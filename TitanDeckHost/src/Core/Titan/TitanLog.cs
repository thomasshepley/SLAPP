namespace TitanDeckHost.Core.Titan;

/// <summary>One call to (Fake) Titan as the Host saw it.</summary>
/// <param name="Who">Which Titan and which user: "Fake Titan - WebAPI", "Desk link - Titan UI".</param>
/// <param name="From">Who sent it (the iPad's address).</param>
/// <param name="State">Fake Titan only: command lines, selections and levels after the call.</param>
/// <param name="Flagged">Something TitanDeck should never do, or a refused call.</param>
public sealed record TitanLogEntry(long Id, DateTimeOffset Time, string Who, string From, string Method, string Path,
    string Query, int Status, int Milliseconds, string? Note, string? State, bool Flagged);

/// <summary>A polling call, counted rather than listed.</summary>
public sealed record TitanPollSummary(string Who, string Path, int Count, int LastStatus, DateTimeOffset Last);

/// <summary>
/// Every Titan WebAPI call the Host handles or passes on, newest last, so you
/// can see exactly what TitanDeck sends a desk and what came back. TitanDeck
/// polls a few calls several times a second (the command line, playback and
/// fixture handles, the desk's selection); those are counted, and only listed
/// again when their answer changes, so they can't push real commands out.
/// Thread-safe; keeps the last 2000 calls.
/// </summary>
public sealed class TitanLog
{
    public const int Capacity = 2000;

    private static readonly string[] PollPaths =
    [
        "/titan/get/System/SoftwareVersion",
        "/titan/get/2/Command/CommandLineText",
        "/titan/handles/Playbacks",
        "/titan/handles/Fixtures",
        "/titan/handles/Workspaces",
        "/titan/script/2/Selection/Context/Global/GetAllSelectedFixtureIds",
    ];

    private readonly object gate = new();
    private readonly LinkedList<TitanLogEntry> entries = new();
    private readonly Dictionary<(string Who, string Path), TitanPollSummary> polls = [];
    private long nextId = 1;

    public static bool IsPoll(string method, string path) =>
        method == "GET" && PollPaths.Contains(path.TrimEnd('/'), StringComparer.OrdinalIgnoreCase);

    /// <summary>Adds a call. A repeated poll with the same answer is only
    /// counted; returns the entry when one was listed.</summary>
    public TitanLogEntry? Add(string who, string from, string method, string path, string query, int status,
        int milliseconds, string? note, string? state, bool flagged, DateTimeOffset now)
    {
        lock (gate)
        {
            if (IsPoll(method, path))
            {
                var key = (who, path);
                var seen = polls.TryGetValue(key, out var summary);
                polls[key] = new TitanPollSummary(who, path, (summary?.Count ?? 0) + 1, status, now);
                if (seen && summary!.LastStatus == status) return null;
                note ??= seen ? $"polling: answer changed to {status}" : "polling (repeats are counted, not listed)";
            }
            var entry = new TitanLogEntry(nextId++, now, who, from, method, path, query, status, milliseconds, note, state, flagged);
            entries.AddLast(entry);
            while (entries.Count > Capacity) entries.RemoveFirst();
            return entry;
        }
    }

    /// <summary>Calls after `after` (an Id), oldest first, at most `max`, plus
    /// the polling counts.</summary>
    public (IReadOnlyList<TitanLogEntry> Entries, IReadOnlyList<TitanPollSummary> Polls) Since(long after, int max = 500)
    {
        lock (gate)
        {
            var newer = entries.Where(e => e.Id > after).ToList();
            if (newer.Count > max) newer = newer.GetRange(newer.Count - max, max);
            return (newer, polls.Values.OrderBy(p => p.Who).ThenBy(p => p.Path).ToList());
        }
    }

    public void Clear()
    {
        lock (gate)
        {
            entries.Clear();
            polls.Clear();
        }
    }
}
