using TitanDeckHost.Core.Rdp;

namespace TitanDeckHost.Core.Api;

/// <summary>
/// Shapes of the Host's JSON API (camelCase on the wire). The iPad side lives
/// in TitanDeck/Sources/Host - change both together, and bump
/// <see cref="ApiVersion"/> for anything that isn't purely additive.
/// </summary>
public static class Protocol
{
    public const int ApiVersion = 1;
    /// <summary>Paired API, reachable from the show network.</summary>
    public const int NetworkPort = 4431;
    /// <summary>Local control API for the Host's own window, on 127.0.0.1 only.</summary>
    public const int LocalPort = 4432;
    /// <summary>Bonjour/mDNS service type the iPad looks for.</summary>
    public const string ServiceType = "_titandeck-host._tcp";
}

public sealed record HelloResponse(string Name, string MachineName, string HostVersion, int ApiVersion, bool Paired);

public sealed record PairRequest(string Code, string DeviceName);

public sealed record PairResponse(string Token, string HostName, string DeviceId);

public sealed record CheckDto(string Id, string Title, string State, string Detail, string? Fix, string? FixTitle)
{
    public static CheckDto From(Check c) => new(c.Id, c.Title, c.State.ToString().ToLowerInvariant(), c.Detail,
        c.Fix == FixAction.None ? null : c.Fix.ToString(), c.Fix == FixAction.None ? null : c.FixTitle);
}

public sealed record StatusResponse(
    string Overall,
    IReadOnlyList<CheckDto> Checks,
    string Edition,
    string WindowsVersion,
    string TermsrvVersion,
    bool TitanRunning,
    int FilesWaitingForIPad,
    string HostVersion);

public sealed record FixRequest(string Action);

public sealed record FixResponse(bool Success, string Message);

public sealed record FileEntry(string Name, long Size, DateTimeOffset Modified);

public sealed record UploadResponse(string SavedAs, long Size);

/// <summary>For the Host's own window: pairing code and paired devices.</summary>
public sealed record PairingInfo(string? Code, DateTimeOffset? Expires, IReadOnlyList<DeviceDto> Devices);

public sealed record DeviceDto(string Id, string Name, DateTimeOffset PairedAt, DateTimeOffset? LastSeen);
