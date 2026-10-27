using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace TitanDeckHost.Core.Titan;

/// <summary>One mode of a personality: its name, channel count, where its
/// level is and every attribute with a channel (0-based from the fixture's start).</summary>
public sealed record PersonalityMode(string Name, int? Channels, IReadOnlyList<int>? Intensity,
                                     IReadOnlyList<PersonalityAttribute>? Attributes = null);

/// <summary>An attribute and its channels: one, or coarse then fine (0-based).</summary>
public sealed record PersonalityAttribute(string Name, IReadOnlyList<int> Offsets);

/// <summary>
/// A Titan fixture personality (.d4): plain XML, one fixture per file, as
/// <c>&lt;Fixture Name ShortName Company&gt;</c> with a <c>&lt;Mode Name Channels&gt;</c>
/// per DMX mode. Each mode lists its attributes with a 1-based
/// <c>ChannelOffset</c>, "12,13" being coarse then fine. Checked against real
/// files from the Avolites library.
/// </summary>
public sealed record TitanPersonality(string Name, string? ShortName, string? Company, IReadOnlyList<PersonalityMode> Modes)
{
    private static readonly string[] Colours = ["Red", "Green", "Blue", "White", "Amber", "Lime", "UV", "Cyan", "Magenta", "Yellow"];

    /// <summary>The personality in a .d4 file, or null if it isn't one.</summary>
    public static TitanPersonality? Read(string xml)
    {
        XElement root;
        try
        {
            root = XDocument.Parse(xml.TrimStart('﻿')).Root!;
        }
        catch (Exception)
        {
            return null;
        }
        if (root.Name.LocalName != "Fixture" || (string?)root.Attribute("Name") is not { Length: > 0 } name) return null;
        var modes = root.Elements("Mode").Select(mode => new PersonalityMode(
            ((string?)mode.Attribute("Name") ?? "").Trim(),
            int.TryParse((string?)mode.Attribute("Channels"), out var n) ? n : null,
            IntensityOf(mode),
            AttributesOf(mode))).ToList();
        return new TitanPersonality(name, (string?)root.Attribute("ShortName"), (string?)root.Attribute("Company"), modes);
    }

    /// <summary>
    /// Where a mode's level is: its Dimmer channel(s); in a multi-cell mode
    /// with a virtual Dimmer, the Master_Dimmer; with no dimmer channel at all
    /// (an RGB fixture), its colour channels.
    /// </summary>
    private static IReadOnlyList<int>? IntensityOf(XElement mode)
    {
        // Cells hold the per-cell attributes; the fixture's own are under Include (or Cells/Master).
        var own = mode.Descendants("Attribute")
            .Where(a => a.Ancestors("Cell").FirstOrDefault() is null || a.Ancestors().Any(e => e.Name.LocalName == "Master"))
            .ToList();
        foreach (var id in new[] { "Dimmer", "Master_Dimmer" })
            if (own.FirstOrDefault(a => (string?)a.Attribute("ID") == id && Offsets(a) is not null) is { } dimmer)
                return Offsets(dimmer);
        var colours = own.Where(a => Colours.Contains((string?)a.Attribute("ID")) && Offsets(a) is not null)
            .Select(a => Offsets(a)![0]).Distinct().Order().ToList();
        return colours.Count > 0 ? colours : null;
    }

    /// <summary>
    /// Every attribute in a mode with a channel, in channel order. A cell's
    /// attributes are named with their cell ("Red 2"); an attribute already on
    /// a channel isn't listed twice.
    /// </summary>
    private static IReadOnlyList<PersonalityAttribute> AttributesOf(XElement mode)
    {
        var cells = mode.Descendants("Cell").ToList();
        var seen = new HashSet<int>();
        var result = new List<PersonalityAttribute>();
        foreach (var attribute in mode.Descendants("Attribute"))
        {
            if (Offsets(attribute) is not { } offsets || !seen.Add(offsets[0])) continue;
            var id = ((string?)attribute.Attribute("ID") ?? "").Replace('_', ' ').Trim();
            if (id.Length == 0) id = $"Channel {offsets[0] + 1}";
            var cell = attribute.Ancestors("Cell").FirstOrDefault();
            if (cell is not null && !attribute.Ancestors().Any(e => e.Name.LocalName == "Master"))
                id += $" {cells.IndexOf(cell) + 1}";
            result.Add(new PersonalityAttribute(id, offsets));
        }
        return result.OrderBy(a => a.Offsets[0]).ToList();
    }

    /// <summary>"12,13" to [11, 12]; nil when there's no channel (a virtual attribute).</summary>
    private static List<int>? Offsets(XElement attribute)
    {
        var text = (string?)attribute.Attribute("ChannelOffset");
        if (string.IsNullOrWhiteSpace(text)) return null;
        var offsets = text.Split(',').Select(t => int.TryParse(t.Trim(), out var n) ? n - 1 : -1).ToList();
        return offsets.Count > 0 && offsets.All(o => o is >= 0 and < 512) ? offsets : null;
    }

    /// <summary>
    /// Does this personality fit the fixture name in a patch report? Titan
    /// may show the full name, the short name, or either after the maker.
    /// </summary>
    public bool Matches(string? model)
    {
        if (Key(model) is not { Length: > 0 } wanted) return false;
        var company = Key(Company);
        return new[] { Name, ShortName }.Select(Key).Where(k => k.Length > 0)
            .Any(k => k == wanted || company + k == wanted || (company.Length > 0 && wanted == k + company));
    }

    /// <summary>
    /// The mode a report means: "Mode 1, 35 DMX" is mode "Mode 1" with 35
    /// channels. By name first, then the only mode with that channel count.
    /// </summary>
    public PersonalityMode? Mode(string? reportMode, int? channels)
    {
        if (!string.IsNullOrWhiteSpace(reportMode))
        {
            var name = Key(Regex.Replace(reportMode, @"[,\s]*\(?\d{1,3}\s*(?:DMX|ch\b|chan|channels?)\)?\s*$", "", RegexOptions.IgnoreCase));
            var full = Key(reportMode);
            var byName = Modes.Where(m => Key(m.Name) is var k && k.Length > 0 && (k == name || k == full)).ToList();
            if (byName.Count == 1 || (byName.Count > 1 && channels is null)) return byName[0];
            if (byName.Count > 1) return byName.FirstOrDefault(m => m.Channels == channels) ?? byName[0];
        }
        if (channels is null) return Modes.Count == 1 ? Modes[0] : null;
        var byCount = Modes.Where(m => m.Channels == channels).ToList();
        return byCount.Count == 1 ? byCount[0] : null;
    }

    public static string Key(string? text) => new((text ?? "").ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());
}
