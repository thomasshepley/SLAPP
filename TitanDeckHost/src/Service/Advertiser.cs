using System.Net;
using System.Net.NetworkInformation;
using System.Reflection;
using Makaretu.Dns;
using TitanDeckHost.Core.Api;

namespace TitanDeckHost.Service;

/// <summary>Announces the Host on the show network (Bonjour/mDNS) so TitanDeck
/// finds the PC without typing an address. With an adapter chosen (Network for
/// TitanDeck), only on that adapter and only with its address, so the iPad
/// can't end up on another network's address.</summary>
public sealed class Advertiser : IHostedService, IDisposable
{
    private readonly ILogger<Advertiser> _log;
    private readonly NetworkChoice _network;
    private readonly object _gate = new();
    private MulticastService? _multicast;
    private ServiceDiscovery? _discovery;
    private ServiceProfile? _profile;

    public Advertiser(ILogger<Advertiser> log, NetworkChoice network)
    {
        _log = log;
        _network = network;
        _network.Changed += () => Task.Run(Restart);
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        Start();
        return Task.CompletedTask;
    }

    private void Start()
    {
        lock (_gate)
        {
            try
            {
                var (adapter, problem) = _network.Current();
                if (problem is not null) _log.LogWarning("{Problem}", problem);
                var addresses = adapter?.Ipv4.Select(IPAddress.Parse).ToList();
                _profile = new ServiceProfile(Environment.MachineName, Protocol.ServiceType, Protocol.NetworkPort, addresses);
                _profile.AddProperty("api", Protocol.ApiVersion.ToString());
                _profile.AddProperty("version", HostInfo.Version);
                if (adapter is not null) _profile.AddProperty("address", adapter.Ipv4[0]);
                _multicast = adapter is null
                    ? new MulticastService()
                    : new MulticastService(nics => nics.Where(n => n.Id == adapter.Id));
                if (adapter is not null) _multicast.UseIpv6 = false;
                _discovery = new ServiceDiscovery(_multicast);
                _multicast.Start();
                _discovery.Advertise(_profile);
                _log.LogInformation("Advertising {Type} on port {Port} ({Where})", Protocol.ServiceType, Protocol.NetworkPort,
                    adapter is null ? "every adapter" : $"{adapter.Name}, {string.Join(", ", adapter.Ipv4)}");
            }
            catch (Exception error)
            {
                // Discovery is a convenience; the iPad can still use the PC's address.
                _log.LogWarning(error, "Couldn't advertise on the network");
            }
        }
    }

    private void Stop()
    {
        lock (_gate)
        {
            try
            {
                if (_profile is not null) _discovery?.Unadvertise(_profile);
            }
            catch (Exception error)
            {
                _log.LogDebug(error, "Unadvertise failed");
            }
            _discovery?.Dispose();
            _multicast?.Stop();
            _multicast?.Dispose();
            _discovery = null;
            _multicast = null;
            _profile = null;
        }
    }

    /// <summary>Announce again, on the newly chosen adapter.</summary>
    public void Restart()
    {
        Stop();
        Start();
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        Stop();
        return Task.CompletedTask;
    }

    public void Dispose() => Stop();
}

public static class HostInfo
{
    public static string Version { get; } =
        Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            .Split('+')[0] ?? "0.0.0";
}
