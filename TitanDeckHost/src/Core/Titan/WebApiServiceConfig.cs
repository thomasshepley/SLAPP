using System.Xml.Linq;
using TitanDeckHost.Core.Rdp;

namespace TitanDeckHost.Core.Titan;

/// <summary>
/// Titan 19's WebAPI service (Avolites\WebAPI\&lt;version&gt;\WebAPIService.dll.config),
/// the WebAPI on 4430 that TitanDeck uses. Titan 19.0 changed its calls;
/// 19.2 brought the older ones back behind "webapi.pre19Compatibility"
/// (Titan 19.2 release notes, Changes 1), which ships false. TitanDeck uses
/// the older calls, so with it off the keypad, Clear, Exit, fade times and
/// Layouts get HTTP 500 while playbacks still fire.
/// </summary>
public static class WebApiServiceConfig
{
    public const string Pre19Key = "webapi.pre19Compatibility";
    public const string FileName = "WebAPIService.dll.config";

    /// <summary>True/false for the switch, or null when the file doesn't have it (Titan 19.0/19.1, or not that file).</summary>
    public static bool? ReadPre19(string xml)
    {
        try
        {
            var settings = TitanUiConfig.AppSettings(XDocument.Parse(xml), create: false);
            var value = settings is null ? null : TitanUiConfig.Value(settings, Pre19Key);
            return value is null ? null : value.Trim().Equals("true", StringComparison.OrdinalIgnoreCase);
        }
        catch (System.Xml.XmlException)
        {
            return null;
        }
    }

    /// <summary>The same file with the switch on. Every other line is left exactly as it was.</summary>
    public static string TurnOnPre19(string xml)
    {
        var document = XDocument.Parse(xml, LoadOptions.PreserveWhitespace);
        var settings = TitanUiConfig.AppSettings(document, create: true)!;
        TitanUiConfig.Set(settings, Pre19Key, "true");
        return (document.Declaration?.ToString() ?? "") + document.ToString(SaveOptions.DisableFormatting);
    }

    public static bool IsServiceConfig(string path) =>
        path.Split('\\', '/').Last().Equals(FileName, StringComparison.OrdinalIgnoreCase);

    /// <summary>The checklist line, or null when there's no Titan 19.2+ WebAPI service here.</summary>
    public static Check? Diagnose(IReadOnlyList<bool?> switches)
    {
        const string id = "webapi19";
        const string title = "Titan 19 WebAPI calls";
        var known = switches.OfType<bool>().ToList();
        if (known.Count == 0) return null;
        if (known.All(on => on))
            return new Check(id, title, CheckState.Ok,
                "On: Titan's WebAPI accepts the calls TitanDeck uses (pre19Compatibility).");
        return new Check(id, title, CheckState.Problem,
            "Titan 19's WebAPI only takes its new calls (pre19Compatibility is off), so TitanDeck's keypad, Clear, Exit, " +
            "fade times and Layouts get HTTP 500 errors. Turn on Avolites' compatibility switch; the WebAPI restarts " +
            "(or restart Titan).", FixAction.EnableWebApiCompatibility, "Turn on");
    }
}
