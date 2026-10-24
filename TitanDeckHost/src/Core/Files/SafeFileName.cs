namespace TitanDeckHost.Core.Files;

/// <summary>
/// File names that arrive from the iPad, made safe for Windows: no folders,
/// no characters Windows refuses, no reserved device names, sensible length.
/// </summary>
public static class SafeFileName
{
    private static readonly HashSet<string> Reserved = new(StringComparer.OrdinalIgnoreCase)
    {
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    };

    private const string Invalid = "<>:\"/\\|?*";
    public const int MaxLength = 180;

    public static string Clean(string? name)
    {
        // Only the last path part counts, whichever slash was used.
        var raw = (name ?? "").Replace('\\', '/');
        raw = raw[(raw.LastIndexOf('/') + 1)..];

        var chars = raw.Select(c => c < 32 || Invalid.Contains(c) ? '_' : c).ToArray();
        var cleaned = new string(chars).Trim().TrimEnd('.', ' ');
        if (cleaned is "" or "." or "..") cleaned = "file";

        var stem = Path.GetFileNameWithoutExtension(cleaned);
        var ext = Path.GetExtension(cleaned);
        if (stem.Length == 0)
        {
            // A dotfile such as ".gitignore" is all "extension".
            stem = ext;
            ext = "";
        }
        if (Reserved.Contains(stem)) stem = "_" + stem;

        if (stem.Length + ext.Length > MaxLength)
        {
            if (ext.Length > 20) ext = ext[..20];
            stem = stem[..Math.Max(1, MaxLength - ext.Length)];
        }
        return stem + ext;
    }

    /// <summary>"Plot.pdf", then "Plot (2).pdf"... until <paramref name="isTaken"/> says no.</summary>
    public static string Unique(string name, Func<string, bool> isTaken)
    {
        if (!isTaken(name)) return name;
        var stem = Path.GetFileNameWithoutExtension(name);
        var ext = Path.GetExtension(name);
        for (var n = 2; ; n++)
        {
            var candidate = $"{stem} ({n}){ext}";
            if (!isTaken(candidate)) return candidate;
        }
    }
}
