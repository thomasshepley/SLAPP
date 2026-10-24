namespace TitanDeckHost.Core.Rdp;

/// <summary>Picture-quality presets for the iPad's remote desktop, from a wired
/// link to bad Wi-Fi on set.</summary>
public enum RdpPreset
{
    Best,
    Balanced,
    WeakSignal,
}

/// <summary>"Configure image quality for RemoteFX Adaptive Graphics" (ImageQuality).
/// The numbers are Windows' own.</summary>
public enum RdpImageQuality
{
    Lossless = 1,
    High = 2,
    Medium = 3,
    Low = 4,
}

/// <summary>"Configure RemoteFX Adaptive Graphics" (GraphicsProfile).</summary>
public enum RdpGraphicsProfile
{
    ServerScalability = 1,
    Automatic = 2,
    MinimumBandwidth = 3,
}

/// <summary>A registry value to set (or delete, when Value is null) under HKLM.</summary>
public sealed record RegistryWrite(string Key, string Name, int? Value);

/// <summary>What Windows itself does with the remote desktop picture. The
/// iPad's FreeRDP has no H.264 decoder, so the AVC policies don't apply;
/// these are the ones that change what it receives. Takes effect on the next
/// connection.</summary>
public sealed record RdpServerQuality(RdpImageQuality ImageQuality, RdpGraphicsProfile Profile, int FrameRate)
{
    public const string PolicyKey = @"SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services";
    public const string WinStationsKey = @"SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations";
    /// <summary>DWMFRAMEINTERVAL 15 lifts Windows' 30 fps remote desktop cap to 60 (Microsoft KB 2885213).</summary>
    public const int SixtyFpsInterval = 15;

    /// <summary>What Windows does with nothing set: medium quality, it chooses, 30 fps.</summary>
    public static RdpServerQuality WindowsDefault { get; } = new(RdpImageQuality.Medium, RdpGraphicsProfile.Automatic, 30);

    public static RdpServerQuality For(RdpPreset preset) => preset switch
    {
        RdpPreset.Best => new(RdpImageQuality.High, RdpGraphicsProfile.Automatic, 60),
        RdpPreset.Balanced => new(RdpImageQuality.Medium, RdpGraphicsProfile.Automatic, 30),
        RdpPreset.WeakSignal => new(RdpImageQuality.Low, RdpGraphicsProfile.MinimumBandwidth, 30),
        _ => WindowsDefault,
    };

    /// <summary>The preset these settings match, if any.</summary>
    public RdpPreset? Preset => Enum.GetValues<RdpPreset>().Cast<RdpPreset?>().FirstOrDefault(p => For(p!.Value) == this);

    /// <summary>The registry writes that put these settings in place. Windows'
    /// defaults are written as deletions, so "Balanced" leaves a clean PC.</summary>
    public IReadOnlyList<RegistryWrite> RegistryWrites() =>
    [
        new(PolicyKey, "ImageQuality", ImageQuality == RdpImageQuality.Medium ? null : (int)ImageQuality),
        new(PolicyKey, "GraphicsProfile", Profile == RdpGraphicsProfile.Automatic ? null : (int)Profile),
        new(WinStationsKey, "DWMFRAMEINTERVAL", FrameRate >= 60 ? SixtyFpsInterval : null),
    ];

    /// <summary>Reads settings back from the registry values (null = not set).</summary>
    public static RdpServerQuality FromRegistry(int? imageQuality, int? graphicsProfile, int? frameInterval) => new(
        imageQuality is >= 1 and <= 4 ? (RdpImageQuality)imageQuality.Value : RdpImageQuality.Medium,
        graphicsProfile is >= 1 and <= 3 ? (RdpGraphicsProfile)graphicsProfile.Value : RdpGraphicsProfile.Automatic,
        frameInterval is > 0 and <= 16 ? 60 : 30);

    /// <summary>Settings from what the iPad or the Host window sent, with sane limits.</summary>
    public static RdpServerQuality? Parse(string? imageQuality, string? profile, int frameRate) =>
        Enum.TryParse<RdpImageQuality>(imageQuality, ignoreCase: true, out var quality)
        && Enum.IsDefined(quality)
        && Enum.TryParse<RdpGraphicsProfile>(profile, ignoreCase: true, out var graphics)
        && Enum.IsDefined(graphics)
            ? new RdpServerQuality(quality, graphics, frameRate >= 60 ? 60 : 30)
            : null;
}

/// <summary>The official RDP Wrapper release the Host downloads or accepts:
/// github.com/stascorp/rdpwrap v1.6.2. Anything else is refused.</summary>
public static class RdpWrapperRelease
{
    public const string Version = "1.6.2";
    public const string FileName = "RDPWrap-v1.6.2.zip";
    public const string DownloadUrl = "https://github.com/stascorp/rdpwrap/releases/download/v1.6.2/RDPWrap-v1.6.2.zip";
    /// <summary>SHA-256 of the official zip (checked against the download and public sandbox reports).</summary>
    public const string Sha256 = "35a9481ddbed5177431a9ea4bd09468fe987797d7b1231d64942d17eb54ec269";

    public static bool IsOfficial(Stream zip)
    {
        using var sha = System.Security.Cryptography.SHA256.Create();
        return Convert.ToHexString(sha.ComputeHash(zip)).Equals(Sha256, StringComparison.OrdinalIgnoreCase);
    }
}
