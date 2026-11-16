using System.Text.Json;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Levels;
using TitanDeckHost.Core.Sacn;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// Every patched fixture's level, for TitanDeck (Host 0.20): the
/// <see cref="LevelTracker"/> fed with Titan's patch (over CITP, or a patch
/// report) and the sACN this PC hears. It listens on every universe the
/// patch uses without being asked (before 0.20 only universes 1-4 and ones
/// the iPad asked for, so a fixture on universe 17 was never heard), runs
/// the watch that learns a fixture type's dimmer channel when TitanDeck
/// sets a level, and keeps what was learnt in ProgramData.
/// </summary>
public sealed class LevelService
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    /// <summary>Listening to a universe is cheap, but not without end.</summary>
    private const int MostUniverses = 256;

    private sealed record Kept(Dictionary<string, int[]>? Dimmers, Dictionary<int, int>? Lines);

    private readonly PatchReader _patch;
    private readonly DmxUniverses _store;
    private readonly SacnListener _listener;
    private readonly LiveDmxListener _live;
    /// <summary>How Titan's visualiser feed numbers its universes against sACN's, looked at again every few seconds.</summary>
    private (DateTimeOffset At, (int Offset, bool Checked)? Match) _feed;
    private string? _feedNoted;
    private readonly TitanLog _log;
    private readonly ILogger<LevelService> _logger;
    private readonly string _file;
    private readonly LevelTracker _tracker;
    private int _watching;

    public LevelService(HostPaths paths, PatchReader patch, DmxUniverses store, SacnListener listener, LiveDmxListener live,
                        TitanLog log, ILogger<LevelService> logger)
    {
        _patch = patch;
        _store = store;
        _listener = listener;
        _live = live;
        _log = log;
        _logger = logger;
        _file = Path.Combine(paths.Data, "levels.json");
        var kept = Read();
        _tracker = new LevelTracker(Universe, Heard, kept?.Dimmers, kept?.Lines);
    }

    /// <summary>A universe's levels: sACN when it's heard, else Titan's visualiser feed when that lines up with sACN.</summary>
    private byte[]? Universe(int universe)
    {
        var now = DateTimeOffset.UtcNow;
        if (_store.Get(universe, now)?.Levels is { } sacn) return sacn;
        return Feed() is { } feed ? _live.Store.Get(universe + feed.Offset, now)?.Levels : null;
    }

    private IReadOnlyList<int> Heard()
    {
        var now = DateTimeOffset.UtcNow;
        var sacn = _store.Known(now);
        return Feed() is { } feed
            ? sacn.Union(_live.Store.Known(now).Select(u => u - feed.Offset).Where(u => u >= 1)).Order().ToList()
            : sacn;
    }

    /// <summary>The visualiser feed's numbering, or null while it isn't read or doesn't match sACN.</summary>
    private (int Offset, bool Checked)? Feed()
    {
        var now = DateTimeOffset.UtcNow;
        if (now - _feed.At < TimeSpan.FromSeconds(5)) return _feed.Match;
        var feed = _live.Store.Known(now);
        // Nothing read from it (yet): looked at again each time, so it's used as soon as it turns up.
        if (feed.Count == 0)
        {
            _feed = (DateTimeOffset.MinValue, null);
            return null;
        }
        // Checked against sACN once, it's kept while the feed lasts: a rig mid-fade
        // can look different for a moment, and the level shown shouldn't come and go.
        if (_feed.Match is { Checked: true })
        {
            _feed = (now, _feed.Match);
            return _feed.Match;
        }
        var match = FeedMatch.Offset(_store.Known(now), u => _store.Get(u, now)?.Levels, feed, u => _live.Store.Get(u, now)?.Levels);
        {
            var words = match is { } m
                ? $"Titan's visualiser feed is used for lines with no sACN ({(m.Checked ? "checked against sACN" : "nothing lit on both to check it against")}" +
                  $"{(m.Offset == 0 ? "" : $", its universes are numbered {m.Offset:+0;-0} from sACN's")})"
                : "Titan's visualiser feed doesn't match the sACN for the same universes at the moment, so it isn't used";
            // Said when it changes, not every look.
            if (words != _feedNoted)
            {
                _feedNoted = words;
                _log.Add("Levels", "Host", "FEED", words, "", 200, 0, null, null, match is null, DateTimeOffset.Now);
            }
        }
        _feed = (now, match);
        return match;
    }

    /// <summary>These fixtures' levels (the whole patch for null).</summary>
    public LevelsDto Levels(IReadOnlyCollection<int>? users)
    {
        var patch = _patch.Fixtures();
        Listen(patch);
        var byUser = patch.GroupBy(f => f.UserNumber).ToDictionary(g => g.Key, g => g.First());
        var fixtures = _tracker.Levels(patch, users)
            .Select(level => new FixtureLevelDto(level.User, level.Level, Why(level, byUser.GetValueOrDefault(level.User)), level.Source, level.Universe))
            .ToList();
        return new LevelsDto(fixtures, Heard(), _listener.Problem);
    }

    /// <summary>TitanDeck is about to set these fixtures to a level: watch for the channels that get there.</summary>
    public void Expect(IReadOnlyCollection<int> users, double level)
    {
        var patch = _patch.Fixtures();
        Listen(patch);
        _tracker.Expect(patch, users, level);
        if (!_tracker.Watching || Interlocked.Exchange(ref _watching, 1) == 1) return;
        _ = Task.Run(async () =>
        {
            try
            {
                while (true)
                {
                    await Task.Delay(100);
                    var lessons = _tracker.Observe();
                    if (lessons is null)
                    {
                        if (!_tracker.Watching) break;   // replaced and gone
                        continue;
                    }
                    foreach (var lesson in lessons)
                        _log.Add("Levels", "Host", "LEARNT", lesson.What, "", 200, 0, "from a level TitanDeck set", null, false, DateTimeOffset.Now);
                    if (lessons.Count > 0) Save();
                    if (!_tracker.Watching) break;
                }
            }
            catch (Exception error)
            {
                _logger.LogWarning(error, "Watching for a level failed");
            }
            finally
            {
                Volatile.Write(ref _watching, 0);
            }
        });
    }

    /// <summary>Forgets every dimmer channel and line learnt (a new rig).</summary>
    public void Forget()
    {
        _tracker.Forget();
        Save();
        _log.Add("Levels", "Host", "FORGET", "everything learnt about dimmer channels and lines", "", 200, 0, null, null, false, DateTimeOffset.Now);
    }

    /// <summary>Joins every universe the patch could be on: each line's own number, any found elsewhere, and those below.</summary>
    private void Listen(IReadOnlyList<PatchFixture> patch)
    {
        if (patch.Count == 0) return;
        var highest = Math.Min(patch.Max(f => f.Line), MostUniverses);
        for (var universe = 1; universe <= highest; universe++) _listener.Want(universe);
        foreach (var universe in _tracker.LineUniverses.Values) _listener.Want(universe);
        // Titan's visualiser feed too, one either side in case it counts from 0.
        for (var universe = 0; universe <= highest + 1; universe++) _live.Want(universe);
    }

    private string? Why(FixtureLevel level, PatchFixture? fixture) => level.Gap switch
    {
        LevelGap.None => null,
        LevelGap.NotPatched => $"Fixture {level.User} isn't in the patch TitanDeck Host has from Titan.",
        LevelGap.NoSacn =>
            $"TitanDeck Host hears no sACN on universe {level.Universe}, where fixture {level.User} is patched" +
            (fixture is null ? "" : $" ({fixture.Line}.{fixture.Address})") +
            ". " + FeedWords() + " If that line only goes out of the DMX sockets, add sACN to it in Titan as well (a line can have both)." +
            (_listener.JoinError(level.Universe) is { } join ? $" Listening to it failed: {join}" : "") +
            (_listener.Problem is { } problem ? $" {problem}" : ""),
        _ => $"Which channel is the dimmer on {Name(fixture, level.User)} isn't known yet: Titan's personality for it wasn't found " +
             $"({_patch.PersonalityCount} on this PC). Set its level once from the deck's keypad (\"@ 50\") and the Host learns it for every fixture of that type.",
    };

    /// <summary>Where Titan's visualiser feed has got to, for a fixture with no sACN.</summary>
    private string FeedWords()
    {
        if (_live.Problem is { } problem) return problem;
        if (_live.Heard == 0) return "Titan's built-in visualiser feed (which carries every line) isn't heard on this PC either.";
        if (_live.Readable == 0)
            return "Titan's built-in visualiser feed is heard, but not in a form the Host reads yet: the Titan log has samples marked LiveDMX to pass on.";
        return Feed() is null
            ? "Titan's built-in visualiser feed is heard but doesn't match the sACN, so it isn't used."
            : "Titan's built-in visualiser feed is heard, but hasn't got that universe.";
    }

    private static string Name(PatchFixture? fixture, int user) =>
        fixture?.Model is { Length: > 0 } model
            ? model + (fixture.Mode is { Length: > 0 } mode ? $" ({mode})" : "")
            : $"fixture {user}";

    private Kept? Read()
    {
        try
        {
            return File.Exists(_file) ? JsonSerializer.Deserialize<Kept>(File.ReadAllText(_file), Json) : null;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        {
            _logger.LogWarning("Couldn't read {File}: {Error}", _file, error.Message);
            return null;
        }
    }

    private void Save()
    {
        try
        {
            var kept = new Kept(_tracker.Learnt.ToDictionary(p => p.Key, p => p.Value), _tracker.LineUniverses.ToDictionary(p => p.Key, p => p.Value));
            File.WriteAllText(_file, JsonSerializer.Serialize(kept, Json));
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            _logger.LogWarning("Couldn't save {File}: {Error}", _file, error.Message);
        }
    }
}
