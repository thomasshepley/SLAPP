using System.Globalization;

namespace TitanDeckHost.Core.Rdp;

/// <summary>
/// RDP Wrapper's config file. It holds patch offsets for each Windows build of
/// termsrv.dll; when Windows updates termsrv.dll to a build the file doesn't
/// list, Remote Desktop silently stops listening. A build is supported when the
/// file has both a "[10.0.x.y]" section and its "[10.0.x.y-SLInit]" section.
/// </summary>
public sealed class RdpWrapIni
{
    public string Text { get; }
    /// <summary>[Main] Updated=, e.g. 2026-10-07. Null if missing or unreadable.</summary>
    public DateOnly? Updated { get; }
    public IReadOnlySet<string> Sections { get; }

    private RdpWrapIni(string text, DateOnly? updated, HashSet<string> sections)
    {
        Text = text;
        Updated = updated;
        Sections = sections;
    }

    /// <summary>Parses the file, or returns null if it isn't an rdpwrap.ini at all.</summary>
    public static RdpWrapIni? Parse(string text)
    {
        var sections = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        DateOnly? updated = null;
        var section = "";
        foreach (var raw in text.Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith(';')) continue;
            if (line.StartsWith('[') && line.EndsWith(']'))
            {
                section = line[1..^1].Trim();
                sections.Add(section);
            }
            else if (section.Equals("Main", StringComparison.OrdinalIgnoreCase)
                     && line.StartsWith("Updated=", StringComparison.OrdinalIgnoreCase)
                     && DateOnly.TryParseExact(line["Updated=".Length..].Trim(), "yyyy-MM-dd",
                                               CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
            {
                updated = date;
            }
        }
        return sections.Contains("Main") ? new RdpWrapIni(text, updated, sections) : null;
    }

    /// <summary>True if the file has patches for this termsrv.dll build ("10.0.26100.9549").</summary>
    public bool Supports(string termsrvVersion) =>
        Sections.Contains(termsrvVersion) && Sections.Contains(termsrvVersion + "-SLInit");

    /// <summary>
    /// The best of several candidate files for a termsrv.dll build: ones that
    /// support it win, then the most recently updated.
    /// </summary>
    public static (string Source, RdpWrapIni Ini)? Best(IEnumerable<(string Source, string? Text)> candidates, string termsrvVersion)
    {
        return candidates
            .Where(c => c.Text is not null)
            .Select(c => (c.Source, Ini: Parse(c.Text!)))
            .Where(c => c.Ini is not null)
            .Select(c => (c.Source, Ini: c.Ini!))
            .OrderByDescending(c => c.Ini.Supports(termsrvVersion))
            .ThenByDescending(c => c.Ini.Updated ?? DateOnly.MinValue)
            .Select(c => ((string Source, RdpWrapIni Ini)?)c)
            .FirstOrDefault();
    }
}
