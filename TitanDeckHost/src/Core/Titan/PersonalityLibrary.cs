using System.Text.RegularExpressions;

namespace TitanDeckHost.Core.Titan;

/// <summary>
/// Titan's personalities on this PC (the factory FixtureLibrary and the
/// user's own), indexed by fixture name so a patch report's fixtures can be
/// matched to their .d4 file. Only each file's opening tag is read for the
/// index; a file is read in full when a fixture needs it. Folders listed
/// first win (the user's own personalities before the factory ones).
/// </summary>
public sealed class PersonalityLibrary
{
    private sealed record Entry(string Path, string Name, string? ShortName, string? Company);

    private readonly IReadOnlyList<string> _folders;
    private readonly List<TitanPersonality> _extra = [];
    private readonly Dictionary<string, TitanPersonality?> _read = new(StringComparer.OrdinalIgnoreCase);
    private readonly object _lock = new();
    private List<Entry>? _index;

    public PersonalityLibrary(IEnumerable<string> folders) => _folders = folders.ToList();

    /// <summary>How many personality files were found (indexing them if that hasn't happened yet).</summary>
    public int Count
    {
        get { lock (_lock) return Index().Count + _extra.Count; }
    }

    /// <summary>Folders that exist and were searched.</summary>
    public IReadOnlyList<string> Folders => _folders.Where(Directory.Exists).ToList();

    /// <summary>A personality that isn't on disk (a test's), checked before the files.</summary>
    public void Add(TitanPersonality personality)
    {
        lock (_lock) _extra.Insert(0, personality);
    }

    public void Remove(TitanPersonality personality)
    {
        lock (_lock) _extra.Remove(personality);
    }

    /// <summary>Look at the folders again next time (new personalities installed).</summary>
    public void Forget()
    {
        lock (_lock)
        {
            _index = null;
            _read.Clear();
        }
    }

    /// <summary>The patch with each fixture's intensity channels filled in where its personality is found.</summary>
    public IReadOnlyList<PatchFixture> Fill(IReadOnlyList<PatchFixture> patch)
    {
        var found = new Dictionary<string, TitanPersonality?>(StringComparer.OrdinalIgnoreCase);
        return patch.Select(fixture =>
        {
            if (fixture.Intensity is not null || fixture.Model is null) return fixture;
            if (!found.TryGetValue(fixture.Model, out var personality)) found[fixture.Model] = personality = Find(fixture.Model);
            var mode = personality?.Mode(fixture.Mode, fixture.Channels);
            return mode?.Intensity is { } intensity
                ? fixture with { Intensity = intensity, Channels = fixture.Channels ?? mode.Channels }
                : fixture;
        }).ToList();
    }

    public TitanPersonality? Find(string model)
    {
        lock (_lock)
        {
            if (_extra.FirstOrDefault(p => p.Matches(model)) is { } extra) return extra;
            foreach (var entry in Index())
            {
                var stub = new TitanPersonality(entry.Name, entry.ShortName, entry.Company, []);
                if (!stub.Matches(model)) continue;
                if (!_read.TryGetValue(entry.Path, out var personality))
                {
                    personality = ReadFile(entry.Path);
                    _read[entry.Path] = personality;
                }
                if (personality is not null) return personality;
            }
            return null;
        }
    }

    private static TitanPersonality? ReadFile(string path)
    {
        try
        {
            return new FileInfo(path).Length > TitanPatch.MaxReportBytes ? null : TitanPersonality.Read(File.ReadAllText(path));
        }
        catch (Exception)
        {
            return null;
        }
    }

    private List<Entry> Index()
    {
        if (_index is not null) return _index;
        var index = new List<Entry>();
        foreach (var folder in _folders.Where(Directory.Exists))
        {
            IEnumerable<string> files;
            try
            {
                files = Directory.EnumerateFiles(folder, "*.d4", new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true });
                foreach (var file in files)
                    if (Head(file) is { } entry) index.Add(entry);
            }
            catch (Exception)
            {
                // A folder that can't be read is left out; the rest still count.
            }
        }
        return _index = index;
    }

    /// <summary>The Fixture tag's Name, ShortName and Company, from the start of the file.</summary>
    private static Entry? Head(string path)
    {
        try
        {
            using var reader = new StreamReader(path);
            var buffer = new char[4096];
            var text = new string(buffer, 0, reader.ReadBlock(buffer, 0, buffer.Length));
            var tag = Regex.Match(text, @"<Fixture\b[^>]*>", RegexOptions.IgnoreCase);
            if (!tag.Success) return null;
            string? Attribute(string name) =>
                Regex.Match(tag.Value, $@"\b{name}\s*=\s*""([^""]*)""") is { Success: true } m ? System.Net.WebUtility.HtmlDecode(m.Groups[1].Value) : null;
            return Attribute("Name") is { Length: > 0 } name ? new Entry(path, name, Attribute("ShortName"), Attribute("Company")) : null;
        }
        catch (Exception)
        {
            return null;
        }
    }
}
