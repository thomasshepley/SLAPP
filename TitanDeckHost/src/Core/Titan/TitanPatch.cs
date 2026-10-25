using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace TitanDeckHost.Core.Titan;

/// <summary>
/// One patched fixture from Titan's patch report: its user number, where it
/// starts (DMX line and address, both 1-based) and, when the report says,
/// how many channels it takes. <c>Intensity</c> is the channels its level is
/// on, counted from the start (0 = the first channel), once its personality
/// has been found: one channel, a coarse/fine pair, or (a fixture with no
/// dimmer channel) its colour channels, the brightest of which is its level.
/// </summary>
public sealed record PatchFixture(int UserNumber, string? Model, string? Mode, int Line, int Address,
                                  int? Channels = null, IReadOnlyList<int>? Intensity = null, string? Legend = null);

/// <summary>
/// Reads the patch out of a report Titan writes (Disk &gt; Reports, the
/// Fixtures / "Patch View" section) as CSV, XML or HTML. The column names
/// aren't documented, so it looks for a user-number column and an address
/// column by name, in whichever row names them, and ignores everything else
/// in the report. Address text like "1.36" is line 1, address 36. Cells of a
/// multi-cell fixture ("2.1", "2.2") are skipped: the fixture's own row
/// carries its start address.
/// </summary>
public static class TitanPatch
{
    /// <summary>Reports bigger than this aren't read (a patch report is a few hundred KB at most).</summary>
    public const long MaxReportBytes = 20 * 1024 * 1024;

    public static IReadOnlyList<PatchFixture> Parse(string text, string fileName = "")
    {
        var trimmed = text.TrimStart('﻿', ' ', '\t', '\r', '\n');
        var extension = Path.GetExtension(fileName).ToLowerInvariant();
        List<Dictionary<string, string>> rows;
        if (extension is ".htm" or ".html" || (trimmed.StartsWith('<') && Regex.IsMatch(trimmed, "<table", RegexOptions.IgnoreCase)))
            rows = Table(HtmlRows(trimmed));
        else if (extension == ".xml" || trimmed.StartsWith('<'))
            rows = XmlRows(trimmed);
        else
            rows = Table(CsvRows(trimmed));

        var fixtures = new List<PatchFixture>();
        var seen = new HashSet<int>();
        foreach (var row in rows)
        {
            if (Pick(row, IsUserKey) is not { } userText || !int.TryParse(userText.Trim(), out var user) || user <= 0) continue;
            if (Pick(row, IsAddressKey) is not { } addressText || ParseAddress(addressText) is not { } address) continue;
            if (!seen.Add(user)) continue;
            var mode = Clean(Pick(row, IsModeKey));
            var channels = ParseChannels(mode) ?? (int.TryParse(Pick(row, IsChannelsKey), out var n) && n > 0 ? n : null);
            fixtures.Add(new PatchFixture(user, Clean(Pick(row, IsModelKey)), mode, address.Line, address.Address,
                                          channels, null, Clean(Pick(row, IsLegendKey))));
        }
        return fixtures;
    }

    /// <summary>
    /// "1.36", "1:36", "1/36", "A.36" (line A = 1), "U1 36", or one absolute
    /// channel (513 = line 2, address 1). The first address wins when a
    /// fixture is patched twice. Nil for "Unpatched", blanks and nonsense.
    /// </summary>
    public static (int Line, int Address)? ParseAddress(string text)
    {
        var match = Regex.Match(text, @"(?<![\w.])(?:U\s*)?([A-Za-z]|\d{1,5})\s*[.:/\-\s]\s*(\d{1,3})(?![\d.])");
        if (match.Success)
        {
            var lineText = match.Groups[1].Value;
            var line = char.IsLetter(lineText[0]) ? char.ToUpperInvariant(lineText[0]) - 'A' + 1 : int.Parse(lineText);
            var address = int.Parse(match.Groups[2].Value);
            return line >= 1 && address is >= 1 and <= 512 ? (line, address) : null;
        }
        var whole = Regex.Match(text.Trim(), @"^(\d{1,7})$");
        if (!whole.Success || !int.TryParse(whole.Value, out var absolute) || absolute < 1) return null;
        return ((absolute - 1) / 512 + 1, (absolute - 1) % 512 + 1);
    }

    /// <summary>"Mode 1, 35 DMX" or "Extended (16ch)": 35, 16.</summary>
    public static int? ParseChannels(string? mode)
    {
        if (string.IsNullOrEmpty(mode)) return null;
        var match = Regex.Match(mode, @"(\d{1,3})\s*(?:DMX|ch\b|chan|channels?)", RegexOptions.IgnoreCase);
        return match.Success && int.Parse(match.Groups[1].Value) is var n and > 0 and <= 512 ? n : null;
    }

    // --- Columns, whatever Titan calls them ---

    private static string Key(string name) => new(name.ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());

    private static bool IsUserKey(string k) =>
        k.StartsWith("user") || k is "no" or "number" or "fixtureno" or "fixturenumber" or "fixtureid" or "id";
    private static bool IsAddressKey(string k) =>
        k is "address" or "dmxaddress" or "dmx" or "patch" or "dmxpatch" or "patchaddress" or "startaddress"
            or "dmxline" or "lineaddress" || k.EndsWith("address");
    private static bool IsModeKey(string k) => k is "mode" or "dmxmode" or "personalitymode";
    private static bool IsModelKey(string k) =>
        k is "fixture" or "fixturetype" or "type" or "model" or "personality" or "fixturename";
    private static bool IsLegendKey(string k) => k is "legend" or "label" or "name";
    private static bool IsChannelsKey(string k) => k is "channels" or "footprint" or "dmxchannels" or "channelcount";

    private static string? Pick(Dictionary<string, string> row, Func<string, bool> wanted)
    {
        foreach (var (key, value) in row)
            if (wanted(key) && !string.IsNullOrWhiteSpace(value)) return value;
        return null;
    }

    private static string? Clean(string? text) =>
        string.IsNullOrWhiteSpace(text) ? null : Regex.Replace(text.Trim(), @"\s+", " ");

    /// <summary>Rows of cells to rows by column name: a row that names a user-number and an address column is a header for the rows after it.</summary>
    private static List<Dictionary<string, string>> Table(IEnumerable<List<string>> cells)
    {
        var rows = new List<Dictionary<string, string>>();
        List<string>? header = null;
        foreach (var row in cells)
        {
            var keys = row.Select(Key).ToList();
            if (keys.Any(IsUserKey) && keys.Any(IsAddressKey) && !row.Any(c => ParseAddress(c) is not null && Regex.IsMatch(c, @"\d")))
            {
                header = keys;
                continue;
            }
            if (header is null) continue;
            var named = new Dictionary<string, string>();
            for (var i = 0; i < Math.Min(header.Count, row.Count); i++)
                if (header[i].Length > 0 && !named.ContainsKey(header[i])) named[header[i]] = row[i];
            rows.Add(named);
        }
        return rows;
    }

    // --- CSV ---

    private static IEnumerable<List<string>> CsvRows(string text)
    {
        var sample = string.Join("\n", text.Split('\n').Take(20));
        var delimiter = new[] { ',', ';', '\t' }.OrderByDescending(d => sample.Count(c => c == d)).First();
        var row = new List<string>();
        var cell = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (quoted)
            {
                if (c == '"' && i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; }
                else if (c == '"') quoted = false;
                else cell.Append(c);
            }
            else if (c == '"') quoted = true;
            else if (c == delimiter) { row.Add(cell.ToString()); cell.Clear(); }
            else if (c == '\n')
            {
                row.Add(cell.ToString().TrimEnd('\r'));
                cell.Clear();
                yield return row;
                row = new List<string>();
            }
            else cell.Append(c);
        }
        if (cell.Length > 0 || row.Count > 0)
        {
            row.Add(cell.ToString().TrimEnd('\r'));
            yield return row;
        }
    }

    // --- HTML (the report Titan opens in a browser) ---

    private static IEnumerable<List<string>> HtmlRows(string html)
    {
        foreach (Match tr in Regex.Matches(html, @"<tr\b[^>]*>(.*?)</tr\s*>", RegexOptions.IgnoreCase | RegexOptions.Singleline))
        {
            yield return Regex.Matches(tr.Groups[1].Value, @"<t[hd]\b[^>]*>(.*?)</t[hd]\s*>", RegexOptions.IgnoreCase | RegexOptions.Singleline)
                .Select(td => WebUtility.HtmlDecode(Regex.Replace(td.Groups[1].Value, "<[^>]+>", " ")).Trim())
                .ToList();
        }
    }

    // --- XML: any element whose attributes or plain child elements name a user number and an address ---

    private static List<Dictionary<string, string>> XmlRows(string xml)
    {
        XDocument document;
        try
        {
            document = XDocument.Parse(xml);
        }
        catch (Exception)
        {
            return [];
        }
        var rows = new List<Dictionary<string, string>>();
        foreach (var element in document.Descendants())
        {
            var named = new Dictionary<string, string>();
            foreach (var attribute in element.Attributes()) named.TryAdd(Key(attribute.Name.LocalName), attribute.Value);
            foreach (var child in element.Elements().Where(e => !e.HasElements)) named.TryAdd(Key(child.Name.LocalName), child.Value);
            if (named.Keys.Any(IsUserKey) && named.Keys.Any(IsAddressKey)) rows.Add(named);
        }
        // A table written as <Row><Cell>..</Cell></Row> with a header row.
        if (rows.Count == 0)
        {
            var cellRows = document.Descendants().Where(e => e.HasElements && e.Elements().All(c => !c.HasElements))
                .Select(e => e.Elements().Select(c => c.Value.Trim()).ToList());
            return Table(cellRows);
        }
        return rows;
    }
}
