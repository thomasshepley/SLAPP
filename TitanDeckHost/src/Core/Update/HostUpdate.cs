using System.Security.Cryptography;
using System.Text.Json;

namespace TitanDeckHost.Core.Update;

/// <summary>A TitanDeck Host installer published on GitHub.</summary>
public sealed record HostRelease(Version Version, string Tag, string AssetName, string Url, long Size, string? Sha256,
    string Notes, DateTimeOffset? Published);

/// <summary>
/// Finding and checking Host updates. CI publishes every Host version as a
/// GitHub release "host-vX.Y.Z" (marked pre-release) with the Setup .exe; the
/// Host compares the newest against its own version, and only ever downloads
/// from this repository's release downloads, checked against the SHA-256
/// GitHub lists for the file.
/// </summary>
public static class HostUpdate
{
    public const string Repository = "thomasshepley/SLAPP";
    public const string ReleasesUrl = $"https://api.github.com/repos/{Repository}/releases?per_page=30";
    private const string DownloadPrefix = $"https://github.com/{Repository}/releases/download/host-v";

    /// <summary>The newest Host release in GitHub's releases JSON, or null.</summary>
    public static HostRelease? Newest(string releasesJson)
    {
        using var document = JsonDocument.Parse(releasesJson);
        if (document.RootElement.ValueKind != JsonValueKind.Array) return null;
        HostRelease? best = null;
        foreach (var release in document.RootElement.EnumerateArray())
        {
            if (release.TryGetProperty("draft", out var draft) && draft.GetBoolean()) continue;
            var tag = release.TryGetProperty("tag_name", out var t) ? t.GetString() ?? "" : "";
            if (!tag.StartsWith("host-v", StringComparison.Ordinal) || !Version.TryParse(tag[6..], out var version)) continue;
            if (!release.TryGetProperty("assets", out var assets)) continue;
            foreach (var asset in assets.EnumerateArray())
            {
                var name = asset.GetProperty("name").GetString() ?? "";
                var url = asset.TryGetProperty("browser_download_url", out var u) ? u.GetString() ?? "" : "";
                if (!name.StartsWith("TitanDeckHost-Setup-", StringComparison.OrdinalIgnoreCase)
                    || !name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) || !IsOfficial(url)) continue;
                var digest = asset.TryGetProperty("digest", out var d) ? d.GetString() : null;
                var sha = digest is { } dg && dg.StartsWith("sha256:", StringComparison.Ordinal) ? dg[7..].ToLowerInvariant() : null;
                var published = release.TryGetProperty("published_at", out var p) && p.ValueKind == JsonValueKind.String
                    ? p.GetDateTimeOffset() : (DateTimeOffset?)null;
                var candidate = new HostRelease(version, tag, name, url, asset.GetProperty("size").GetInt64(), sha,
                    ShortNotes(release.TryGetProperty("body", out var b) ? b.GetString() ?? "" : ""), published);
                if (best is null || candidate.Version > best.Version) best = candidate;
                break;
            }
        }
        return best;
    }

    /// <summary>Is `release` newer than the running Host ("0.4.0")?</summary>
    public static bool IsNewer(HostRelease release, string current) =>
        !Version.TryParse(current.Split('+', '-')[0], out var mine) || release.Version > mine;

    /// <summary>Only this repository's Host release downloads, over HTTPS.</summary>
    public static bool IsOfficial(string url) => url.StartsWith(DownloadPrefix, StringComparison.Ordinal);

    /// <summary>Does the file match GitHub's SHA-256 for it?</summary>
    public static bool Matches(Stream file, string sha256)
    {
        var hash = Convert.ToHexString(SHA256.HashData(file)).ToLowerInvariant();
        return hash == sha256.ToLowerInvariant();
    }

    /// <summary>The release notes' first section, without the install instructions.</summary>
    public static string ShortNotes(string body)
    {
        var lines = body.Replace("\r", "").Split('\n')
            .Where(l => !l.StartsWith("**Install:**", StringComparison.Ordinal))
            .SkipWhile(string.IsNullOrWhiteSpace)
            .ToList();
        var text = string.Join("\n", lines).Trim();
        return text.Length <= 900 ? text : text[..900].TrimEnd() + "...";
    }
}
