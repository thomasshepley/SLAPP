using System.Reflection;
using Makaretu.Dns;
using TitanDeckHost.Core.Api;

namespace TitanDeckHost.Service;

/// <summary>Announces the Host on the show network (Bonjour/mDNS) so TitanDeck
/// finds the PC without typing an address.</summary>
public sealed class Advertiser : IHostedService, IDisposable
{
    private readonly ILogger<Advertiser> _log;
    private ServiceDiscovery? _discovery;
    private ServiceProfile? _profile;

    public Advertiser(ILogger<Advertiser> log) => _log = log;

    public Task StartAsync(CancellationToken cancellationToken)
    {
        try
        {
            _profile = new ServiceProfile(Environment.MachineName, Protocol.ServiceType, Protocol.NetworkPort);
            _profile.AddProperty("api", Protocol.ApiVersion.ToString());
            _profile.AddProperty("version", HostInfo.Version);
            _discovery = new ServiceDiscovery();
            _discovery.Advertise(_profile);
            _log.LogInformation("Advertising {Type} on port {Port}", Protocol.ServiceType, Protocol.NetworkPort);
        }
        catch (Exception error)
        {
            // Discovery is a convenience; the iPad can still use the PC's address.
            _log.LogWarning(error, "Couldn't advertise on the network");
        }
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        try
        {
            if (_profile is not null) _discovery?.Unadvertise(_profile);
        }
        catch (Exception error)
        {
            _log.LogDebug(error, "Unadvertise failed");
        }
        return Task.CompletedTask;
    }

    public void Dispose() => _discovery?.Dispose();
}

public static class HostInfo
{
    public static string Version { get; } =
        Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            .Split('+')[0] ?? "0.0.0";
}
