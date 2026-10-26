using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace TitanDeckHost.Core.Net;

/// <summary>One of the PC's network adapters with an IPv4 address ("Ethernet 1", 10.0.0.5).</summary>
public sealed record AdapterInfo(string Id, string Name, string Description, IReadOnlyList<string> Ipv4, bool Up);

/// <summary>
/// Which adapter TitanDeck should use. Automatic announces the Host on every
/// adapter; picking one announces only that adapter's address, so an iPad on
/// the show network doesn't land on another network's address (the PC's
/// internet or a second show network).
/// </summary>
public static class NetworkAdapters
{
    /// <summary>The PC's adapters that have an IPv4 address (not loopback), connected ones first.</summary>
    public static IReadOnlyList<AdapterInfo> Read()
    {
        try
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Where(n => n.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                .Select(n => new AdapterInfo(n.Id, n.Name, n.Description,
                    n.GetIPProperties().UnicastAddresses
                        .Where(a => a.Address.AddressFamily == AddressFamily.InterNetwork)
                        .Select(a => a.Address.ToString())
                        .Where(a => !a.StartsWith("169.254.", StringComparison.Ordinal))   // no DHCP answer
                        .ToList(),
                    n.OperationalStatus == OperationalStatus.Up))
                .Where(a => a.Ipv4.Count > 0)
                .OrderByDescending(a => a.Up)
                .ThenBy(a => a.Name, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        catch (NetworkInformationException)
        {
            return [];
        }
    }

    /// <summary>
    /// The adapter to announce on: the chosen one if it's connected with an
    /// address, else none (every adapter) with the reason.
    /// </summary>
    public static (AdapterInfo? Adapter, string? Problem) Resolve(IReadOnlyList<AdapterInfo> adapters, string? chosenId, string? chosenName)
    {
        if (string.IsNullOrEmpty(chosenId)) return (null, null);
        var adapter = adapters.FirstOrDefault(a => a.Id == chosenId)
            ?? adapters.FirstOrDefault(a => a.Name.Equals(chosenName, StringComparison.OrdinalIgnoreCase));
        var name = chosenName ?? "The chosen adapter";
        if (adapter is null) return (null, $"{name} isn't there (unplugged or no address?), so the Host is on every adapter for now.");
        if (!adapter.Up) return (null, $"{adapter.Name} isn't connected, so the Host is on every adapter for now.");
        return (adapter, null);
    }
}
