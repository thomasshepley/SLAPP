using TitanDeckHost.Core.Rdp;

public class RdpTests
{
    private const string Build = "10.0.26100.9549";

    private static string Ini(string updated, params string[] builds) =>
        $"; RDP Wrapper\r\n[Main]\r\nUpdated={updated}\r\nLogFile=\\rdpwrap.txt\r\n\r\n[SLPolicy]\r\nX=1\r\n" +
        string.Concat(builds.Select(b => $"\r\n[{b}]\r\nLocalOnlyPatch.x64=1\r\n\r\n[{b}-SLInit]\r\nbInitialized.x64=1\r\n"));

    [Fact]
    public void ParsesSectionsAndDate()
    {
        var ini = RdpWrapIni.Parse(Ini("2026-10-07", Build))!;
        Assert.Equal(new DateOnly(2026, 10, 7), ini.Updated);
        Assert.True(ini.Supports(Build));
        Assert.False(ini.Supports("10.0.26100.1"));
    }

    [Fact]
    public void NeedsBothThePatchAndSLInitSections()
    {
        var ini = RdpWrapIni.Parse("[Main]\nUpdated=2026-01-01\n[10.0.1.1]\nx=1\n")!;
        Assert.False(ini.Supports("10.0.1.1"));
    }

    [Fact]
    public void RejectsFilesThatAreNotRdpWrapIni()
    {
        Assert.Null(RdpWrapIni.Parse("<html>404</html>"));
        Assert.Null(RdpWrapIni.Parse(""));
    }

    [Fact]
    public void BestPrefersSupportThenNewest()
    {
        var installed = Ini("2025-01-01", "10.0.22631.1");
        var bundledOld = Ini("2026-05-01", Build);
        var uploadedNew = Ini("2026-10-07", Build);
        var newestButUseless = Ini("2026-12-01", "10.0.99999.1");
        var best = RdpWrapIni.Best(new[]
        {
            ("installed", installed), ("bundled", bundledOld), ("uploaded", uploadedNew),
            ("other", newestButUseless), ("missing", (string?)null), ("junk", "nope"),
        }, Build);
        Assert.Equal("uploaded", best?.Source);
        Assert.Null(RdpWrapIni.Best(Array.Empty<(string, string?)>(), Build));
    }

    // --- Diagnosis ---

    private static RdpFacts HealthyHome => new()
    {
        Edition = "Core", TermsrvVersion = Build, RemoteDesktopAllowed = true, TermServiceRunning = true,
        ListeningOn3389 = true, RdpWrapperInstalled = true, RdpWrapperDllPresent = true,
        InstalledIniSupportsBuild = true, FirewallAllowsRdp = true, FirewallAllowsHost = true,
        NetworkIsPrivate = true, DefenderExcludesRdpWrapper = true, TitanRunning = true,
    };

    [Fact]
    public void HealthyPcIsAllOk()
    {
        var checks = RdpDiagnosis.Run(HealthyHome);
        Assert.All(checks, c => Assert.Equal(CheckState.Ok, c.State));
        Assert.Equal(CheckState.Ok, RdpDiagnosis.Overall(checks));
    }

    [Fact]
    public void OutOfDateIniIsTheProblemWeHadAndOffersTheFix()
    {
        // The real case: Windows updated termsrv.dll, the old ini didn't know it.
        var facts = HealthyHome with { ListeningOn3389 = false, InstalledIniSupportsBuild = false, BetterIniAvailable = true };
        var checks = RdpDiagnosis.Run(facts);
        Assert.Equal(CheckState.Problem, RdpDiagnosis.Overall(checks));
        Assert.Contains(checks, c => c.Id == "ini" && c.Fix == FixAction.UpdateRdpWrapIni && c.Detail.Contains(Build));
        Assert.Contains(checks, c => c.Id == "listening" && c.Fix == FixAction.UpdateRdpWrapIni);
    }

    [Fact]
    public void WithoutABetterIniItSaysWhereToGetOne()
    {
        var facts = HealthyHome with { ListeningOn3389 = false, InstalledIniSupportsBuild = false };
        var ini = RdpDiagnosis.Run(facts).Single(c => c.Id == "ini");
        Assert.Equal(FixAction.None, ini.Fix);
        Assert.Contains("iPad", ini.Detail);
    }

    [Fact]
    public void ProDoesNotTalkAboutRdpWrapper()
    {
        var pro = HealthyHome with { Edition = "Professional", RdpWrapperInstalled = false, InstalledIniSupportsBuild = null };
        Assert.DoesNotContain(RdpDiagnosis.Run(pro), c => c.Id is "wrapper" or "ini" or "defender");
    }

    [Fact]
    public void DefenderEatingTheDllIsCalledOut()
    {
        var facts = HealthyHome with { RdpWrapperDllPresent = false, DefenderExcludesRdpWrapper = false };
        var checks = RdpDiagnosis.Run(facts);
        Assert.Contains(checks, c => c.Id == "wrapper" && c.State == CheckState.Problem && c.Fix == FixAction.AddDefenderExclusion);
    }

    [Fact]
    public void FirewallAndPublicNetworkAndTitan()
    {
        var facts = HealthyHome with { FirewallAllowsHost = false, NetworkIsPrivate = false, TitanRunning = false };
        var checks = RdpDiagnosis.Run(facts);
        Assert.Contains(checks, c => c.Id == "firewall" && c.Fix == FixAction.AddFirewallRules);
        Assert.Contains(checks, c => c.Id == "network" && c.Fix == FixAction.SetNetworkPrivate);
        Assert.Contains(checks, c => c.Id == "titan" && c.State == CheckState.Warning);
    }

    [Fact]
    public void RemoteDesktopOffAndServiceStopped()
    {
        var facts = HealthyHome with { RemoteDesktopAllowed = false, TermServiceRunning = false, ListeningOn3389 = false };
        var checks = RdpDiagnosis.Run(facts);
        Assert.Contains(checks, c => c.Id == "allowed" && c.Fix == FixAction.AllowRemoteDesktop);
        Assert.Contains(checks, c => c.Id == "service" && c.Fix == FixAction.StartRemoteDesktop);
        Assert.Equal("Turn on", checks.First(c => c.Id == "allowed").FixTitle);
    }

    [Fact]
    public void HomeWithoutWrapperOffersDownloadOrInstall()
    {
        var bare = HealthyHome with { RdpWrapperInstalled = false, ListeningOn3389 = false };
        var download = RdpDiagnosis.Run(bare).Single(c => c.Id == "wrapper");
        Assert.Equal(FixAction.InstallRdpWrapper, download.Fix);
        Assert.Equal("Download & install", download.FixTitle);
        var ready = RdpDiagnosis.Run(bare with { RdpWrapperPackageAvailable = true }).Single(c => c.Id == "wrapper");
        Assert.Equal(FixAction.InstallRdpWrapper, ready.Fix);
        Assert.Equal("Install", ready.FixTitle);
    }
}
