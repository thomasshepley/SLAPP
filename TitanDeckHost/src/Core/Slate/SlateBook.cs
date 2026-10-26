using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Core.Slate;

/// <summary>Where the day is: the slate on the clapper, the take, day or night, and an FX shot.</summary>
public sealed record SlateState(string Slate, int Take, bool Night, bool Fx)
{
    public static readonly SlateState Start = new("1", 1, false, false);
}

/// <summary>
/// One line of the Slate Book: a new slate, a new take, or a change that
/// settled during one. It keeps the whole look (every universe, base64) so it
/// can be matched against later, and what changed since the line before.
/// </summary>
public sealed record SlateEntry(long Id, DateTimeOffset Time, string Kind, string Slate, int Take, bool Night, bool Fx,
                                IReadOnlyList<LookChange> Changes, Dictionary<int, string> Levels, string? Note = null)
{
    public const string NewSlate = "slate";
    public const string NewTake = "take";
    public const string Change = "change";
}

/// <summary>
/// A shooting day's Slate Book. Pressing TAKE moves the take on and logs the
/// look; NEW SLATE (or a letter, "112A") moves the slate on, back to take 1,
/// and logs the look; changes in between are logged by the Host when the
/// output settles. Every line says what changed since the one before, in
/// fixtures and attributes. Not thread-safe: the service locks around it.
/// </summary>
public sealed class SlateBook(string day, SlateState state, List<SlateEntry>? entries = null)
{
    /// <summary>A day this busy is almost certainly an effect nobody meant to log; stop adding changes.</summary>
    public const int MaxEntries = 3000;

    public string Day { get; } = day;
    public SlateState State { get; private set; } = state;
    public List<SlateEntry> Entries { get; } = entries ?? [];

    /// <summary>The look of the newest line, or null before the day's first.</summary>
    public IReadOnlyDictionary<int, byte[]>? LastLook => Entries.Count == 0 ? null : Decode(Entries[^1].Levels);

    public SlateEntry Take(IReadOnlyDictionary<int, byte[]> look, IReadOnlyList<PatchFixture> patch, DateTimeOffset now,
                           ISet<(int, int)>? ignore = null)
    {
        // The first line of the day is take 1 of the slate showing, not take 2.
        if (Entries.Count > 0) State = State with { Take = State.Take + 1 };
        return Log(SlateEntry.NewTake, look, patch, now, ignore);
    }

    /// <summary>The next slate ("113"), or one typed in; back to take 1.</summary>
    public SlateEntry NewSlate(string? slate, IReadOnlyDictionary<int, byte[]> look, IReadOnlyList<PatchFixture> patch,
                               DateTimeOffset now, ISet<(int, int)>? ignore = null)
    {
        State = State with { Slate = SlateNumbers.Clean(slate) ?? SlateNumbers.Next(State.Slate), Take = 1 };
        return Log(SlateEntry.NewSlate, look, patch, now, ignore);
    }

    /// <summary>The same setup's next letter ("112" to "112A"); back to take 1.</summary>
    public SlateEntry Letter(IReadOnlyDictionary<int, byte[]> look, IReadOnlyList<PatchFixture> patch, DateTimeOffset now,
                             ISet<(int, int)>? ignore = null)
    {
        State = State with { Slate = SlateNumbers.NextLetter(State.Slate), Take = 1 };
        return Log(SlateEntry.NewSlate, look, patch, now, ignore);
    }

    public SlateEntry? Change(IReadOnlyDictionary<int, byte[]> look, IReadOnlyList<PatchFixture> patch, DateTimeOffset now,
                              ISet<(int, int)>? ignore = null) =>
        Entries.Count >= MaxEntries ? null : Log(SlateEntry.Change, look, patch, now, ignore);

    /// <summary>Day or night, FX, or a slate or take put right by hand, without logging a look.</summary>
    public void Set(bool? night = null, bool? fx = null, string? slate = null, int? take = null)
    {
        State = State with
        {
            Night = night ?? State.Night,
            Fx = fx ?? State.Fx,
            Slate = SlateNumbers.Clean(slate) ?? State.Slate,
            Take = take is { } t ? Math.Clamp(t, 1, 999) : State.Take,
        };
    }

    public bool Note(long id, string? note)
    {
        var index = Entries.FindIndex(e => e.Id == id);
        if (index < 0) return false;
        var text = note?.Trim();
        Entries[index] = Entries[index] with { Note = string.IsNullOrEmpty(text) ? null : text.Length > 500 ? text[..500] : text };
        return true;
    }

    private SlateEntry Log(string kind, IReadOnlyDictionary<int, byte[]> look, IReadOnlyList<PatchFixture> patch,
                           DateTimeOffset now, ISet<(int, int)>? ignore)
    {
        var changes = LastLook is { } before ? LookDiff.Compare(before, look, patch, ignore) : [];
        var id = Entries.Count == 0 ? 1 : Entries[^1].Id + 1;
        var entry = new SlateEntry(id, now, kind, State.Slate, State.Take, State.Night, State.Fx, changes, Encode(look));
        Entries.Add(entry);
        return entry;
    }

    public static Dictionary<int, string> Encode(IReadOnlyDictionary<int, byte[]> look) =>
        look.ToDictionary(p => p.Key, p => Convert.ToBase64String(p.Value));

    public static Dictionary<int, byte[]> Decode(IReadOnlyDictionary<int, string> levels)
    {
        var look = new Dictionary<int, byte[]>();
        foreach (var (universe, text) in levels)
        {
            try
            {
                var bytes = Convert.FromBase64String(text);
                if (bytes.Length <= 512) look[universe] = bytes;
            }
            catch (FormatException)
            {
                // A damaged line: that universe is left out rather than the whole day.
            }
        }
        return look;
    }
}
