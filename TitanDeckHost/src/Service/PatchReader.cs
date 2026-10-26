using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// The show's patch, from the newest patch report Titan wrote (Disk &gt;
/// Reports, Fixtures, saved to this PC: Documents\Titan\Reports), matched to
/// Titan's personalities for where each fixture's intensity is. Only reads
/// files: nothing here touches Titan's Patch menu. A report picked in the Host window counts
/// until a newer one turns up in the folder.
/// </summary>
public sealed class PatchReader(TitanLog log, HostModeStore mode, ILogger<PatchReader> logger)
{
    private static readonly string[] ReportTypes = ["*.csv", "*.xml", "*.htm", "*.html"];
    private static readonly TimeSpan Rescan = TimeSpan.FromSeconds(15);
    private static readonly HttpClient Titan = new() { Timeout = TimeSpan.FromSeconds(10) };

    private readonly object gate = new();
    private readonly PersonalityLibrary library = new(PersonalityFolders());
    private (string Source, DateTimeOffset Written, IReadOnlyList<PatchFixture> Fixtures)? fromFile, imported;
    private (string Path, DateTime Written)? lastFile;
    private DateTimeOffset lastScan = DateTimeOffset.MinValue;
    private DateTimeOffset? read;
    private string? problem;

    /// <summary>Index the personalities and read the newest report in the background, so the first ask is quick.</summary>
    public void Warm() => Task.Run(() =>
    {
        try { Status(); } catch (Exception error) { logger.LogWarning(error, "Warming the patch reader failed"); }
    });

    public PatchDto Status()
    {
        lock (gate)
        {
            if (DateTimeOffset.UtcNow - lastScan > Rescan) ScanLocked();
            return DtoLocked();
        }
    }

    /// <summary>The current patch with each fixture's attributes, for naming changes in the Slate Book.</summary>
    public IReadOnlyList<PatchFixture> Fixtures()
    {
        lock (gate)
        {
            if (DateTimeOffset.UtcNow - lastScan > Rescan) ScanLocked();
            return CurrentLocked()?.Fixtures ?? [];
        }
    }

    public PatchDto Reload()
    {
        lock (gate)
        {
            library.Forget();
            lastFile = null;
            ScanLocked();
            return DtoLocked();
        }
    }

    /// <summary>A report picked in the Host window (or one that isn't in the Reports folder).</summary>
    public PatchDto Import(PatchImportRequest request)
    {
        lock (gate)
        {
            var fixtures = TitanPatch.Parse(request.Text ?? "", request.Name ?? "");
            if (fixtures.Count == 0)
            {
                problem = $"{request.Name} has no patch in it (no rows with a user number and an address).";
            }
            else
            {
                imported = (request.Name ?? "report", DateTimeOffset.Now, library.Fill(fixtures));
                read = DateTimeOffset.Now;
                problem = null;
                Logged("IMPORT", request.Name ?? "", imported.Value.Fixtures);
            }
            return DtoLocked();
        }
    }

    /// <summary>
    /// Experimental: asks Titan's WebAPI (the separate API user, never the
    /// desk's own UI) to write a report, then reads it. Titan's parameters for
    /// this aren't documented, so what Titan answers goes in the Titan log.
    /// </summary>
    public async Task<PatchDto> AskTitan()
    {
        const string path = "/titan/script/2/Reports/GenerateReport";
        const string query = "format=CSV&reportSections=Fixtures";
        if (mode.IsShow)
        {
            lock (gate)
            {
                problem = "Asking Titan for a report is a test feature: it's off in Show mode. Use Disk > Reports on Titan.";
                return DtoLocked();
            }
        }
        var started = DateTimeOffset.Now;
        int status;
        string note;
        try
        {
            using var response = await Titan.GetAsync($"http://127.0.0.1:{TitanUiConfig.ApiPort}{path}?{query}");
            status = (int)response.StatusCode;
            var body = await response.Content.ReadAsStringAsync();
            note = body.Length == 0 ? "answered with nothing" : $"answered {(body.Length > 160 ? body[..160] + "..." : body)}";
        }
        catch (Exception error)
        {
            status = 502;
            note = "Titan didn't answer: " + error.Message;
        }
        log.Add("Patch report - Titan WebAPI", "Host window", "GET", path, query, status,
            (int)(DateTimeOffset.Now - started).TotalMilliseconds, note, null, status is < 200 or >= 300, DateTimeOffset.Now);
        await Task.Delay(TimeSpan.FromSeconds(3));   // Titan writes the file
        return Reload();
    }

    private void ScanLocked()
    {
        lastScan = DateTimeOffset.UtcNow;
        try
        {
            var newest = ReportFolders().Where(Directory.Exists)
                .SelectMany(folder => ReportTypes.SelectMany(type => SafeFiles(folder, type)))
                .Select(path => new FileInfo(path))
                .Where(file => file.Length is > 0 and <= TitanPatch.MaxReportBytes)
                .OrderByDescending(file => file.LastWriteTimeUtc)
                .Take(8)
                .ToList();
            if (newest.Count == 0)
            {
                if (fromFile is null) problem = null;
                return;
            }
            if (lastFile is { } last && last.Path == newest[0].FullName && last.Written == newest[0].LastWriteTimeUtc) return;
            lastFile = (newest[0].FullName, newest[0].LastWriteTimeUtc);
            // The newest report with a patch in it (a report of palettes alone has none).
            foreach (var file in newest)
            {
                var fixtures = TitanPatch.Parse(File.ReadAllText(file.FullName), file.Name);
                if (fixtures.Count == 0) continue;
                fromFile = (file.Name, new DateTimeOffset(file.LastWriteTimeUtc), library.Fill(fixtures));
                read = DateTimeOffset.Now;
                problem = null;
                Logged("READ", file.FullName, fromFile.Value.Fixtures);
                return;
            }
            if (fromFile is null) problem = $"Found reports in {newest[0].DirectoryName}, but none with the patch in (tick Fixtures).";
        }
        catch (Exception error)
        {
            problem = "Couldn't read the patch report: " + error.Message;
            logger.LogWarning(error, "Reading the patch report failed");
        }
    }

    private void Logged(string method, string source, IReadOnlyList<PatchFixture> fixtures)
    {
        var withLevel = fixtures.Count(f => f.Intensity is not null);
        log.Add("Patch report", "Host", method, source, "", 200, 0,
            $"{fixtures.Count} fixture{(fixtures.Count == 1 ? "" : "s")}, intensity channel known for {withLevel} " +
            $"({library.Count} personalities on this PC)", null, false, DateTimeOffset.Now);
    }

    /// <summary>The newer of the folder's report and one picked by hand.</summary>
    private (string Source, DateTimeOffset Written, IReadOnlyList<PatchFixture> Fixtures)? CurrentLocked() =>
        imported is { } i && (fromFile is not { } f || i.Written >= f.Written) ? imported : fromFile;

    private PatchDto DtoLocked()
    {
        var current = CurrentLocked();
        var fixtures = current?.Fixtures.Select(f =>
            new PatchFixtureDto(f.UserNumber, f.Model, f.Mode, f.Line, f.Address, f.Channels, f.Intensity, f.Legend)).ToList() ?? [];
        var problemText = problem ?? (current is null
            ? "No patch report yet. On Titan: Disk > Reports, tick Fixtures, choose CSV, save to this PC."
            : null);
        return new PatchDto(current?.Source, current?.Written, read, fixtures, library.Count, problemText,
            ReportFolders().Where(Directory.Exists).Concat(library.Folders).ToList());
    }

    private static IEnumerable<string> SafeFiles(string folder, string pattern)
    {
        try
        {
            return Directory.EnumerateFiles(folder, pattern, new EnumerationOptions { RecurseSubdirectories = true, MaxRecursionDepth = 2, IgnoreInaccessible = true }).ToList();
        }
        catch (Exception)
        {
            return [];
        }
    }

    /// <summary>Every user's Documents (the service runs as LocalSystem, so not "my" Documents).</summary>
    private static IEnumerable<string> UserDocuments()
    {
        var users = Path.Combine(Path.GetPathRoot(Environment.SystemDirectory) is { Length: > 0 } root ? root : "C:\\", "Users");
        if (!Directory.Exists(users)) yield break;
        string[] profiles;
        try
        {
            profiles = Directory.GetDirectories(users);
        }
        catch (Exception)
        {
            yield break;
        }
        foreach (var profile in profiles)
        {
            yield return Path.Combine(profile, "Documents");
            yield return Path.Combine(profile, "OneDrive", "Documents");
        }
    }

    public static IEnumerable<string> ReportFolders() =>
        UserDocuments().Concat(Special(Environment.SpecialFolder.CommonDocuments))
            .Select(d => Path.Combine(d, "Titan", "Reports"))
            .Append(@"D:\Reports");

    /// <summary>A special folder, or nothing where the system has none (Linux test runs).</summary>
    private static IEnumerable<string> Special(Environment.SpecialFolder folder) =>
        Environment.GetFolderPath(folder) is { Length: > 0 } path ? [path] : [];

    /// <summary>The user's own personalities first, then the factory library.</summary>
    private static IEnumerable<string> PersonalityFolders()
    {
        foreach (var documents in UserDocuments()) yield return Path.Combine(documents, "Titan", "Personalities");
        yield return @"D:\Personalities";
        foreach (var programs in Special(Environment.SpecialFolder.ProgramFiles).Concat(Special(Environment.SpecialFolder.ProgramFilesX86)).Distinct())
        {
            var avolites = Path.Combine(programs, "Avolites");
            string[] titans;
            try
            {
                titans = Directory.Exists(avolites) ? Directory.GetDirectories(avolites) : [];
            }
            catch (Exception)
            {
                titans = [];
            }
            foreach (var titan in titans) yield return Path.Combine(titan, "FixtureLibrary");
        }
        yield return @"D:\TitanData\FixtureLibrary";
    }
}
