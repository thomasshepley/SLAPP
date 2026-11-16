using System.Collections.Concurrent;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text.Json;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Citp;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// Follows the desk's selection over CITP, the way Capture does.
/// Titan 19's WebAPI is its own user, so it can't see what's selected on the
/// desk's screens, but Titan shares its selection with a CITP visualiser.
/// When switched on (Test or Show mode, off by default, Data\citp.json) the Host
/// announces itself as a visualiser called "TitanDeck Host", listens for
/// CITP announcements, takes a connection from Titan on this PC (or connects
/// to Titan if Titan announces a port) and passes the selection to the iPad.
/// It only ever sends the packets <see cref="CitpAllowlist"/> lets through:
/// never a patch, selection, identify or DMX. Connections from other PCs are
/// refused, so another desk on the show network can't link to it. Every CITP
/// message shows in the Titan log.
/// </summary>
public sealed class CitpService(HostPaths paths, TitanLog titanLog, PatchReader patch, ILogger<CitpService> log) : BackgroundService
{
    public const string Who = "CITP";
    public const string OurName = "TitanDeck Host";
    public const int PreferredPort = 4435;
    public const int MaxLinks = 8;
    private static readonly TimeSpan AnnounceEvery = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan ConnectOutAfter = TimeSpan.FromSeconds(5);
    /// <summary>Between tries at connecting to Titan, so a Titan that says no doesn't fill the log.</summary>
    private static readonly TimeSpan ConnectOutEvery = TimeSpan.FromSeconds(30);

    private sealed record Peer(IPAddress Address, CitpLocation Location, DateTimeOffset LastSeen);
    private sealed record Saved(bool Enabled);

    private readonly string _file = Path.Combine(paths.Data, "citp.json");
    private readonly ConcurrentDictionary<IPAddress, Peer> _peers = new();
    private readonly object _gate = new();
    private bool? _enabled;
    private CancellationTokenSource? _running;
    /// <summary>Titan's links, by number. Titan opens several (and keeps retrying
    /// any that are refused), so up to <see cref="MaxLinks"/> are kept.</summary>
    private readonly Dictionary<int, (CitpSession? Session, string Peer)> _links = [];
    private int _nextLink;
    private DateTimeOffset _lastRefusalLogged = DateTimeOffset.MinValue;
    private int _refusedSinceLogged;
    private DateTimeOffset _lastLinkLogged = DateTimeOffset.MinValue;
    private int? _listeningPort;
    /// <summary>What's wrong with each of CITP's jobs, if anything, and when it was last logged.</summary>
    private readonly ConcurrentDictionary<string, (string Text, DateTimeOffset Noted)> _problems = new();
    private static readonly TimeSpan RestartAfter = TimeSpan.FromSeconds(3);
    private IReadOnlyList<string> _announcedOn = [];
    private DateTimeOffset? _announcedAt;
    private DateTimeOffset? _heardOurselves;

    public bool Enabled
    {
        get
        {
            if (_enabled is { } known) return known;
            try
            {
                _enabled = File.Exists(_file) && (JsonSerializer.Deserialize<Saved>(File.ReadAllText(_file))?.Enabled ?? false);
            }
            catch (Exception)
            {
                _enabled = false;   // unreadable: off, the safe default
            }
            return _enabled.Value;
        }
    }

    /// <summary>Switched on (in either mode).</summary>
    public bool Active => Enabled;

    public CitpStatusDto SetEnabled(bool enabled)
    {
        _enabled = enabled;
        File.WriteAllText(_file, JsonSerializer.Serialize(new Saved(_enabled.Value)));
        Note(_enabled.Value ? "Follow selection via CITP switched on" : "Follow selection via CITP switched off");
        return Status();
    }

    /// <summary>Asks Titan over every CITP link to clear its selection (TitanDeck's CLEAR). False with no link.</summary>
    public bool ClearDeskSelection()
    {
        lock (_gate)
        {
            var sessions = _links.Values.Select(l => l.Session).OfType<CitpSession>().ToList();
            foreach (var session in sessions) session.ClearSelection();
            return sessions.Count > 0;
        }
    }

    /// <summary>Fixture numbers for Titan's fixture ids from Titan's CITP fixture list (null where it hasn't one).</summary>
    public IReadOnlyList<int?> UserNumbers(IReadOnlyList<int> titanIds)
    {
        lock (_gate)
        {
            var session = _links.Values.Select(l => l.Session).OfType<CitpSession>().FirstOrDefault(s => s.HaveFixtureList);
            return titanIds.Select(id => session?.UserNumber(id)).ToList();
        }
    }

    public CitpSelectionDto Selection()
    {
        lock (_gate)
        {
            var snapshot = Latest();
            return new CitpSelectionDto(Active, snapshot is not null, snapshot?.PeerName,
                snapshot?.Selection ?? [], snapshot?.Problem ?? Problem);
        }
    }

    public CitpStatusDto Status()
    {
        var local = LocalAddresses();
        var peers = _peers.Values.OrderBy(p => p.Location.Name)
            .Select(p => new CitpPeerDto(p.Address.ToString(), p.Location.Type, p.Location.Name, p.Location.State,
                p.Location.ListeningTcpPort, local.Contains(p.Address), p.LastSeen))
            .ToList();
        lock (_gate)
        {
            var snapshot = Latest();
            var links = _links.Values.Count(l => l.Session is not null);
            var connected = snapshot is null ? null
                : $"{snapshot.PeerName ?? "Titan"}{(links > 1 ? $" ({links} links)" : "")}";
            return new CitpStatusDto(Enabled, true, _running is not null, _listeningPort, peers, connected,
                snapshot?.PeerShow, snapshot?.FixtureCount ?? 0, snapshot?.Selection ?? [], snapshot?.Problem ?? Problem,
                _running is null ? null : Announcing());
        }
    }

    /// <summary>How the announcing is going, for the card: where to, and whether it's coming back round.</summary>
    private string Announcing()
    {
        var now = DateTimeOffset.UtcNow;
        if (_announcedAt is not { } at || now - at > TimeSpan.FromSeconds(10) || _announcedOn.Count == 0)
            return "Not announcing itself at the moment (it starts again by itself).";
        var heard = _heardOurselves is { } own && now - own < TimeSpan.FromSeconds(10);
        return $"Announcing itself every second on {string.Join(", ", _announcedOn)}. " +
               (heard ? "The announcements come back round on this PC, so Titan can hear them."
                      : "The announcements aren't coming back round on this PC, so Titan may not hear them.");
    }

    protected override async Task ExecuteAsync(CancellationToken stopping)
    {
        try
        {
            while (!stopping.IsCancellationRequested)
            {
                if (Active && _running is null)
                {
                    _running = CancellationTokenSource.CreateLinkedTokenSource(stopping);
                    _ = Run(_running.Token);
                }
                else if (!Active && _running is { } running)
                {
                    _running = null;
                    running.Cancel();
                    _peers.Clear();
                }
                await Task.Delay(AnnounceEvery, stopping);
            }
        }
        catch (OperationCanceledException)
        {
            // stopping
        }
    }

    /// <summary>
    /// While switched on: hear announcements, announce ourselves, take
    /// Titan's connection. Each of the four jobs is kept going on its own
    /// (Host 0.20.1): before, one that hit a network error (the PC asleep, a
    /// cable out) stopped for good while the others carried on, so the card
    /// said "Waiting for Titan to connect" until CITP was switched off and on.
    /// </summary>
    private async Task Run(CancellationToken token)
    {
        _problems.Clear();
        Note($"Announcing \"{OurName}\" as a CITP visualiser");
        var started = DateTimeOffset.UtcNow;
        try
        {
            await Task.WhenAll(
                KeepGoing("hearing announcements", Hear, token),
                KeepGoing("announcing", Announce, token),
                KeepGoing("taking Titan's connection", Accept, token),
                KeepGoing("connecting to Titan", t => ConnectOut(started, t), token));
        }
        finally
        {
            _listeningPort = null;
            Note("CITP stopped");
        }
    }

    /// <summary>Runs one of CITP's jobs until CITP is switched off, starting it again a few seconds after it stops or fails.</summary>
    private async Task KeepGoing(string what, Func<CancellationToken, Task> job, CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                await job(token);
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                return;
            }
            catch (Exception error)
            {
                Trouble(what, $"CITP {what} stopped ({error.Message}). Starting it again.");
            }
            try
            {
                await Task.Delay(RestartAfter, token);
            }
            catch (OperationCanceledException)
            {
                return;
            }
        }
    }

    /// <summary>Something wrong with one of the jobs: shown on the card, and logged when it's new (not every retry).</summary>
    private void Trouble(string what, string problem)
    {
        var known = _problems.TryGetValue(what, out var before) && before.Text == problem
                    && DateTimeOffset.UtcNow - before.Noted < TimeSpan.FromMinutes(10);
        _problems[what] = (problem, known ? before.Noted : DateTimeOffset.UtcNow);
        if (known) return;
        log.LogWarning("{Problem}", problem);
        Note(problem, flagged: true);
    }

    private string? Problem => _problems.IsEmpty ? null : string.Join(" ", _problems.Values.Select(p => p.Text));

    private static TcpListener StartListener()
    {
        try
        {
            var preferred = new TcpListener(IPAddress.Any, PreferredPort);
            preferred.Start();
            return preferred;
        }
        catch (SocketException)
        {
            var any = new TcpListener(IPAddress.Any, 0);   // 4435 taken: any free port (it's in our announcement)
            any.Start();
            return any;
        }
    }

    // --- PINF over UDP multicast ---

    private async Task Hear(CancellationToken token)
    {
        using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
        var joined = new HashSet<(string Group, IPAddress Adapter)>();
        // Every adapter that's up now, and again every half minute for ones that come up later.
        void Join()
        {
            foreach (var group in CitpMessages.MulticastGroups)
            foreach (var adapter in Adapters().Prepend(IPAddress.Loopback))
            {
                if (joined.Contains((group, adapter))) continue;
                try
                {
                    socket.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.AddMembership,
                        new MulticastOption(IPAddress.Parse(group), adapter));
                    joined.Add((group, adapter));
                }
                catch (SocketException)
                {
                    // that adapter can't do multicast: the others still can
                }
                catch (ObjectDisposedException)
                {
                    return;
                }
            }
        }
        try
        {
            socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);   // shared with Titan
            socket.Bind(new IPEndPoint(IPAddress.Any, CitpMessages.Port));
        }
        catch (SocketException error)
        {
            // Still announcing and taking connections: Titan links without being heard. Tried again in a while.
            Trouble("hearing announcements", $"Can't hear CITP announcements on UDP {CitpMessages.Port}: {error.Message}");
            await Task.Delay(TimeSpan.FromSeconds(30), token);
            return;
        }
        Join();
        _problems.TryRemove("hearing announcements", out _);
        using var rejoin = new Timer(_ => Join(), null, TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));
        var buffer = new byte[65536];
        EndPoint from = new IPEndPoint(IPAddress.Any, 0);
        while (!token.IsCancellationRequested)
        {
            var received = await socket.ReceiveFromAsync(buffer, SocketFlags.None, from, token);
            if (CitpPacket.Parse(buffer.AsSpan(0, received.ReceivedBytes)) is not { } packet) continue;
            if (CitpMessages.ReadLocation(packet) is not { } location) continue;
            var address = ((IPEndPoint)received.RemoteEndPoint).Address;
            if (location.Name == OurName && location.ListeningTcpPort == _listeningPort)
            {
                _heardOurselves = DateTimeOffset.UtcNow;   // multicast loops back on this PC, so Titan can hear it too
                continue;
            }
            var seen = _peers.TryGetValue(address, out var before);
            _peers[address] = new Peer(address, location, DateTimeOffset.UtcNow);
            if (!seen || before!.Location != location)
                Log(false, address.ToString(), "PINF PLoc",
                    $"{location.Type} \"{location.Name}\" ({location.State}), TCP port {location.ListeningTcpPort}"
                    + (LocalAddresses().Contains(address) ? ", on this PC" : ", another PC: TitanDeck Host won't link to it"), false);
        }
    }

    private async Task Announce(CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            // Nothing to announce until there's a port for Titan to connect to.
            if (_listeningPort is { } port)
            {
                var bytes = CitpAllowlist.Check(CitpMessages.Location((ushort)port, "Visualizer", OurName, "Running")).ToBytes();
                var sent = new List<string>();
                foreach (var adapter in Adapters().Prepend(IPAddress.Loopback))
                {
                    try
                    {
                        using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
                        socket.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.MulticastTimeToLive, 1);   // never past a router
                        socket.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.MulticastLoopback, true);   // Titan's on this PC
                        socket.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.MulticastInterface, adapter.GetAddressBytes());
                        foreach (var group in CitpMessages.MulticastGroups)
                            await socket.SendToAsync(bytes, SocketFlags.None, new IPEndPoint(IPAddress.Parse(group), CitpMessages.Port), token);
                        sent.Add(IPAddress.IsLoopback(adapter) ? "this PC" : adapter.ToString());
                    }
                    catch (SocketException)
                    {
                        // an adapter that can't send multicast; the others still do
                    }
                }
                _announcedOn = sent;
                _announcedAt = DateTimeOffset.UtcNow;
            }
            await Task.Delay(AnnounceEvery, token);
        }
    }

    // --- The TCP link with Titan ---

    private async Task Accept(CancellationToken token)
    {
        var listener = StartListener();
        try
        {
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;
            if (_listeningPort != port) Note($"Listening for Titan on TCP {port}");
            _listeningPort = port;
            _problems.TryRemove("taking Titan's connection", out _);
            await AcceptOn(listener, token);
        }
        finally
        {
            listener.Stop();
        }
    }

    private async Task AcceptOn(TcpListener listener, CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            var client = await listener.AcceptTcpClientAsync(token);
            var remote = ((IPEndPoint)client.Client.RemoteEndPoint!).Address;
            if (!IsThisPc(remote))
            {
                Log(false, remote.ToString(), "TCP connection", "refused: only Titan on this PC can link to TitanDeck Host", true);
                client.Dispose();
                continue;
            }
            if (TryClaim(remote) is not { } link)
            {
                LogRefusal(remote);
                client.Dispose();
                continue;
            }
            _ = Link(client, remote, link, outgoing: false, token);
        }
    }

    /// <summary>If Titan announces a TCP port and hasn't connected to us, connect to it.</summary>
    private async Task ConnectOut(DateTimeOffset started, CancellationToken token)
    {
        var lastTry = DateTimeOffset.MinValue;
        while (!token.IsCancellationRequested)
        {
            await Task.Delay(ConnectOutAfter, token);
            if (DateTimeOffset.UtcNow - started < ConnectOutAfter || DateTimeOffset.UtcNow - lastTry < ConnectOutEvery) continue;
            var local = LocalAddresses();
            var titan = _peers.Values.FirstOrDefault(p => local.Contains(p.Address) && p.Location.ListeningTcpPort > 0
                && p.Location.Type.Equals("LightingConsole", StringComparison.OrdinalIgnoreCase));
            if (titan is null || HasLinks() || TryClaim(titan.Address) is not { } link) continue;
            lastTry = DateTimeOffset.UtcNow;
            var client = new TcpClient();
            try
            {
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
                timeout.CancelAfter(TimeSpan.FromSeconds(3));
                await client.ConnectAsync(titan.Address, titan.Location.ListeningTcpPort, timeout.Token);
            }
            catch (Exception error) when (error is SocketException or OperationCanceledException && !token.IsCancellationRequested)
            {
                Log(true, titan.Address.ToString(), $"TCP connect to {titan.Location.ListeningTcpPort}", "couldn't connect: " + error.Message, true);
                client.Dispose();
                Release(link);
                continue;
            }
            await Link(client, titan.Address, link, outgoing: true, token);
        }
    }

    /// <summary>A number for a new link, or null when there are already <see cref="MaxLinks"/>.</summary>
    private int? TryClaim(IPAddress peer)
    {
        lock (_gate)
        {
            if (_links.Count >= MaxLinks) return null;
            var link = ++_nextLink;
            _links[link] = (null, peer.ToString());
            return link;
        }
    }

    private void Release(int link)
    {
        lock (_gate) _links.Remove(link);
    }

    private bool HasLinks()
    {
        lock (_gate) return _links.Count > 0;
    }

    /// <summary>The link that heard a selection last (they all hear the same desk). Call inside the gate.</summary>
    private CitpSessionSnapshot? Latest() =>
        _links.Values.Select(l => l.Session?.Snapshot()).OfType<CitpSessionSnapshot>()
            .OrderByDescending(s => s.SelectionAt ?? DateTimeOffset.MinValue).FirstOrDefault();

    /// <summary>Over the limit: at most one line a minute, with a count, so retries can't bury the log.</summary>
    private void LogRefusal(IPAddress remote)
    {
        lock (_gate)
        {
            _refusedSinceLogged++;
            if (DateTimeOffset.UtcNow - _lastRefusalLogged < TimeSpan.FromMinutes(1)) return;
            _lastRefusalLogged = DateTimeOffset.UtcNow;
        }
        Log(false, remote.ToString(), "TCP connection",
            $"refused {_refusedSinceLogged} more link{(_refusedSinceLogged == 1 ? "" : "s")} (already {MaxLinks})", false);
        lock (_gate) _refusedSinceLogged = 0;
    }

    private async Task Link(TcpClient client, IPAddress remote, int link, bool outgoing, CancellationToken token)
    {
        var from = remote.ToString();
        // Only the first link logs everything, and link-up lines at most every 30 s
        // (Titan reconnects often); the rest log selections and problems only.
        bool quiet;
        lock (_gate)
        {
            quiet = _links.Keys.Any(other => other < link) || DateTimeOffset.UtcNow - _lastLinkLogged < TimeSpan.FromSeconds(30);
            if (!quiet) _lastLinkLogged = DateTimeOffset.UtcNow;
        }
        using (client)
        {
            var stream = client.GetStream();
            var session = new CitpSession(OurName, packet => stream.Write(packet.ToBytes()), line =>
            {
                if (!quiet || line.Flagged || line.What.Contains("Selection") || line.What.StartsWith("FSEL"))
                    Log(line.Outgoing, from, line.What, line.Note, line.Flagged);
            }, fixtures => patch.UseCitp(fixtures, from));
            if (!quiet)
                Log(outgoing, from, "TCP connection", outgoing ? $"linked (TitanDeck Host connected to Titan's port {((IPEndPoint)client.Client.RemoteEndPoint!).Port})" : "linked (Titan connected)", false);
            try
            {
                lock (_gate)
                {
                    _links[link] = (session, from);
                    session.Start();
                }
                var framer = new CitpFramer();
                var buffer = new byte[65536];
                while (!token.IsCancellationRequested)
                {
                    var read = await stream.ReadAsync(buffer, token);
                    if (read == 0) break;
                    var packets = framer.Add(buffer.AsSpan(0, read));
                    lock (_gate)
                        foreach (var packet in packets) session.Receive(packet, DateTimeOffset.UtcNow);
                }
                if (!quiet) Log(false, from, "TCP connection", "Titan closed the link", false);
            }
            catch (OperationCanceledException)
            {
                try
                {
                    lock (_gate) session.Stop();
                }
                catch (IOException)
                {
                    // already gone
                }
            }
            catch (Exception error) when (error is IOException or SocketException or InvalidDataException or ObjectDisposedException)
            {
                if (!quiet) Log(false, from, "TCP connection", "link lost: " + error.Message, true);
            }
            finally
            {
                Release(link);
            }
        }
    }

    // --- Helpers ---

    private void Log(bool outgoing, string from, string what, string? note, bool flagged) =>
        titanLog.Add(Who, from, outgoing ? "OUT" : "IN", what, "", 200, 0, note, null, flagged, DateTimeOffset.Now);

    private void Note(string text, bool flagged = false) =>
        titanLog.Add(Who, "", "--", text, "", 200, 0, null, null, flagged, DateTimeOffset.Now);

    private static bool IsThisPc(IPAddress address) =>
        IPAddress.IsLoopback(address) || LocalAddresses().Contains(address.IsIPv4MappedToIPv6 ? address.MapToIPv4() : address);

    private static HashSet<IPAddress> LocalAddresses()
    {
        var addresses = new HashSet<IPAddress> { IPAddress.Loopback };
        try
        {
            foreach (var n in NetworkInterface.GetAllNetworkInterfaces())
            foreach (var a in n.GetIPProperties().UnicastAddresses)
                if (a.Address.AddressFamily == AddressFamily.InterNetwork) addresses.Add(a.Address);
        }
        catch (NetworkInformationException)
        {
            // loopback only
        }
        return addresses;
    }

    private static List<IPAddress> Adapters()
    {
        try
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Where(n => n.OperationalStatus == OperationalStatus.Up && n.SupportsMulticast
                            && n.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                .SelectMany(n => n.GetIPProperties().UnicastAddresses)
                .Select(a => a.Address)
                .Where(a => a.AddressFamily == AddressFamily.InterNetwork)
                .Distinct()
                .ToList();
        }
        catch (NetworkInformationException)
        {
            return [];
        }
    }
}
