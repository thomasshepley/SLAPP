namespace TitanDeckHost.Core.Rdp;

/// <summary>What the Host found out about the PC. Null means "couldn't tell".</summary>
public sealed record RdpFacts
{
    /// <summary>Windows EditionID: "Core" is Home, "Professional" is Pro.</summary>
    public string Edition { get; init; } = "";
    public string WindowsVersion { get; init; } = "";
    /// <summary>termsrv.dll build, e.g. "10.0.26100.9549".</summary>
    public string TermsrvVersion { get; init; } = "";
    /// <summary>fDenyTSConnections is 0.</summary>
    public bool RemoteDesktopAllowed { get; init; }
    public bool TermServiceRunning { get; init; }
    /// <summary>Something is accepting connections on TCP 3389.</summary>
    public bool ListeningOn3389 { get; init; }
    /// <summary>TermService loads rdpwrap.dll (RDP Wrapper is installed).</summary>
    public bool RdpWrapperInstalled { get; init; }
    public bool RdpWrapperDllPresent { get; init; }
    /// <summary>The installed rdpwrap.ini covers this termsrv.dll build.</summary>
    public bool? InstalledIniSupportsBuild { get; init; }
    /// <summary>A newer or better rdpwrap.ini is available (bundled or from the iPad).</summary>
    public bool BetterIniAvailable { get; init; }
    public bool? FirewallAllowsRdp { get; init; }
    public bool? FirewallAllowsHost { get; init; }
    public bool? NetworkIsPrivate { get; init; }
    public bool? DefenderExcludesRdpWrapper { get; init; }
    public bool RdpWrapperPackageAvailable { get; init; }
    public bool TitanRunning { get; init; }

    public bool IsHome => Edition.StartsWith("Core", StringComparison.OrdinalIgnoreCase);
}

public enum CheckState { Ok, Warning, Problem }

/// <summary>Fixes the Host can apply with one click.</summary>
public enum FixAction
{
    None,
    AllowRemoteDesktop,
    StartRemoteDesktop,
    RestartRemoteDesktop,
    UpdateRdpWrapIni,
    AddFirewallRules,
    SetNetworkPrivate,
    AddDefenderExclusion,
    InstallRdpWrapper,
}

public sealed record Check(string Id, string Title, CheckState State, string Detail, FixAction Fix = FixAction.None,
                           string? FixLabel = null)
{
    public string FixTitle => FixLabel ?? Fix switch
    {
        FixAction.AllowRemoteDesktop => "Turn on",
        FixAction.StartRemoteDesktop => "Start",
        FixAction.RestartRemoteDesktop => "Restart",
        FixAction.UpdateRdpWrapIni => "Update",
        FixAction.AddFirewallRules => "Allow",
        FixAction.SetNetworkPrivate => "Make private",
        FixAction.AddDefenderExclusion => "Add exclusion",
        FixAction.InstallRdpWrapper => "Install",
        _ => "",
    };
}

/// <summary>Turns facts into a short, plain-English checklist with fixes.</summary>
public static class RdpDiagnosis
{
    public static IReadOnlyList<Check> Run(RdpFacts f)
    {
        var checks = new List<Check>();

        checks.Add(f.RemoteDesktopAllowed
            ? new Check("allowed", "Remote Desktop allowed", CheckState.Ok, "Windows accepts remote connections.")
            : new Check("allowed", "Remote Desktop allowed", CheckState.Problem,
                        "Windows is set to refuse remote connections.", FixAction.AllowRemoteDesktop));

        if (f.IsHome)
        {
            if (!f.RdpWrapperInstalled)
            {
                checks.Add(new Check("wrapper", "RDP Wrapper", CheckState.Problem,
                    f.RdpWrapperPackageAvailable
                        ? $"Windows Home needs RDP Wrapper for Remote Desktop. The official v{RdpWrapperRelease.Version} package is here, ready to install."
                        : $"Windows Home needs RDP Wrapper for Remote Desktop. The Host downloads the official v{RdpWrapperRelease.Version} release and checks it before installing. No internet on this PC? Send it from TitanDeck instead.",
                    FixAction.InstallRdpWrapper,
                    f.RdpWrapperPackageAvailable ? "Install" : "Download & install"));
            }
            else if (!f.RdpWrapperDllPresent)
            {
                checks.Add(new Check("wrapper", "RDP Wrapper", CheckState.Problem,
                    "RDP Wrapper's rdpwrap.dll is missing - usually Windows Defender removed it. Add the exclusion, then restore it from Defender's Protection history or reinstall.",
                    FixAction.AddDefenderExclusion));
            }
            else
            {
                checks.Add(new Check("wrapper", "RDP Wrapper", CheckState.Ok, "Installed."));
                if (f.InstalledIniSupportsBuild == false)
                {
                    checks.Add(new Check("ini", "RDP Wrapper config", CheckState.Problem,
                        f.BetterIniAvailable
                            ? $"It doesn't know this Windows build ({f.TermsrvVersion}), so Remote Desktop can't listen. A newer config is ready."
                            : $"It doesn't know this Windows build ({f.TermsrvVersion}), so Remote Desktop can't listen. Send a newer rdpwrap.ini from the iPad when it has internet.",
                        f.BetterIniAvailable ? FixAction.UpdateRdpWrapIni : FixAction.None));
                }
                else if (f.InstalledIniSupportsBuild == true)
                {
                    checks.Add(new Check("ini", "RDP Wrapper config", CheckState.Ok,
                        $"Knows this Windows build ({f.TermsrvVersion})."));
                }
            }

            if (f.RdpWrapperInstalled && f.DefenderExcludesRdpWrapper == false)
            {
                checks.Add(new Check("defender", "Defender exclusion", CheckState.Warning,
                    "Windows Defender treats RDP Wrapper as a hacking tool and may delete it after an update. An exclusion for its folder stops that.",
                    FixAction.AddDefenderExclusion));
            }
        }

        if (!f.TermServiceRunning)
        {
            checks.Add(new Check("service", "Remote Desktop service", CheckState.Problem, "Not running.",
                FixAction.StartRemoteDesktop));
        }
        else if (!f.ListeningOn3389)
        {
            checks.Add(new Check("listening", "Listening for TitanDeck", CheckState.Problem,
                "The Remote Desktop service is running but not accepting connections on port 3389.",
                f.IsHome && f.InstalledIniSupportsBuild == false && f.BetterIniAvailable
                    ? FixAction.UpdateRdpWrapIni : FixAction.RestartRemoteDesktop));
        }
        else
        {
            checks.Add(new Check("listening", "Listening for TitanDeck", CheckState.Ok, "Port 3389 is open."));
        }

        if (f.FirewallAllowsRdp == false || f.FirewallAllowsHost == false)
        {
            checks.Add(new Check("firewall", "Firewall", CheckState.Problem,
                "Windows Firewall is blocking TitanDeck (Remote Desktop, Titan's WebAPI or the Host).",
                FixAction.AddFirewallRules));
        }
        else if (f.FirewallAllowsRdp == true)
        {
            checks.Add(new Check("firewall", "Firewall", CheckState.Ok, "TitanDeck's ports are allowed."));
        }

        if (f.NetworkIsPrivate == false)
        {
            checks.Add(new Check("network", "Network profile", CheckState.Warning,
                "The show network is set to Public, so Windows blocks most local connections.",
                FixAction.SetNetworkPrivate));
        }

        checks.Add(f.TitanRunning
            ? new Check("titan", "Titan", CheckState.Ok, "Running.")
            : new Check("titan", "Titan", CheckState.Warning, "Titan isn't running. The deck needs it; remote desktop doesn't."));

        return checks;
    }

    public static CheckState Overall(IEnumerable<Check> checks) =>
        checks.Select(c => c.State).DefaultIfEmpty(CheckState.Ok).Max();
}
