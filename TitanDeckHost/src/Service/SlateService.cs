using System.Text.Json;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Sacn;
using TitanDeckHost.Core.Slate;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// The Slate Book: the look on stage, logged per slate and take from the
/// sACN Titan sends (read only: nothing here talks to Titan). TAKE and NEW
/// SLATE come from the deck; in between, a change is logged once the output
/// has been still for a few seconds, ignoring channels that keep moving (an
/// effect). One file per shooting day in Data\SlateBook, plus the slate
/// showing in state.json so it carries on after a restart or into the next day.
/// </summary>
public sealed class SlateService(HostPaths paths, DmxUniverses store, SacnListener listener, PatchReader patch,
                                 ILogger<SlateService> log) : BackgroundService
{
    private static readonly TimeSpan SampleEvery = TimeSpan.FromMilliseconds(500);
    private static readonly TimeSpan Settle = TimeSpan.FromSeconds(3);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = false };

    private readonly object gate = new();
    private readonly LookWatcher watcher = new(Settle);
    private SlateBook? book;
    private string Folder => Path.Combine(paths.Data, "SlateBook");
    private string StateFile => Path.Combine(Folder, "state.json");

    /// <param name="entries">False for just the slate showing (the deck polls this).</param>
    public SlateBookDto Status(bool entries = true)
    {
        lock (gate)
        {
            var today = Today();
            var look = Look(out var problem);
            return new SlateBookDto(today.Day, Dto(today.State), entries ? today.Entries.Select(Dto).ToList() : [], Days(),
                look.Count > 0, Patch().Count, problem);
        }
    }

    /// <summary>A past day's book, or null if there isn't one.</summary>
    public SlateBookDto? Day(string day)
    {
        lock (gate)
        {
            var other = day == Today().Day ? Today() : Load(day);
            if (other is null) return null;
            return new SlateBookDto(other.Day, Dto(other.State), other.Entries.Select(Dto).ToList(), Days(), true, Patch().Count, null);
        }
    }

    public IResult Take() => Logging(today => today.Take(Look(out _), Patch(), DateTimeOffset.Now, watcher.Moving.ToHashSet()));

    public IResult NewSlate(string? slate) =>
        Logging(today => today.NewSlate(slate, Look(out _), Patch(), DateTimeOffset.Now, watcher.Moving.ToHashSet()));

    public IResult Letter() => Logging(today => today.Letter(Look(out _), Patch(), DateTimeOffset.Now, watcher.Moving.ToHashSet()));

    public SlateBookDto Set(SlateSetRequest request)
    {
        lock (gate)
        {
            Today().Set(request.Night, request.Fx, request.Slate, request.Take);
            Save(Today());
        }
        return Status();
    }

    public IResult Note(SlateNoteRequest request)
    {
        lock (gate)
        {
            var target = request.Day == Today().Day ? Today() : Load(request.Day);
            if (target is null || !target.Note(request.Id, request.Note)) return Results.NotFound(new { error = "No such line in the Slate Book." });
            Save(target);
            return Results.Ok(Dto(target.Entries.First(e => e.Id == request.Id)));
        }
    }

    /// <summary>What's different on stage now from a line of the book.</summary>
    public IResult Match(string day, long id)
    {
        lock (gate)
        {
            var target = day == Today().Day ? Today() : Load(day);
            var entry = target?.Entries.FirstOrDefault(e => e.Id == id);
            if (entry is null) return Results.NotFound(new { error = "No such line in the Slate Book." });
            var now = Look(out _);
            var differences = now.Count == 0 ? []
                : LookDiff.Compare(SlateBook.Decode(entry.Levels), now, Patch(), watcher.Moving.ToHashSet());
            return Results.Ok(new SlateMatchDto(Dto(entry), differences.Select(Dto).ToList(), now.Count > 0));
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stopping)
    {
        while (!stopping.IsCancellationRequested)
        {
            try
            {
                lock (gate)
                {
                    var look = Look(out _);
                    if (look.Count > 0 && watcher.Sample(look, DateTimeOffset.Now))
                    {
                        var today = Today();
                        // Nothing is logged until the day's first TAKE or NEW SLATE.
                        if (today.Entries.Count > 0 && today.Change(look, Patch(), DateTimeOffset.Now, watcher.Moving.ToHashSet()) is not null)
                            Save(today);
                        watcher.Accept(look);
                    }
                }
            }
            catch (Exception error)
            {
                log.LogWarning(error, "Slate Book sampling failed");
            }
            try { await Task.Delay(SampleEvery, stopping); }
            catch (OperationCanceledException) { return; }
        }
    }

    private IResult Logging(Func<SlateBook, SlateEntry> action)
    {
        lock (gate)
        {
            var look = Look(out var problem);
            if (look.Count == 0)
                return Results.Json(new { error = "No sACN from Titan, so there's no look to log. " + (problem ?? "Is Titan sending sACN to this PC?") },
                                    statusCode: StatusCodes.Status409Conflict);
            var today = Today();
            var entry = action(today);
            watcher.Accept(look);
            Save(today);
            return Results.Ok(Dto(entry));
        }
    }

    /// <summary>Every universe live now (the patch's lines are asked for too).</summary>
    private Dictionary<int, byte[]> Look(out string? problem)
    {
        foreach (var line in Patch().Select(f => f.Line).Distinct()) listener.Want(line);
        var now = DateTimeOffset.UtcNow;
        var look = new Dictionary<int, byte[]>();
        foreach (var universe in store.Known(now))
            if (store.Get(universe, now) is { } levels) look[universe] = levels.Levels;
        problem = listener.Problem;
        return look;
    }

    private IReadOnlyList<PatchFixture> Patch() => patch.Fixtures();

    /// <summary>Today's book: loaded from disk the first time, a new one after midnight.</summary>
    private SlateBook Today()
    {
        var day = DateTime.Now.ToString("yyyy-MM-dd");
        if (book?.Day == day) return book;
        var state = book?.State ?? LoadState() ?? SlateState.Start;
        book = Load(day) ?? new SlateBook(day, state);
        return book;
    }

    private IReadOnlyList<string> Days()
    {
        try
        {
            if (!Directory.Exists(Folder)) return [];
            return Directory.EnumerateFiles(Folder, "????-??-??.json").Select(Path.GetFileNameWithoutExtension)
                .OfType<string>().OrderDescending().ToList();
        }
        catch (Exception)
        {
            return [];
        }
    }

    private sealed record DayFile(SlateState State, List<SlateEntry> Entries);

    private SlateBook? Load(string day)
    {
        if (!System.Text.RegularExpressions.Regex.IsMatch(day, @"^\d{4}-\d{2}-\d{2}$")) return null;
        var file = Path.Combine(Folder, day + ".json");
        try
        {
            if (!File.Exists(file)) return null;
            var saved = JsonSerializer.Deserialize<DayFile>(File.ReadAllText(file), Json);
            return saved is null ? null : new SlateBook(day, saved.State, saved.Entries);
        }
        catch (Exception error)
        {
            log.LogWarning(error, "Couldn't read the Slate Book for {Day}", day);
            return null;
        }
    }

    private SlateState? LoadState()
    {
        try
        {
            return File.Exists(StateFile) ? JsonSerializer.Deserialize<SlateState>(File.ReadAllText(StateFile), Json) : null;
        }
        catch (Exception)
        {
            return null;
        }
    }

    private void Save(SlateBook day)
    {
        try
        {
            Directory.CreateDirectory(Folder);
            Write(Path.Combine(Folder, day.Day + ".json"), JsonSerializer.Serialize(new DayFile(day.State, day.Entries), Json));
            if (day == book) Write(StateFile, JsonSerializer.Serialize(day.State, Json));
        }
        catch (Exception error)
        {
            log.LogWarning(error, "Couldn't save the Slate Book");
        }
    }

    /// <summary>Written beside, then swapped in: a crash mid-write never loses the day.</summary>
    private static void Write(string file, string text)
    {
        var temp = file + ".tmp";
        File.WriteAllText(temp, text);
        File.Move(temp, file, overwrite: true);
    }

    private static SlateStateDto Dto(SlateState state) => new(state.Slate, state.Take, state.Night, state.Fx);

    private static SlateEntryDto Dto(SlateEntry entry) =>
        new(entry.Id, entry.Time, entry.Kind, entry.Slate, entry.Take, entry.Night, entry.Fx, entry.Changes.Select(Dto).ToList(), entry.Note);

    private static LookChangeDto Dto(LookChange change) => new(change.Fixture, change.What, change.Before, change.After);
}
