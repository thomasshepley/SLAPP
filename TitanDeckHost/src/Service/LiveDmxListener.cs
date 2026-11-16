using System.Collections.Concurrent;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using TitanDeckHost.Core.Sacn;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// Listens to the feed Titan sends its own built-in visualiser (Host
/// 0.20.1). Titan's manual ("Ports used by Titan") lists it as LiveDMX: UDP
/// 5584, multicast 239.184.0.0 - 239.184.249.255, "used for internal
/// Visualiser DMX data". It carries every DMX line, whatever the line goes
/// out on, so it's the one place a line on the DMX sockets alone could be
/// heard. Its packets aren't documented. The groups mirror sACN's
/// (239.255.hi.lo on 5568), so each packet is tried as sACN: if it reads,
/// its levels are kept here for <see cref="LevelService"/>; if it doesn't,
/// the first few different ones go in the Titan log as hex, so the layout
/// can be worked out from a real one. It only ever listens.
/// </summary>
public sealed class LiveDmxListener(TitanLog titanLog, ILogger<LiveDmxListener> log) : BackgroundService
{
    public const int Port = 5584;
    private const int MostSamples = 6;
    private static readonly TimeSpan RejoinEvery = TimeSpan.FromSeconds(30);

    private readonly ConcurrentDictionary<int, bool> wanted = new();
    private readonly HashSet<(int Universe, IPAddress Adapter)> joined = [];
    private readonly object joinGate = new();
    private readonly ConcurrentDictionary<int, bool> sampled = new();
    private Socket? socket;
    private long heard, readable;
    private bool readableLogged;

    /// <summary>Levels read from the feed, by the feed's own universe numbers.</summary>
    public DmxUniverses Store { get; } = new();

    /// <summary>Packets heard on the feed since the service started.</summary>
    public long Heard => Interlocked.Read(ref heard);
    /// <summary>Of those, the ones that read as sACN data.</summary>
    public long Readable => Interlocked.Read(ref readable);
    public string? Problem { get; private set; }

    /// <summary>The group a universe would be sent to, by sACN's scheme: 239.184.hi.lo.</summary>
    public static byte[] Group(int universe) => [239, 184, (byte)(universe >> 8), (byte)universe];

    /// <summary>Starts listening for a universe (0 too: the numbering isn't documented).</summary>
    public void Want(int universe)
    {
        if (universe is < 0 or > SacnPacket.MaxUniverse) return;
        if (wanted.TryAdd(universe, true)) JoinAll();
    }

    protected override async Task ExecuteAsync(CancellationToken stopping)
    {
        for (var universe = 0; universe <= 16; universe++) wanted.TryAdd(universe, true);
        while (!stopping.IsCancellationRequested)
        {
            try
            {
                socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
                socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);   // Titan's visualiser listens here too
                socket.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.PacketInformation, true);  // which group it came to
                socket.Bind(new IPEndPoint(IPAddress.Any, Port));
                Problem = null;
                JoinAll();
                using var rejoin = new Timer(_ => JoinAll(), null, RejoinEvery, RejoinEvery);
                var buffer = new byte[2048];
                EndPoint any = new IPEndPoint(IPAddress.Any, 0);
                while (!stopping.IsCancellationRequested)
                {
                    var received = await socket.ReceiveMessageFromAsync(buffer, SocketFlags.None, any, stopping);
                    Take(buffer.AsSpan(0, received.ReceivedBytes), received.PacketInformation.Address,
                        (received.RemoteEndPoint as IPEndPoint)?.Address);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception error) when (error is SocketException or ObjectDisposedException or InvalidOperationException)
            {
                Problem = $"Can't listen for Titan's visualiser feed on port {Port}: {error.Message}";
                log.LogWarning("{Problem}", Problem);
                await Task.Delay(TimeSpan.FromSeconds(10), stopping).ContinueWith(_ => { });
            }
            finally
            {
                lock (joinGate) joined.Clear();
                socket?.Dispose();
                socket = null;
            }
        }
    }

    private void Take(ReadOnlySpan<byte> packet, IPAddress? group, IPAddress? from)
    {
        Interlocked.Increment(ref heard);
        if (SacnPacket.ParseData(packet) is { } data)
        {
            Interlocked.Increment(ref readable);
            Store.Accept(data, DateTimeOffset.UtcNow);
            if (readableLogged) return;
            readableLogged = true;
            Note($"Titan's visualiser feed reads as sACN: universe {data.Universe} sent to {group}, from \"{data.SourceName}\" at {from}", false);
            return;
        }
        // Not sACN-shaped: the first few different sizes, in hex, to work the layout out from.
        if (sampled.Count >= MostSamples || !sampled.TryAdd(packet.Length, true)) return;
        var start = Convert.ToHexString(packet[..Math.Min(packet.Length, 64)]);
        Note($"Titan's visualiser feed, not in a form the Host reads yet: {packet.Length} bytes to {group} from {from}, starting {start}", true);
    }

    private void Note(string text, bool flagged) =>
        titanLog.Add("LiveDMX", "", "IN", text, "", 200, 0, null, null, flagged, DateTimeOffset.Now);

    private void JoinAll()
    {
        var current = socket;
        if (current is null) return;
        var adapters = Adapters();
        lock (joinGate)
        {
            foreach (var universe in wanted.Keys)
            {
                var group = new IPAddress(Group(universe));
                foreach (var adapter in adapters)
                {
                    if (joined.Contains((universe, adapter))) continue;
                    try
                    {
                        current.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.AddMembership, new MulticastOption(group, adapter));
                        joined.Add((universe, adapter));
                    }
                    catch (Exception error) when (error is SocketException or ObjectDisposedException)
                    {
                        log.LogDebug("Couldn't join the visualiser feed's universe {Universe} on {Adapter}: {Error}", universe, adapter, error.Message);
                    }
                }
            }
        }
    }

    /// <summary>Every IPv4 adapter that's up, and this PC itself: the feed is "internal", so it may never leave it.</summary>
    private static List<IPAddress> Adapters()
    {
        try
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Where(n => n.OperationalStatus == OperationalStatus.Up && n.SupportsMulticast)
                .SelectMany(n => n.GetIPProperties().UnicastAddresses)
                .Select(a => a.Address)
                .Where(a => a.AddressFamily == AddressFamily.InterNetwork)
                .Append(IPAddress.Loopback)
                .Distinct()
                .ToList();
        }
        catch (NetworkInformationException)
        {
            return [IPAddress.Any];
        }
    }
}
