using System.Text;
using TitanDeckHost.Core.Rdp;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class RdpQualityTests
{
    [Fact]
    public void PresetsMapToWindowsValues()
    {
        var best = RdpServerQuality.For(RdpPreset.Best);
        Assert.Equal(RdpImageQuality.High, best.ImageQuality);
        Assert.Equal(60, best.FrameRate);
        var weak = RdpServerQuality.For(RdpPreset.WeakSignal);
        Assert.Equal(RdpGraphicsProfile.MinimumBandwidth, weak.Profile);
        Assert.Equal(RdpImageQuality.Low, weak.ImageQuality);
        Assert.Equal(RdpServerQuality.WindowsDefault, RdpServerQuality.For(RdpPreset.Balanced));
    }

    [Fact]
    public void RegistryWritesUseWindowsNumbersAndDeleteDefaults()
    {
        var best = RdpServerQuality.For(RdpPreset.Best).RegistryWrites();
        Assert.Contains(new RegistryWrite(RdpServerQuality.PolicyKey, "ImageQuality", 2), best);
        Assert.Contains(new RegistryWrite(RdpServerQuality.PolicyKey, "GraphicsProfile", null), best);
        Assert.Contains(new RegistryWrite(RdpServerQuality.WinStationsKey, "DWMFRAMEINTERVAL", 15), best);

        var balanced = RdpServerQuality.For(RdpPreset.Balanced).RegistryWrites();
        Assert.All(balanced, w => Assert.Null(w.Value));   // a clean PC

        var weak = RdpServerQuality.For(RdpPreset.WeakSignal).RegistryWrites();
        Assert.Contains(new RegistryWrite(RdpServerQuality.PolicyKey, "ImageQuality", 4), weak);
        Assert.Contains(new RegistryWrite(RdpServerQuality.PolicyKey, "GraphicsProfile", 3), weak);
    }

    [Fact]
    public void ReadsBackAndRecognisesPresets()
    {
        Assert.Equal(RdpPreset.Best, RdpServerQuality.FromRegistry(2, null, 15).Preset);
        Assert.Equal(RdpPreset.Balanced, RdpServerQuality.FromRegistry(null, null, null).Preset);
        Assert.Equal(RdpPreset.WeakSignal, RdpServerQuality.FromRegistry(4, 3, null).Preset);
        Assert.Null(RdpServerQuality.FromRegistry(1, 2, 15).Preset);   // lossless: custom
        Assert.Equal(RdpServerQuality.WindowsDefault, RdpServerQuality.FromRegistry(99, -1, 500));
    }

    [Fact]
    public void ParsesWhatTheIPadSends()
    {
        Assert.Equal(new RdpServerQuality(RdpImageQuality.Lossless, RdpGraphicsProfile.MinimumBandwidth, 60),
                     RdpServerQuality.Parse("lossless", "minimumBandwidth", 75));
        Assert.Equal(30, RdpServerQuality.Parse("high", "automatic", 24)!.FrameRate);
        Assert.Null(RdpServerQuality.Parse("ultra", "automatic", 30));
        Assert.Null(RdpServerQuality.Parse("high", "7", 30));
    }

    [Fact]
    public void OnlyTheOfficialRdpWrapperZipIsAccepted()
    {
        Assert.False(RdpWrapperRelease.IsOfficial(new MemoryStream(Encoding.UTF8.GetBytes("not the zip"))));
        Assert.Equal(64, RdpWrapperRelease.Sha256.Length);
        Assert.StartsWith("https://github.com/stascorp/rdpwrap/releases/download/", RdpWrapperRelease.DownloadUrl);
    }
}
