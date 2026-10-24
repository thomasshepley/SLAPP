using System.Collections.Concurrent;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using TitanDeckHost.Core.Sacn;

namespace TitanDeckHost.Service;

/// <summary>
/// Listens to the sACN Titan sends, so TitanDeck can show a fixture's live
/// level (Titan's WebAPI can't report one). Titan only sends sACN multicast,
/// and Windows loops multicast back to programs on the same PC, so joining
/// each universe's group on every network adapter hears Titan's own output.
/// The port is shared, in case Titan listens for sACN input too.
/// </summary>
public sealed class SacnListener(DmxUniverses store, ILogger<SacnListener> log) : BackgroundService
{
    /// <summary>Universes listened to from the start; others are added when
    /// a discovery packet lists them or the iPad asks for one.</summary>
    private static readonly int[] StartingUniverses = [1, 2, 3, 4];
    private static readonly TimeSpan RejoinEvery = TimeSpan.FromSeconds(30);

    private readonly ConcurrentDictionary<int, bool> wanted = new();
    private readonly HashSet<(int Universe, IPAddress Adapter)> joined = [];
    private readonly object joinGate = new();
    private Socket? socket;

    /// <summary>Why listening isn't working, or null when it is.</summary>
    public string? Problem { get; private set; }

    /// <summary>Starts listening to a universe (no-op if it already is).</summary>
    public void Want(int universe)
    {
        if (universe is < 1 or > SacnPacket.MaxUniverse) return;
        if (wanted.TryAdd(universe, true)) JoinAll();
    }

    public IReadOnlyList<int> Listening => wanted.Keys.Order().ToList();

    protected override async Task ExecuteAsync(CancellationToken stopping)
    {
        foreach (var u in StartingUniverses.Append(SacnPacket.DiscoveryUniverse)) wanted.TryAdd(u, true);
        while (!stopping.IsCancellationRequested)
        {
            try
            {
                socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
                socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
                socket.Bind(new IPEndPoint(IPAddress.Any, SacnPacket.Port));
                Problem = null;
                JoinAll();
                using var rejoin = new Timer(_ => JoinAll(), null, RejoinEvery, RejoinEvery);
                var buffer = new byte[1144];   // bigger than any sACN packet
                while (!stopping.IsCancellationRequested)
                {
                    var received = await socket.ReceiveAsync(buffer, SocketFlags.None, stopping);
                    foreach (var u in store.Accept(buffer.AsSpan(0, received), DateTimeOffset.UtcNow)) Want(u);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (SocketException error)
            {
                Problem = $"Can't listen for sACN on port {SacnPacket.Port}: {error.Message}";
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

    /// <summary>Joins every wanted universe on every IPv4 adapter that's up,
    /// including ones that appeared since (a cable plugged in mid-show).</summary>
    private void JoinAll()
    {
        var current = socket;
        if (current is null) return;
        var adapters = Adapters();
        lock (joinGate)
        {
            foreach (var universe in wanted.Keys)
            {
                var group = new IPAddress(SacnPacket.MulticastGroup(universe));
                foreach (var adapter in adapters)
                {
                    if (joined.Contains((universe, adapter))) continue;
                    try
                    {
                        current.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.AddMembership,
                            new MulticastOption(group, adapter));
                        joined.Add((universe, adapter));
                    }
                    catch (SocketException error)
                    {
                        log.LogDebug("Couldn't join sACN universe {Universe} on {Adapter}: {Error}", universe, adapter, error.Message);
                    }
                }
            }
        }
    }

    private static List<IPAddress> Adapters()
    {
        try
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Where(n => n.OperationalStatus == OperationalStatus.Up && n.SupportsMulticast)
                .SelectMany(n => n.GetIPProperties().UnicastAddresses)
                .Select(a => a.Address)
                .Where(a => a.AddressFamily == AddressFamily.InterNetwork)
                .Distinct()
                .ToList();
        }
        catch (NetworkInformationException)
        {
            return [IPAddress.Any];
        }
    }
}
