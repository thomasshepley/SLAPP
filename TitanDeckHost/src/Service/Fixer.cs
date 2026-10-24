using System.Diagnostics;
using System.IO.Compression;
using System.Runtime.Versioning;
using System.ServiceProcess;
using Microsoft.Win32;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Rdp;

namespace TitanDeckHost.Service;

/// <summary>Applies the one-click fixes from the checklist. Runs as LocalSystem.</summary>
[SupportedOSPlatform("windows")]
public sealed class Fixer
{
    /// <summary>Fixes a paired iPad may ask for. Ones that weaken the PC's defences
    /// (Defender exclusion, network profile, installing RDP Wrapper) need a click on the PC.</summary>
    public static readonly IReadOnlySet<FixAction> AllowedFromIPad = new HashSet<FixAction>
    {
        FixAction.AllowRemoteDesktop, FixAction.StartRemoteDesktop, FixAction.RestartRemoteDesktop,
        FixAction.UpdateRdpWrapIni, FixAction.AddFirewallRules,
    };

    private readonly HostPaths _paths;
    private readonly WindowsProbe _probe;
    private readonly ILogger<Fixer> _log;
    private readonly SemaphoreSlim _oneAtATime = new(1, 1);

    public Fixer(HostPaths paths, WindowsProbe probe, ILogger<Fixer> log)
    {
        _paths = paths;
        _probe = probe;
        _log = log;
    }

    public async Task<FixResponse> Apply(FixAction action)
    {
        await _oneAtATime.WaitAsync();
        try
        {
            _log.LogInformation("Fix: {Action}", action);
            var message = action switch
            {
                FixAction.AllowRemoteDesktop => AllowRemoteDesktop(),
                FixAction.StartRemoteDesktop => await RestartRemoteDesktop(startOnly: true),
                FixAction.RestartRemoteDesktop => await RestartRemoteDesktop(startOnly: false),
                FixAction.UpdateRdpWrapIni => await UpdateRdpWrapIni(),
                FixAction.AddFirewallRules => AddFirewallRules(),
                FixAction.SetNetworkPrivate => $"Set {NetworkProfiles.MakeConnectedPrivate()} network(s) to Private.",
                FixAction.AddDefenderExclusion => AddDefenderExclusion(),
                FixAction.InstallRdpWrapper => await InstallRdpWrapper(),
                _ => throw new InvalidOperationException("Nothing to do."),
            };
            return new FixResponse(true, message);
        }
        catch (Exception error)
        {
            _log.LogWarning(error, "Fix {Action} failed", action);
            return new FixResponse(false, error.Message);
        }
        finally
        {
            _oneAtATime.Release();
        }
    }

    private static string AllowRemoteDesktop()
    {
        using var key = Registry.LocalMachine.OpenSubKey(WindowsProbe.TerminalServerKey, writable: true)
                        ?? throw new InvalidOperationException("Remote Desktop settings not found in the registry.");
        key.SetValue("fDenyTSConnections", 0, RegistryValueKind.DWord);
        AddFirewallRules();
        return "Remote Desktop is allowed.";
    }

    /// <summary>Restarts TermService (and with it the Remote Desktop listener).</summary>
    private async Task<string> RestartRemoteDesktop(bool startOnly)
    {
        if (!startOnly) await StopTermService();
        await StartTermService();
        return "Remote Desktop service restarted.";
    }

    private async Task StopTermService()
    {
        using var service = new ServiceController("TermService");
        service.Refresh();
        if (service.Status == ServiceControllerStatus.Stopped) return;
        try
        {
            // Also stops services that depend on it (UmRdpService).
            service.Stop();
            service.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(20));
        }
        catch (Exception error) when (error is System.ServiceProcess.TimeoutException or InvalidOperationException)
        {
            // TermService often refuses to stop; ending its process is the standard way round.
            _log.LogInformation("TermService wouldn't stop; ending its process");
            await Run("taskkill", "/F /FI \"SERVICES eq TermService\"");
            await Task.Delay(1500);
        }
    }

    private static async Task StartTermService()
    {
        foreach (var name in new[] { "TermService", "UmRdpService" })
        {
            try
            {
                using var service = new ServiceController(name);
                service.Refresh();
                if (service.Status != ServiceControllerStatus.Running)
                {
                    service.Start();
                    service.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(20));
                }
            }
            catch (InvalidOperationException) when (name == "UmRdpService")
            {
                // Optional helper service; not on every PC.
            }
        }
        await Task.Delay(500);
    }

    /// <summary>Installs the best rdpwrap.ini (bundled or from the iPad) and restarts Remote Desktop.</summary>
    private async Task<string> UpdateRdpWrapIni()
    {
        var folder = WindowsProbe.RdpWrapperFolder()
                     ?? throw new InvalidOperationException("RDP Wrapper isn't installed.");
        var build = WindowsProbe.TermsrvVersion();
        var best = RdpWrapIni.Best(_probe.IniCandidates(), build)
                   ?? throw new InvalidOperationException("No rdpwrap.ini available.");
        if (!best.Ini.Supports(build))
            throw new InvalidOperationException($"None of the rdpwrap.ini files know Windows build {build} yet. Send a newer one from the iPad.");
        if (best.Source == "installed")
            return "The installed rdpwrap.ini is already the best one.";

        var target = Path.Combine(folder, "rdpwrap.ini");
        await StopTermService();
        if (File.Exists(target)) File.Copy(target, $"{target}.bak-{DateTime.Now:yyyyMMdd-HHmmss}", overwrite: true);
        await File.WriteAllTextAsync(target, best.Ini.Text);
        await StartTermService();
        return $"Installed the {best.Source} rdpwrap.ini (updated {best.Ini.Updated:yyyy-MM-dd}) and restarted Remote Desktop.";
    }

    private const string RulePrefix = "TitanDeck - ";

    /// <summary>Private and domain networks only; never Public.</summary>
    private static string AddFirewallRules()
    {
        var rules = new (string Name, string Protocol, int Port)[]
        {
            ("Remote Desktop (TCP)", "TCP", 3389),
            ("Remote Desktop (UDP)", "UDP", 3389),
            ("Titan WebAPI", "TCP", 4430),
            ("Host", "TCP", Protocol.NetworkPort),
            ("Host discovery", "UDP", 5353),
        };
        foreach (var rule in rules)
        {
            RunSync("netsh", $"advfirewall firewall delete rule name=\"{RulePrefix}{rule.Name}\"");
            RunSync("netsh", $"advfirewall firewall add rule name=\"{RulePrefix}{rule.Name}\" dir=in action=allow " +
                             $"protocol={rule.Protocol} localport={rule.Port} profile=private,domain");
        }
        return "Firewall rules added for Remote Desktop, Titan and the Host (private networks).";
    }

    private static string AddDefenderExclusion()
    {
        var folder = WindowsProbe.RdpWrapperFolder() ?? WindowsProbe.DefaultRdpWrapperFolder;
        var exitCode = RunSync("powershell", $"-NoProfile -NonInteractive -Command \"Add-MpPreference -ExclusionPath '{folder}'\"");
        if (exitCode != 0) throw new InvalidOperationException("Windows Security refused the exclusion (Tamper Protection may block it - add it by hand in Windows Security).");
        return $"Windows Defender will leave {folder} alone.";
    }

    /// <summary>Installs RDP Wrapper from the official release package, then the best rdpwrap.ini.</summary>
    private async Task<string> InstallRdpWrapper()
    {
        var installer = RdpWrapperInstaller.FindPackage(_paths)
                        ?? throw new InvalidOperationException("Put the RDP Wrapper release zip (RDPWrap-v1.6.2.zip) in the To PC folder first.");
        // Exclude both folders first, or Defender removes the files mid-install.
        RunSync("powershell", "-NoProfile -NonInteractive -Command \"Add-MpPreference -ExclusionPath " +
                              $"'{WindowsProbe.DefaultRdpWrapperFolder}','{_paths.RdpWrapperPackage}'\"");
        var exe = RdpWrapperInstaller.Unpack(installer, _paths);
        var exitCode = await Run(exe, "-i");
        if (exitCode != 0) throw new InvalidOperationException($"RDP Wrapper's installer exited with code {exitCode}.");
        try
        {
            await UpdateRdpWrapIni();
        }
        catch (InvalidOperationException)
        {
            // Installed, but no config knows this build yet - the checklist will say so.
        }
        AddFirewallRules();
        return "RDP Wrapper installed.";
    }

    private static int RunSync(string file, string arguments) => Run(file, arguments).GetAwaiter().GetResult();

    private static async Task<int> Run(string file, string arguments)
    {
        using var process = Process.Start(new ProcessStartInfo(file, arguments)
        {
            CreateNoWindow = true,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        }) ?? throw new InvalidOperationException($"Couldn't run {file}.");
        await process.WaitForExitAsync();
        return process.ExitCode;
    }
}

/// <summary>Finds and unpacks the official RDP Wrapper release (github.com/stascorp/rdpwrap).
/// It isn't bundled: Defender flags its files, which would quarantine the whole Host installer.</summary>
public static class RdpWrapperInstaller
{
    /// <summary>RDPWInst.exe, or a release zip containing it, wherever the user put it.</summary>
    public static string? FindPackage(HostPaths paths)
    {
        var unpacked = Path.Combine(paths.RdpWrapperPackage, "RDPWInst.exe");
        if (File.Exists(unpacked)) return unpacked;
        foreach (var folder in new[] { paths.ToPC, paths.Data })
        {
            if (!Directory.Exists(folder)) continue;
            var zip = Directory.EnumerateFiles(folder, "RDPWrap*.zip").OrderByDescending(File.GetLastWriteTimeUtc).FirstOrDefault();
            if (zip is not null) return zip;
        }
        return null;
    }

    /// <summary>Returns the path of RDPWInst.exe, unzipping first if needed.</summary>
    public static string Unpack(string package, HostPaths paths)
    {
        if (package.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) return package;
        Directory.CreateDirectory(paths.RdpWrapperPackage);
        ZipFile.ExtractToDirectory(package, paths.RdpWrapperPackage, overwriteFiles: true);
        return Directory.EnumerateFiles(paths.RdpWrapperPackage, "RDPWInst.exe", SearchOption.AllDirectories).FirstOrDefault()
               ?? throw new InvalidOperationException("That zip doesn't contain RDPWInst.exe.");
    }
}
