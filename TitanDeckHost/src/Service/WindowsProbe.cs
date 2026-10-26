using System.Diagnostics;
using System.Net.NetworkInformation;
using System.Runtime.Versioning;
using System.ServiceProcess;
using Microsoft.Win32;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Net;
using TitanDeckHost.Core.Rdp;

namespace TitanDeckHost.Service;

/// <summary>Reads the PC's Remote Desktop set-up. Each fact is read on its own,
/// so one that can't be read leaves the rest intact (null = couldn't tell).</summary>
[SupportedOSPlatform("windows")]
public sealed class WindowsProbe
{
    public const string TerminalServerKey = @"SYSTEM\CurrentControlSet\Control\Terminal Server";
    public const string TermServiceParametersKey = @"SYSTEM\CurrentControlSet\Services\TermService\Parameters";
    public static readonly string DefaultRdpWrapperFolder =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "RDP Wrapper");

    private readonly HostPaths _paths;
    private readonly ILogger<WindowsProbe> _log;

    public WindowsProbe(HostPaths paths, ILogger<WindowsProbe> log)
    {
        _paths = paths;
        _log = log;
    }

    public const string LsaKey = @"SYSTEM\CurrentControlSet\Control\Lsa";

    public RdpFacts Gather()
    {
        var wrapperFolder = Try(RdpWrapperFolder, null);
        var termsrv = Try(TermsrvVersion, "");
        var installedIni = Try(() => ReadText(Path.Combine(wrapperFolder ?? DefaultRdpWrapperFolder, "rdpwrap.ini")), null);
        var installed = installedIni is null ? null : RdpWrapIni.Parse(installedIni);
        var best = RdpWrapIni.Best(IniCandidates(installedIni), termsrv);

        return new RdpFacts
        {
            Edition = Try(() => ReadString(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion", "EditionID") ?? "", ""),
            WindowsVersion = Try(WindowsVersion, ""),
            TermsrvVersion = termsrv,
            RemoteDesktopAllowed = Try(() => ReadInt(TerminalServerKey, "fDenyTSConnections") == 0, false),
            TermServiceRunning = Try(() => ServiceRunning("TermService"), false),
            ListeningOn3389 = Try(() => IPGlobalProperties.GetIPGlobalProperties().GetActiveTcpListeners().Any(e => e.Port == 3389), false),
            RdpWrapperInstalled = wrapperFolder is not null,
            RdpWrapperDllPresent = wrapperFolder is not null && File.Exists(Path.Combine(wrapperFolder, "rdpwrap.dll")),
            InstalledIniSupportsBuild = installed?.Supports(termsrv),
            BetterIniAvailable = best is { } b && b.Source != "installed" && b.Ini.Supports(termsrv),
            FirewallAllowsRdp = Try<bool?>(() => Firewall.AllowsInbound(3389), null),
            FirewallAllowsHost = Try<bool?>(() => Firewall.AllowsInbound(Protocol.NetworkPort), null),
            NetworkIsPrivate = Try(NetworkProfiles.AllConnectedArePrivate, null),
            DefenderExcludesRdpWrapper = Try<bool?>(() => DefenderExcludes(wrapperFolder ?? DefaultRdpWrapperFolder), null),
            RdpWrapperPackageAvailable = Try(() => RdpWrapperInstaller.FindPackage(_paths) is not null, false),
            TitanRunning = Try(TitanRunning, false),
            // Missing means Windows' default, 1.
            BlankPasswordsCanSignInRemotely = Try<bool?>(() => (ReadInt(LsaKey, "LimitBlankPasswordUse") ?? 1) == 0, null),
        };
    }

    /// <summary>Installed (if any), bundled and uploaded-from-iPad rdpwrap.ini files.</summary>
    public IEnumerable<(string Source, string? Text)> IniCandidates(string? installedText = null)
    {
        var folder = Try(RdpWrapperFolder, null) ?? DefaultRdpWrapperFolder;
        yield return ("installed", installedText ?? Try(() => ReadText(Path.Combine(folder, "rdpwrap.ini")), null));
        yield return ("bundled", Try(() => ReadText(_paths.BundledIni), null));
        yield return ("from iPad", Try(() => ReadText(_paths.UploadedIni), null));
    }

    /// <summary>Folder rdpwrap.dll is loaded from, when TermService uses RDP Wrapper.</summary>
    public static string? RdpWrapperFolder()
    {
        var dll = ReadString(TermServiceParametersKey, "ServiceDll");
        if (dll is null || !dll.Contains("rdpwrap", StringComparison.OrdinalIgnoreCase)) return null;
        return Path.GetDirectoryName(Environment.ExpandEnvironmentVariables(dll));
    }

    public static string TermsrvVersion()
    {
        var info = FileVersionInfo.GetVersionInfo(Path.Combine(Environment.SystemDirectory, "termsrv.dll"));
        return RdpWrapIni.TermsrvBuild(info.FileMajorPart, info.FileMinorPart, info.FileBuildPart, info.FilePrivatePart);
    }

    private static string WindowsVersion()
    {
        const string key = @"SOFTWARE\Microsoft\Windows NT\CurrentVersion";
        var name = ReadString(key, "ProductName") ?? "Windows";
        // ProductName still says "Windows 10" on Windows 11; the build number tells them apart.
        var build = ReadString(key, "CurrentBuild") ?? "";
        if (int.TryParse(build, out var number) && number >= 22000) name = name.Replace("Windows 10", "Windows 11");
        var display = ReadString(key, "DisplayVersion");
        var ubr = ReadInt(key, "UBR");
        return $"{name} {display} (build {build}{(ubr is null ? "" : $".{ubr}")})".Replace("  ", " ");
    }

    private static bool ServiceRunning(string name)
    {
        using var service = new ServiceController(name);
        return service.Status == ServiceControllerStatus.Running;
    }

    private static bool DefenderExcludes(string folder)
    {
        using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths");
        if (key is null) return false;
        var wanted = folder.TrimEnd('\\');
        return key.GetValueNames().Any(p => p.TrimEnd('\\').Equals(wanted, StringComparison.OrdinalIgnoreCase));
    }

    private static (DateTimeOffset At, bool Running) _titanSeen;

    /// <summary>Titan is running (checked at most every 2 s: it walks every process).</summary>
    public static bool IsTitanRunning()
    {
        var seen = _titanSeen;
        if (DateTimeOffset.UtcNow - seen.At < TimeSpan.FromSeconds(2)) return seen.Running;
        var running = TitanRunning();
        _titanSeen = (DateTimeOffset.UtcNow, running);
        return running;
    }

    private static bool TitanRunning()
    {
        var self = Process.GetCurrentProcess().ProcessName;
        return Process.GetProcesses().Any(p =>
            p.ProcessName.Contains("titan", StringComparison.OrdinalIgnoreCase)
            && !p.ProcessName.StartsWith("TitanDeckHost", StringComparison.OrdinalIgnoreCase)
            && p.ProcessName != self);
    }

    public static string? ReadString(string key, string name)
    {
        using var k = Registry.LocalMachine.OpenSubKey(key);
        return k?.GetValue(name) as string;
    }

    public static int? ReadInt(string key, string name)
    {
        using var k = Registry.LocalMachine.OpenSubKey(key);
        return k?.GetValue(name) is int value ? value : null;
    }

    private static string? ReadText(string path) => File.Exists(path) ? File.ReadAllText(path) : null;

    private T Try<T>(Func<T> read, T fallback)
    {
        try
        {
            return read();
        }
        catch (Exception error)
        {
            _log.LogDebug(error, "Probe step failed");
            return fallback;
        }
    }
}

/// <summary>Windows Firewall, through its COM interface (HNetCfg.FwPolicy2).</summary>
[SupportedOSPlatform("windows")]
public static class Firewall
{
    private const int InboundDirection = 1;
    private const int AllowAction = 1;
    private const int PrivateProfile = 2;
    private const int TcpProtocol = 6;

    /// <summary>True if an enabled inbound allow rule covers this TCP port on private networks.</summary>
    public static bool AllowsInbound(int port)
    {
        dynamic policy = Activator.CreateInstance(Type.GetTypeFromProgID("HNetCfg.FwPolicy2")!)!;
        foreach (dynamic rule in policy.Rules)
        {
            try
            {
                if ((int)rule.Direction != InboundDirection || !(bool)rule.Enabled || (int)rule.Action != AllowAction) continue;
                if (((int)rule.Profiles & PrivateProfile) == 0) continue;
                var protocol = (int)rule.Protocol;
                if (protocol != TcpProtocol && protocol != 256) continue;   // 256 = any
                if (PortList.Contains((string?)rule.LocalPorts, port)) return true;
            }
            catch
            {
                // Some rules don't expose every property; skip them.
            }
        }
        return false;
    }
}

/// <summary>Network location (Public/Private), through NetworkListManager's COM interface.</summary>
[SupportedOSPlatform("windows")]
public static class NetworkProfiles
{
    private static readonly Guid NetworkListManagerClsid = new("DCB00C01-570F-4A9B-8D69-199FDBA5723B");
    private const int Connected = 1;
    private const int PublicCategory = 0;
    private const int PrivateCategory = 1;

    public static bool? AllConnectedArePrivate()
    {
        dynamic manager = Activator.CreateInstance(Type.GetTypeFromCLSID(NetworkListManagerClsid)!)!;
        var any = false;
        foreach (dynamic network in manager.GetNetworks(Connected))
        {
            any = true;
            if ((int)network.GetCategory() == PublicCategory) return false;
        }
        return any ? true : null;
    }

    public static int MakeConnectedPrivate()
    {
        dynamic manager = Activator.CreateInstance(Type.GetTypeFromCLSID(NetworkListManagerClsid)!)!;
        var changed = 0;
        foreach (dynamic network in manager.GetNetworks(Connected))
        {
            if ((int)network.GetCategory() == PublicCategory)
            {
                network.SetCategory(PrivateCategory);
                changed++;
            }
        }
        return changed;
    }
}
