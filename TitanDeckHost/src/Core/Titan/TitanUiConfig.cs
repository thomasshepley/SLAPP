using System.Xml.Linq;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Rdp;

namespace TitanDeckHost.Core.Titan;

/// <summary>
/// Titan's second WebAPI, the one inside its user interface. Titan's normal
/// WebAPI (port 4430) is a separate user with its own programmer, so it never
/// sees what's selected on the desk. Titan 14+ can also run a WebAPI in the
/// UI itself ("webapi.enabled" in the Titan app's settings file, Titan.dll.config
/// from Titan 19 and Titan.exe.config before, which ships
/// with it set to false): that one shares the operator's selection and
/// programmer. Avolites call it experimental. Its usual port, 4431, is the
/// Host's, so TitanDeck uses 4433, and the Host passes it on to the iPad on
/// 4434 in case Titan only answers on the PC itself.
/// </summary>
public static class TitanUiConfig
{
    public const string EnabledKey = "webapi.enabled";
    public const string PortKey = "webapi.port";
    public const int UiPort = 4433;
    /// <summary>Titan's usual WebAPI port, the one TitanDeck always uses.</summary>
    public const int ApiPort = 4430;
    public const int ProxyPort = 4434;
    /// <summary>Titan's WebAPI (4430) through the Host, so every call TitanDeck makes shows in the Titan log.</summary>
    public const int PassThroughPort = 4436;
    public const string BackupSuffix = ".titandeck-backup";

    public sealed record State(bool Enabled, int? Port)
    {
        public int EffectivePort => Port ?? 4431;
    }

    /// <summary>
    /// Titan's own settings file: "Titan.dll.config" (Titan 19 runs on .NET 8)
    /// or "Titan.exe.config" (older Titans). Only Titan's: the WebAPI service's
    /// WebAPIService.dll.config has the same webapi.enabled / webapi.port keys,
    /// but they're the separate WebAPI on 4430 (its own user, which never sees
    /// the desk's selection), not one inside Titan.
    /// </summary>
    public static bool IsSettingsFileName(string path)
    {
        var name = path.Split('\\', '/').Last();
        return name.Equals("Titan.dll.config", StringComparison.OrdinalIgnoreCase)
            || name.Equals("Titan.exe.config", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>A Titan config file and what it says, or null for a file
    /// that isn't one of Titan's (no webapi.enabled key).</summary>
    public static State? Read(string xml)
    {
        try
        {
            var settings = AppSettings(XDocument.Parse(xml), create: false);
            if (settings is null) return null;
            var enabled = Value(settings, EnabledKey);
            if (enabled is null) return null;
            var port = int.TryParse(Value(settings, PortKey), out var p) ? p : (int?)null;
            return new State(enabled.Trim().Equals("true", StringComparison.OrdinalIgnoreCase), port);
        }
        catch (System.Xml.XmlException)
        {
            return null;
        }
    }

    /// <summary>The same file with the UI WebAPI turned on at `port`. Every
    /// other line is left exactly as it was.</summary>
    public static string Enable(string xml, int port = UiPort)
    {
        var document = XDocument.Parse(xml, LoadOptions.PreserveWhitespace);
        var settings = AppSettings(document, create: true)!;
        Set(settings, EnabledKey, "true");
        Set(settings, PortKey, port.ToString());
        // The original line break after the declaration is kept as whitespace in the document.
        return (document.Declaration?.ToString() ?? "") + document.ToString(SaveOptions.DisableFormatting);
    }

    /// <summary>
    /// What the desk-link proxy passes through to the operator's own UI:
    /// TitanDeck's calls (keypad, intensity, flash, palettes, playbacks,
    /// workspaces, handles, selection reads). Anything in a Patch namespace
    /// is refused - in Titan the Patch menu holds the programmer while it's
    /// open, and it must never be opened on the desk from the iPad - and so
    /// is anything not on the list.
    /// </summary>
    public static bool ProxyAllows(string path)
    {
        var p = path.TrimEnd('/');
        if (p.Contains("/Patch", StringComparison.OrdinalIgnoreCase)) return false;
        string[] allowed =
        [
            "/titan/get/System/SoftwareVersion",
            "/titan/get/2/Command/", "/titan/script/2/Command/",
            "/titan/script/2/Menu/ExitRootOrLatched",
            "/titan/script/2/Programmer/Editor/Fixtures/", "/titan/script/2/Playbacks/",
            "/titan/script/2/Palette/ApplyPalette", "/titan/script/2/Workspace/Apply", "/titan/script/2/Macros/Run",
            "/titan/script/2/Selection/Context/", "/titan/get/2/Programmer/Editor/Selection/",
            "/titan/get/2/Playbacks/Editor/Times/", "/titan/set/2/Playbacks/Editor/Times/",
            "/titan/handles/",
        ];
        return allowed.Any(a => a.EndsWith('/') ? p.StartsWith(a, StringComparison.OrdinalIgnoreCase)
                                                 : p.Equals(a, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>
    /// Some Titan installs already run their WebAPI inside the UI on 4430
    /// (webapi.enabled = true, webapi.port = 4430 in Titan's settings file).
    /// Then that's the desk's own WebAPI, there's no second one to add, and
    /// it must never be moved: TitanDeck uses it for everything.
    /// </summary>
    public static bool UiIsOnApiPort(IReadOnlyList<State> configs) =>
        configs.Any(c => c.Enabled && c.EffectivePort == ApiPort);

    /// <summary>Where the desk link passes calls on to: 4430 when that's the UI's WebAPI, else 4433.</summary>
    public static int TargetPort(IReadOnlyList<State> configs) => UiIsOnApiPort(configs) ? ApiPort : UiPort;

    /// <summary>The checklist line for the Host window and the iPad.</summary>
    public static Check Diagnose(IReadOnlyList<State> configs, bool uiAnswers, bool titanRunning)
    {
        const string id = "desklink";
        const string title = "Desk selection for TitanDeck";
        if (UiIsOnApiPort(configs))
            return uiAnswers || !titanRunning
                ? new Check(id, title, CheckState.Ok,
                    $"Nothing to change: Titan's settings file already runs its WebAPI inside Titan on port {ApiPort}, " +
                    "the one TitanDeck uses, so the desk link uses it too.")
                : new Check(id, title, CheckState.Warning,
                    $"Titan's WebAPI is set up in its settings file on port {ApiPort}, but isn't answering. Is Titan's WebAPI on?");
        if (uiAnswers)
            return new Check(id, title, CheckState.Ok,
                $"On. TitanDeck can follow what's selected on the desk (Titan's UI WebAPI, port {UiPort}).");
        if (configs.Count == 0)
            return new Check(id, title, CheckState.Warning,
                "Couldn't find Titan's settings file with webapi.enabled in it (Titan.dll.config in Titan 19's folder, " +
                "Titan.exe.config in older versions). Add webapi.enabled = true " +
                $"and webapi.port = {UiPort} to it by hand, then restart Titan.");
        if (configs.Any(c => c.Enabled && c.EffectivePort == Protocol.NetworkPort))
            return new Check(id, title, CheckState.Problem,
                $"Titan's UI WebAPI is set to port {Protocol.NetworkPort}, which the Host uses. Move it to {UiPort}.",
                FixAction.EnableDeskLink, "Move to " + UiPort);
        if (configs.Any(c => c.Enabled && c.EffectivePort == UiPort))
            return new Check(id, title, CheckState.Warning, titanRunning
                ? "Turned on, but Titan isn't answering on it yet. Restart Titan to start it."
                : "Turned on. It starts with Titan.");
        if (configs.Any(c => c.Enabled))
            return new Check(id, title, CheckState.Warning,
                $"Titan's UI WebAPI is on a different port ({configs.First(c => c.Enabled).EffectivePort}). TitanDeck expects {UiPort}.",
                FixAction.EnableDeskLink, "Move to " + UiPort);
        return new Check(id, title, CheckState.Warning,
            "Off. Turn it on so TitanDeck can follow what you select in Layouts or on the desk " +
            "(Titan's experimental UI WebAPI; needs a Titan restart).", FixAction.EnableDeskLink, "Turn on");
    }

    internal static XElement? AppSettings(XDocument document, bool create)
    {
        var root = document.Root;
        if (root is null || root.Name.LocalName != "configuration") return null;
        var settings = root.Element("appSettings");
        if (settings is null && create)
        {
            settings = new XElement("appSettings");
            root.Add(settings);
        }
        return settings;
    }

    internal static string? Value(XElement settings, string key) =>
        settings.Elements("add").FirstOrDefault(e => (string?)e.Attribute("key") == key)?.Attribute("value")?.Value;

    internal static void Set(XElement settings, string key, string value)
    {
        var entry = settings.Elements("add").FirstOrDefault(e => (string?)e.Attribute("key") == key);
        if (entry is null) settings.Add(new XElement("add", new XAttribute("key", key), new XAttribute("value", value)));
        else entry.SetAttributeValue("value", value);
    }
}
