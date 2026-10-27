using System.Text.RegularExpressions;

namespace TitanDeckHost.Core.Slate;

/// <summary>
/// UK-style slate numbers: one slate per setup, counting up ("112", "113"),
/// with a letter for a pickup or variation of the same setup ("112A",
/// "112B"). Letters skip I and O, as clapper loaders do (they read as 1 and 0).
/// </summary>
public static class SlateNumbers
{
    private const string Letters = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    private static readonly Regex Parts = new(@"^(?<prefix>.*?)(?<number>\d+)(?<letters>[A-Za-z]*)$");

    /// <summary>The next setup: "112" or "112B" to "113". No number in it: "1".</summary>
    public static string Next(string slate)
    {
        var match = Parts.Match(slate.Trim());
        if (!match.Success) return "1";
        var number = long.Parse(match.Groups["number"].Value) + 1;
        return match.Groups["prefix"].Value + number;
    }

    /// <summary>The next letter of the same setup: "112" to "112A", "112H" to "112J", "112Z" to "112AA".</summary>
    public static string NextLetter(string slate)
    {
        var text = slate.Trim();
        var match = Parts.Match(text);
        if (!match.Success) return text.Length == 0 ? "1A" : text + "A";
        var letters = match.Groups["letters"].Value.ToUpperInvariant();
        var stem = text[..^letters.Length];
        if (letters.Length == 0) return stem + "A";
        var last = Letters.IndexOf(letters[^1]);
        if (last < 0 || last == Letters.Length - 1) return stem + letters + "A";
        return stem + letters[..^1] + Letters[last + 1];
    }

    /// <summary>A slate typed by hand, tidied: trimmed, letters in capitals, at most 12 characters.</summary>
    public static string? Clean(string? slate)
    {
        var text = (slate ?? "").Trim().ToUpperInvariant();
        if (text.Length == 0) return null;
        return text.Length > 12 ? text[..12] : text;
    }
}
