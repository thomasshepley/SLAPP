using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Core.Levels;

/// <summary>Why a fixture has no level.</summary>
public enum LevelGap
{
    None,
    /// <summary>It isn't in Titan's patch.</summary>
    NotPatched,
    /// <summary>Nothing is sending its universe as sACN (a line on the DMX sockets only, or sACN not set up).</summary>
    NoSacn,
    /// <summary>Which of its channels is the dimmer isn't known yet.</summary>
    NoDimmerChannel,
}

/// <summary>One fixture's level now (0...1), or why there isn't one.</summary>
/// <param name="Universe">The sACN universe it was looked for on.</param>
/// <param name="Source">"learnt", "personality" or "dimmer": how its dimmer channel is known.</param>
public sealed record FixtureLevel(int User, double? Level, LevelGap Gap, int Universe, string? Source);

/// <summary>What a watch learnt, for the log.</summary>
public sealed record LevelLesson(string What);

/// <summary>
/// Every patched fixture's level, worked out on the Titan PC from the sACN
/// Titan sends and Titan's patch (Host 0.20). Titan can't be asked for a
/// level (not by its WebAPI, not over CITP), so this is the nearest thing to
/// its Intensity view.
///
/// Which channel of a fixture is its dimmer comes from, in order: what was
/// learnt on this rig, Titan's personality for it, or (a one-channel
/// fixture) its only channel. Learning is by fixture type, not by fixture:
/// TitanDeck says "fixtures 404 and 405 are about to go to 50%"
/// (<see cref="Expect"/>), the tracker watches those fixtures' own channels
/// (<see cref="Observe"/>), and the channel that moves to 50% is the dimmer
/// for every fixture of that model and mode, from then on. The same watch
/// finds which sACN universe a DMX line goes out on when it isn't the
/// line's own number. Before 0.20 the iPad did the learning, one fixture at
/// a time, from nudges only, and only on universes the Host happened to be
/// listening to: a fixture on universe 17 never learnt at all.
///
/// No clock, sockets or files in here, so it's tested. Thread-safe.
/// </summary>
public sealed class LevelTracker
{
    /// <summary>How long a watch looks for the level to arrive.</summary>
    public static readonly TimeSpan WatchFor = TimeSpan.FromSeconds(6);
    /// <summary>A channel this close to the level asked for (of 255) has arrived.</summary>
    public const int Near = 2;
    /// <summary>A channel had to be further than this from it beforehand to count as having moved there.</summary>
    public const int Far = 5;
    /// <summary>More channels than this arriving together isn't a dimmer.</summary>
    public const int MostChannels = 8;

    private readonly Func<int, byte[]?> _universe;
    private readonly Func<IReadOnlyList<int>> _heard;
    private readonly Func<DateTimeOffset> _now;
    private readonly object _gate = new();
    private readonly Dictionary<string, int[]> _learnt;
    private readonly Dictionary<int, int> _lineUniverse;
    private Watch? _watch;

    private sealed class Watch
    {
        public required int Target;
        public required DateTimeOffset Until;
        public required List<Watched> Fixtures;
    }

    private sealed class Watched
    {
        public required PatchFixture Fixture;
        /// <summary>The fixture's own channels as they were, per universe looked at.</summary>
        public required Dictionary<int, byte[]> Before;
        public (int Universe, int[] Offsets)? Candidate;
        public (int Universe, int[] Offsets)? Settled;
    }

    /// <param name="universe">A universe's 512 levels as heard now, or null when nothing is sending it.</param>
    /// <param name="heard">Every universe heard now.</param>
    public LevelTracker(Func<int, byte[]?> universe, Func<IReadOnlyList<int>> heard,
                        IReadOnlyDictionary<string, int[]>? learnt = null, IReadOnlyDictionary<int, int>? lineUniverse = null,
                        Func<DateTimeOffset>? clock = null)
    {
        _universe = universe;
        _heard = heard;
        _now = clock ?? (() => DateTimeOffset.UtcNow);
        _learnt = learnt?.ToDictionary(p => p.Key, p => p.Value.ToArray(), StringComparer.OrdinalIgnoreCase)
                  ?? new Dictionary<string, int[]>(StringComparer.OrdinalIgnoreCase);
        _lineUniverse = lineUniverse?.ToDictionary(p => p.Key, p => p.Value) ?? [];
    }

    /// <summary>Dimmer channels learnt, by fixture type (to keep between restarts).</summary>
    public IReadOnlyDictionary<string, int[]> Learnt
    {
        get { lock (_gate) return _learnt.ToDictionary(p => p.Key, p => p.Value.ToArray()); }
    }

    /// <summary>DMX lines found on a different sACN universe (to keep between restarts).</summary>
    public IReadOnlyDictionary<int, int> LineUniverses
    {
        get { lock (_gate) return _lineUniverse.ToDictionary(p => p.Key, p => p.Value); }
    }

    /// <summary>Forgets everything learnt (a new rig).</summary>
    public void Forget()
    {
        lock (_gate)
        {
            _learnt.Clear();
            _lineUniverse.Clear();
            _watch = null;
        }
    }

    /// <summary>The sACN universe a DMX line is looked for on: its own number unless a watch found it elsewhere.</summary>
    public int UniverseOf(int line)
    {
        lock (_gate) return _lineUniverse.GetValueOrDefault(line, line);
    }

    /// <summary>A fixture type: every fixture of the same model, mode and size has its dimmer in the same place.</summary>
    public static string TypeKey(PatchFixture fixture) =>
        string.IsNullOrWhiteSpace(fixture.Model)
            ? $"#{fixture.UserNumber}"   // Titan didn't name it: this fixture alone
            : $"{fixture.Model.Trim()}|{fixture.Mode?.Trim()}|{fixture.Channels}";

    /// <summary>The levels of these fixtures (all of the patch for null), in the order asked.</summary>
    public IReadOnlyList<FixtureLevel> Levels(IReadOnlyList<PatchFixture> patch, IReadOnlyCollection<int>? users = null)
    {
        var byUser = patch.GroupBy(f => f.UserNumber).ToDictionary(g => g.Key, g => g.First());
        var wanted = users ?? patch.Select(f => f.UserNumber).ToList();
        var universes = new Dictionary<int, byte[]?>();
        var result = new List<FixtureLevel>(wanted.Count);
        lock (_gate)
        {
            foreach (var user in wanted)
            {
                if (!byUser.TryGetValue(user, out var fixture))
                {
                    result.Add(new FixtureLevel(user, null, LevelGap.NotPatched, 0, null));
                    continue;
                }
                var universe = _lineUniverse.GetValueOrDefault(fixture.Line, fixture.Line);
                if (!universes.TryGetValue(universe, out var levels)) universes[universe] = levels = _universe(universe);
                if (levels is null)
                {
                    result.Add(new FixtureLevel(user, null, LevelGap.NoSacn, universe, null));
                    continue;
                }
                var (offsets, source) = DimmerOf(fixture);
                if (offsets is null)
                {
                    result.Add(new FixtureLevel(user, null, LevelGap.NoDimmerChannel, universe, null));
                    continue;
                }
                var level = LevelLearning.Level(offsets, levels, fixture.Address);
                result.Add(new FixtureLevel(user, level, level is null ? LevelGap.NoDimmerChannel : LevelGap.None, universe, source));
            }
        }
        return result;
    }

    /// <summary>Where a fixture's dimmer is, and how that's known. Call inside the gate.</summary>
    private (IReadOnlyList<int>? Offsets, string? Source) DimmerOf(PatchFixture fixture)
    {
        if (_learnt.TryGetValue(TypeKey(fixture), out var learnt)) return (learnt, "learnt");
        if (fixture.Intensity is { Count: > 0 } known) return (known, "personality");
        return fixture.Channels == 1 ? ([0], "dimmer") : (null, null);
    }

    /// <summary>
    /// TitanDeck is about to set these fixtures to a level (0...1): remember
    /// how their channels are now, and watch for the ones that get there.
    /// A newer call replaces the watch.
    /// </summary>
    public void Expect(IReadOnlyList<PatchFixture> patch, IReadOnlyCollection<int> users, double level)
    {
        var target = (int)Math.Round(Math.Clamp(level, 0, 1) * 255);
        var heard = _heard();
        var watched = new List<Watched>();
        lock (_gate)
        {
            foreach (var fixture in patch.Where(f => users.Contains(f.UserNumber)).GroupBy(f => f.UserNumber).Select(g => g.First()))
            {
                var own = _lineUniverse.GetValueOrDefault(fixture.Line, fixture.Line);
                var before = new Dictionary<int, byte[]>();
                // Its own universe, and every other one heard in case the line goes out on a different number.
                foreach (var universe in heard.Prepend(own).Distinct())
                    if (_universe(universe) is { } levels && Footprint(levels, fixture) is { Length: > 0 } footprint)
                        before[universe] = footprint;
                if (before.Count > 0) watched.Add(new Watched { Fixture = fixture, Before = before });
            }
            _watch = watched.Count == 0 ? null : new Watch { Target = target, Until = _now() + WatchFor, Fixtures = watched };
        }
    }

    /// <summary>A watch is running: call <see cref="Observe"/> every 100 ms or so.</summary>
    public bool Watching
    {
        get { lock (_gate) return _watch is not null; }
    }

    /// <summary>
    /// Looks at the watched fixtures' channels again. When the watch is over
    /// (everything settled, or time's up) returns what it learnt, which may
    /// be nothing; null while it's still watching or there's no watch.
    /// </summary>
    public IReadOnlyList<LevelLesson>? Observe()
    {
        lock (_gate)
        {
            if (_watch is not { } watch) return null;
            var universes = new Dictionary<int, byte[]?>();
            byte[]? Now(int universe)
            {
                if (!universes.TryGetValue(universe, out var levels)) universes[universe] = levels = _universe(universe);
                return levels;
            }
            foreach (var watched in watch.Fixtures.Where(w => w.Settled is null))
            {
                var own = _lineUniverse.GetValueOrDefault(watched.Fixture.Line, watched.Fixture.Line);
                (int Universe, int[] Offsets)? found = null;
                // Its own universe first; another only if nothing arrived there.
                foreach (var universe in watched.Before.Keys.OrderBy(u => u == own ? 0 : 1).ThenBy(u => u))
                {
                    if (Now(universe) is not { } levels) continue;
                    if (LevelLearning.Arrived(watched.Before[universe], Footprint(levels, watched.Fixture), watch.Target) is not { } offsets) continue;
                    found = (universe, offsets);
                    break;
                }
                // The same answer twice running: settled, not a fade passing through.
                if (found is { } now && watched.Candidate is { } last && last.Universe == now.Universe && last.Offsets.SequenceEqual(now.Offsets))
                    watched.Settled = now;
                watched.Candidate = found;
            }
            if (watch.Fixtures.Any(w => w.Settled is null) && _now() < watch.Until) return null;
            _watch = null;
            return Learn(watch);
        }
    }

    /// <summary>Takes what the watched fixtures agree on. Call inside the gate.</summary>
    private List<LevelLesson> Learn(Watch watch)
    {
        var lessons = new List<LevelLesson>();
        var settled = watch.Fixtures.Where(w => w.Settled is not null).ToList();
        // A line's universe: every fixture on it that arrived somewhere must agree where.
        foreach (var line in settled.GroupBy(w => w.Fixture.Line))
        {
            var found = line.Select(w => w.Settled!.Value.Universe).Distinct().ToList();
            if (found.Count != 1) continue;
            var current = _lineUniverse.GetValueOrDefault(line.Key, line.Key);
            if (found[0] == current) continue;
            if (found[0] == line.Key) _lineUniverse.Remove(line.Key); else _lineUniverse[line.Key] = found[0];
            lessons.Add(new LevelLesson($"DMX line {line.Key} goes out as sACN universe {found[0]}"));
        }
        // A type's dimmer: every fixture of the type that arrived must agree which channels.
        foreach (var type in settled.GroupBy(w => TypeKey(w.Fixture), StringComparer.OrdinalIgnoreCase))
        {
            var found = type.Select(w => w.Settled!.Value.Offsets).ToList();
            if (found.Any(o => !o.SequenceEqual(found[0]))) continue;
            if (_learnt.TryGetValue(type.Key, out var known) && known.SequenceEqual(found[0])) continue;
            _learnt[type.Key] = found[0];
            var fixture = type.First().Fixture;
            var channels = string.Join(", ", found[0].Select(o => o + 1));
            lessons.Add(new LevelLesson(
                $"{fixture.Model ?? $"fixture {fixture.UserNumber}"}{(fixture.Mode is { Length: > 0 } mode ? $" ({mode})" : "")}: " +
                $"dimmer on channel {channels} of the fixture, seen on fixture {string.Join(", ", type.Select(w => w.Fixture.UserNumber))}"));
        }
        return lessons;
    }

    /// <summary>A fixture's own channels out of its universe (the patch's channel count, else what's left of the universe, 64 at most).</summary>
    private static byte[] Footprint(byte[] universe, PatchFixture fixture)
    {
        var from = fixture.Address - 1;
        if (from < 0 || from >= universe.Length) return [];
        var count = Math.Min(fixture.Channels is > 0 and var n ? n : 64, universe.Length - from);
        return universe.AsSpan(from, count).ToArray();
    }
}

/// <summary>The sums behind <see cref="LevelTracker"/>.</summary>
public static class LevelLearning
{
    /// <summary>
    /// The channels (0-based, within a fixture) that moved to the level asked
    /// for: its dimmer. One channel; a coarse and fine pair (the fine one
    /// moves too, to wherever); or, for a fixture with no dimmer channel, the
    /// colour channels that all went there. Null when nothing arrived, or too
    /// much else moved at the same time to be sure (an effect running): the
    /// next level set tries again.
    /// </summary>
    public static int[]? Arrived(ReadOnlySpan<byte> before, ReadOnlySpan<byte> after, int target)
    {
        var count = Math.Min(before.Length, after.Length);
        var arrived = new List<int>();
        var others = new List<int>();
        for (var i = 0; i < count; i++)
        {
            if (Math.Abs(after[i] - target) <= LevelTracker.Near && Math.Abs(before[i] - target) > LevelTracker.Far) arrived.Add(i);
            else if (Math.Abs(after[i] - before[i]) > LevelTracker.Near) others.Add(i);
        }
        if (arrived.Count is 0 or > LevelTracker.MostChannels) return null;
        if (others.Count == 0) return arrived.ToArray();
        // One more channel moving is the fine half of a 16-bit dimmer, straight after the coarse.
        return arrived.Count == 1 && others.Count == 1 && others[0] == arrived[0] + 1 ? [arrived[0], others[0]] : null;
    }

    /// <summary>
    /// A fixture's level (0...1) from its dimmer channels: two neighbours are
    /// coarse then fine (the coarse is the level); otherwise the brightest
    /// (colour channels standing in for a dimmer). Null if they'd run off the universe.
    /// </summary>
    public static double? Level(IReadOnlyList<int> offsets, byte[] universe, int address)
    {
        if (offsets.Count == 0) return null;
        var values = new List<int>(offsets.Count);
        foreach (var offset in offsets)
        {
            var index = address - 1 + offset;
            if (index < 0 || index >= universe.Length) return null;
            values.Add(universe[index]);
        }
        var pair = offsets.Count == 2 && offsets[1] == offsets[0] + 1;
        return (pair ? values[0] : values.Max()) / 255.0;
    }
}
