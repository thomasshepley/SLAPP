using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Prism;

namespace TitanDeckHost.Service;

/// <summary>
/// Finds which clips Prism has in which bank, for TitanDeck's FX tab (Host
/// 0.18). Prism's files aren't documented, so it looks through Avolites'
/// Prism folders (every user's Documents\Avolites\Prism, AppData and
/// ProgramData) for JSON or XML that lists media in banks, and uses the
/// newest (exported banks in Playlists only if there's nothing else). A
/// folder or file from TitanDeck's Prism Setup is read instead: Prism's
/// project file, or a folder of media whose subfolders are the banks. Only
/// reads; every file it weighed is in the steps.
/// </summary>
public sealed class PrismMediaFinder
{
    private const long LargestProject = 20 * 1024 * 1024;
    private const int MostFilesLooked = 3000;
    private const int MostFilesRead = 300;

    public PrismMediaDto Read(string? folder)
    {
        var steps = new List<string>();
        if (!string.IsNullOrWhiteSpace(folder))
        {
            var path = Environment.ExpandEnvironmentVariables(folder.Trim().Trim('"'));
            if (File.Exists(path))
            {
                var banks = ParseFile(path, steps);
                return banks is { Count: > 0 }
                    ? Result(path, banks, steps)
                    : Fail(path, $"{path} doesn't list any Prism banks the Host can read.", steps);
            }
            if (!Directory.Exists(path)) return Fail(path, $"There's no {path} on the PC.", steps);
            return FromProjects([path], steps) ?? FromMediaFolder(path, steps)
                   ?? Fail(path, $"{path} has no Prism project or media the Host can read.", steps);
        }

        var roots = Roots().Where(Directory.Exists).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        if (roots.Count == 0)
            return Fail("", "The Host found no Avolites Prism folders on this PC. Put the folder Prism keeps its project in (or a folder of your Prism media) in TitanDeck's FX tab > Prism Setup.", steps);
        steps.Add("Looked in " + string.Join("; ", roots));
        return FromProjects(roots, steps)
               ?? Fail("", "The Host found Prism's folders but no project it can read. Put the folder Prism keeps its project in (or a folder of your Prism media) in TitanDeck's FX tab > Prism Setup, and send the steps below to whoever looks after TitanDeck.", steps);
    }

    /// <summary>Where Prism might keep its project and banks.</summary>
    private static IEnumerable<string> Roots()
    {
        foreach (var documents in PatchReader.UserDocuments())
        {
            yield return Path.Combine(documents, "Avolites", "Prism");
            yield return Path.Combine(documents, "Prism");
        }
        foreach (var profile in PatchReader.UserProfiles())
        {
            yield return Path.Combine(profile, "AppData", "Roaming", "Avolites", "Prism");
            yield return Path.Combine(profile, "AppData", "Local", "Avolites", "Prism");
        }
        foreach (var special in new[] { Environment.SpecialFolder.CommonApplicationData, Environment.SpecialFolder.CommonDocuments })
            if (Environment.GetFolderPath(special) is { Length: > 0 } path)
                yield return Path.Combine(path, "Avolites", "Prism");
    }

    private sealed record Found(string Path, DateTime Modified, IReadOnlyList<PrismBank> Banks, bool Exported);

    /// <summary>The newest project-like file under the roots that lists banks of media.</summary>
    private static PrismMediaDto? FromProjects(IReadOnlyList<string> roots, List<string> steps)
    {
        var found = new List<Found>();
        var looked = 0;
        var read = 0;
        foreach (var root in roots)
        {
            foreach (var file in Files(root))
            {
                if (++looked > MostFilesLooked || read >= MostFilesRead) break;
                if (PrismLibrary.IsMedia(file)) continue;
                FileInfo info;
                try { info = new FileInfo(file); }
                catch (Exception) { continue; }
                if (info.Length is 0 or > LargestProject || !LooksLikeText(file)) continue;
                read++;
                var banks = ParseFile(file, null);
                if (banks is { Count: > 0 })
                    found.Add(new Found(file, info.LastWriteTimeUtc, banks,
                        file.Contains(Path.DirectorySeparatorChar + "Playlists" + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)));
            }
        }
        steps.Add($"Read {read} JSON / XML files of {looked} looked at; {found.Count} list media in banks");
        foreach (var f in found.OrderByDescending(f => f.Modified).Take(10))
            steps.Add($"{f.Path}: {f.Banks.Count} banks, {f.Banks.Sum(b => b.Clips.Count)} clips, saved {f.Modified.ToLocalTime():yyyy-MM-dd HH:mm}{(f.Exported ? " (an exported bank)" : "")}");
        var best = found.Where(f => !f.Exported).OrderByDescending(f => f.Modified).FirstOrDefault()
                   ?? found.OrderByDescending(f => f.Modified).FirstOrDefault();
        return best is null ? null : Result(best.Path, best.Banks, steps, best.Modified);
    }

    /// <summary>A folder of media: each subfolder a bank.</summary>
    private static PrismMediaDto? FromMediaFolder(string folder, List<string> steps)
    {
        var files = Files(folder, depth: 2).Take(MostFilesLooked).Where(f => PrismLibrary.IsMedia(f)).Select(f => Path.GetRelativePath(folder, f)).ToList();
        steps.Add($"{folder} has {files.Count} media files");
        if (files.Count == 0) return null;
        var banks = PrismLibrary.FromFolder(files)
            .Select(b => b with { Clips = b.Clips.Select(c => c with { Path = Path.Combine(folder, c.Path!.Replace('/', Path.DirectorySeparatorChar)) }).ToList() })
            .ToList();
        return Result(folder, banks, steps);
    }

    private static IReadOnlyList<PrismBank>? ParseFile(string path, List<string>? steps)
    {
        try
        {
            return PrismLibrary.Parse(File.ReadAllText(path));
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            steps?.Add($"Couldn't read {path}: {e.Message}");
            return null;
        }
    }

    private static IEnumerable<string> Files(string root, int depth = 6)
    {
        try
        {
            return Directory.EnumerateFiles(root, "*", new EnumerationOptions
            {
                RecurseSubdirectories = true, MaxRecursionDepth = depth, IgnoreInaccessible = true,
                AttributesToSkip = FileAttributes.System | FileAttributes.Hidden,
            });
        }
        catch (Exception)
        {
            return [];
        }
    }

    /// <summary>True if the file starts (past a BOM and spaces) with {, [ or &lt;.</summary>
    private static bool LooksLikeText(string path)
    {
        try
        {
            using var stream = File.OpenRead(path);
            Span<byte> head = stackalloc byte[64];
            var count = stream.Read(head);
            foreach (var b in head[..count])
            {
                if (b is (byte)' ' or (byte)'\t' or (byte)'\r' or (byte)'\n' or 0xEF or 0xBB or 0xBF) continue;
                return b is (byte)'{' or (byte)'[' or (byte)'<';
            }
            return false;
        }
        catch (Exception)
        {
            return false;
        }
    }

    private static PrismMediaDto Result(string source, IReadOnlyList<PrismBank> banks, List<string> steps, DateTime? modified = null)
    {
        var dtos = banks.Select(b => new PrismBankDto(b.Index, b.Number, b.Name, b.Clips.Select(Clip).ToList())).ToList();
        var clips = dtos.Sum(b => b.Clips.Count);
        var missing = dtos.Sum(b => b.Clips.Count(c => !c.Exists));
        var message = $"{dtos.Count} bank{(dtos.Count == 1 ? "" : "s")}, {clips} clip{(clips == 1 ? "" : "s")}"
                      + (missing > 0 ? $" ({missing} not found on the PC)" : "");
        modified ??= File.Exists(source) ? File.GetLastWriteTimeUtc(source) : null;
        return new PrismMediaDto(true, source, modified is { } m ? new DateTimeOffset(m, TimeSpan.Zero) : null, dtos, message, steps);
    }

    private static PrismClipDto Clip(PrismClip clip)
    {
        long? bytes = null;
        var exists = false;
        try
        {
            if (clip.Path is { } path && Path.IsPathFullyQualified(path) && File.Exists(path))
            {
                exists = true;
                bytes = new FileInfo(path).Length;
            }
        }
        catch (Exception)
        {
            // A path Windows can't read is just "not found".
        }
        return new PrismClipDto(clip.Index, clip.Number, clip.Name, clip.Path, bytes, exists);
    }

    private static PrismMediaDto Fail(string source, string message, List<string> steps) =>
        new(false, source, null, [], message, steps);
}
