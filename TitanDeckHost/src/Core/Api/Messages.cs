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
    string HostVersion,
    string Mode = "test");

public sealed record FixRequest(string Action);

public sealed record FixResponse(bool Success, string Message);

/// <summary>Remote desktop picture settings on the PC. Strings are the enum
/// names in camelCase ("high", "minimumBandwidth"); preset is null when the
/// settings don't match one.</summary>
public sealed record RdpQualityDto(string ImageQuality, string Profile, int FrameRate, string? Preset)
{
    public static RdpQualityDto From(RdpServerQuality q) =>
        new(Camel(q.ImageQuality.ToString()), Camel(q.Profile.ToString()), q.FrameRate, q.Preset is { } p ? Camel(p.ToString()) : null);

    private static string Camel(string name) => char.ToLowerInvariant(name[0]) + name[1..];
}

/// <summary>Either a preset ("best", "balanced", "weakSignal") or the three settings.</summary>
public sealed record RdpQualityRequest(string? Preset, string? ImageQuality, string? Profile, int FrameRate)
{
    public RdpServerQuality? Resolve() =>
        Enum.TryParse<RdpPreset>(Preset, ignoreCase: true, out var preset) && Enum.IsDefined(preset)
            ? RdpServerQuality.For(preset)
            : RdpServerQuality.Parse(ImageQuality, Profile, FrameRate);
}

public sealed record FileEntry(string Name, long Size, DateTimeOffset Modified);

public sealed record UploadResponse(string SavedAs, long Size);

/// <summary>For the Host's own window: pairing code and paired devices.</summary>
public sealed record PairingInfo(string? Code, DateTimeOffset? Expires, IReadOnlyList<DeviceDto> Devices);

public sealed record DeviceDto(string Id, string Name, DateTimeOffset PairedAt, DateTimeOffset? LastSeen);

/// <summary>Live sACN levels of one universe (`GET /api/v1/dmx/{universe}`).
/// Levels are 0-255, starting at DMX address `start`. Sources are the
/// winning senders' names (Titan's own, normally).</summary>
public sealed record DmxLevelsDto(int Universe, int Start, IReadOnlyList<int> Levels, int Priority,
    IReadOnlyList<string> Sources, int AgeMs);

/// <summary>What the Host hears over sACN (`GET /api/v1/dmx`): universes with
/// a live source or announced by discovery, those it's listening to, and why
/// it can't listen, if it can't.</summary>
public sealed record DmxSummaryDto(IReadOnlyList<int> Universes, IReadOnlyList<int> Listening, string? Problem);

/// <summary>Host updates (`GET /local/update`). Ready is the checked installer
/// to run, with its SHA-256 so the window can check it again before running it.</summary>
public sealed record UpdateStatusDto(string Current, string? Latest, bool Available, string? Notes, DateTimeOffset? Published,
    DateTimeOffset? Checked, string? Problem, double? Downloading, string? Ready, string? ReadySha256);

/// <summary>Fake Titan's settings when started from the Host window.</summary>
public sealed record FakeTitanStartRequest(int Fixtures, int Playbacks, bool Desk, bool Sacn, int LatencyMs);

/// <summary>Fake Titan (`GET /local/faketitan`). State is its command lines,
/// selections and levels; Ports the ones it has open.</summary>
public sealed record FakeTitanStatusDto(bool Running, int Fixtures, int Playbacks, bool Desk, bool Sacn, int LatencyMs,
    string? Problem, string? State, IReadOnlyList<int> Ports);

/// <summary>"3,4", "1-10" or empty, as if selected in Layouts.</summary>
public sealed record DeskSelectRequest(string Fixtures);

/// <summary>The Titan log since an entry (`GET /local/titanlog?after=`).</summary>
public sealed record TitanLogDto(IReadOnlyList<TitanDeckHost.Core.Titan.TitanLogEntry> Entries,
    IReadOnlyList<TitanDeckHost.Core.Titan.TitanPollSummary> Polls);


/// <summary>One patched fixture (`GET /api/v1/patch`). Universe is Titan's DMX
/// line, taken as the sACN universe it sends on (Titan's default). Intensity
/// is the channels its level is on, 0 = its first channel; null until its
/// personality is found.</summary>
public sealed record PatchFixtureDto(int User, string? Model, string? Mode, int Universe, int Address, int? Channels,
    IReadOnlyList<int>? Intensity, string? Legend);

/// <summary>The patch from Titan's newest patch report (Disk &gt; Reports), or
/// Fake Titan's while it runs. Folders are where the Host looks.</summary>
public sealed record PatchDto(string? Source, DateTimeOffset? Written, DateTimeOffset? Read, IReadOnlyList<PatchFixtureDto> Fixtures,
    int Personalities, string? Problem, IReadOnlyList<string> Folders);

/// <summary>Test or Show (`GET/POST /local/mode`): "test" or "show".</summary>
public sealed record ModeDto(string Mode);

/// <summary>A report file picked in the Host window.</summary>
public sealed record PatchImportRequest(string Name, string Text);
