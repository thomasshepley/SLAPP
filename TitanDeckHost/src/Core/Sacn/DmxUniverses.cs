namespace TitanDeckHost.Core.Sacn;

/// <summary>
/// The latest levels of every sACN universe heard, merged the E1.31 way: the
/// highest-priority sources win, and between sources at that priority the
/// highest level wins (HTP). Preview data and non-DMX start codes are
/// ignored, a source that stops for 2.5 s or says it's terminating is
/// dropped, and late out-of-order packets are thrown away. Thread-safe.
/// </summary>
public sealed class DmxUniverses
{
    /// <summary>E1.31's network data loss timeout.</summary>
    public static readonly TimeSpan SourceTimeout = TimeSpan.FromMilliseconds(2500);

    private readonly object gate = new();
    private readonly Dictionary<int, Dictionary<Guid, Source>> universes = [];
    private readonly HashSet<int> announced = [];

    private sealed class Source(string name, byte priority, byte sequence, byte[] levels, DateTimeOffset seen)
    {
        public string Name = name;
        public byte Priority = priority;
        public byte Sequence = sequence;
        public byte[] Levels = levels;
        public DateTimeOffset Seen = seen;
    }

    /// <summary>Takes in one received packet. Returns the universes a
    /// discovery packet listed (to start listening to), else empty.</summary>
    public IReadOnlyList<int> Accept(ReadOnlySpan<byte> packet, DateTimeOffset now)
    {
        if (SacnPacket.ParseData(packet) is { } data)
        {
            Accept(data, now);
            return [];
        }
        if (SacnPacket.ParseDiscovery(packet) is { } listed)
        {
            lock (gate) announced.UnionWith(listed);
            return listed;
        }
        return [];
    }

    public void Accept(SacnData data, DateTimeOffset now)
    {
        if (data.Preview || data.StartCode != 0) return;
        lock (gate)
        {
            if (!universes.TryGetValue(data.Universe, out var sources))
                universes[data.Universe] = sources = [];
            if (data.Terminated)
            {
                sources.Remove(data.Cid);
                return;
            }
            if (sources.TryGetValue(data.Cid, out var known))
            {
                // E1.31 6.7.2: a packet 1-19 behind the last one is late; drop it.
                int step = (sbyte)(byte)(data.Sequence - known.Sequence);
                if (step is <= 0 and > -20 && now - known.Seen < SourceTimeout) return;
                known.Name = data.SourceName;
                known.Priority = data.Priority;
                known.Sequence = data.Sequence;
                known.Levels = data.Levels;
                known.Seen = now;
            }
            else
            {
                sources[data.Cid] = new Source(data.SourceName, data.Priority, data.Sequence, data.Levels, now);
            }
        }
    }

    /// <summary>A universe's merged levels (512 slots, unsent ones 0), or null
    /// if nothing live is sending it.</summary>
    public UniverseLevels? Get(int universe, DateTimeOffset now)
    {
        lock (gate)
        {
            if (!universes.TryGetValue(universe, out var sources)) return null;
            var live = sources.Values.Where(s => now - s.Seen < SourceTimeout).ToList();
            if (live.Count == 0) return null;
            var top = live.Max(s => s.Priority);
            var winners = live.Where(s => s.Priority == top).ToList();
            var levels = new byte[512];
            foreach (var source in winners)
                for (int i = 0; i < source.Levels.Length && i < 512; i++)
                    levels[i] = Math.Max(levels[i], source.Levels[i]);
            return new UniverseLevels(universe, levels, top,
                winners.Select(s => s.Name).Distinct().ToList(), now - winners.Max(s => s.Seen));
        }
    }

    /// <summary>Universes with a live source, plus any a discovery packet
    /// announced, in order.</summary>
    public IReadOnlyList<int> Known(DateTimeOffset now)
    {
        lock (gate)
        {
            var live = universes.Where(u => u.Value.Values.Any(s => now - s.Seen < SourceTimeout)).Select(u => u.Key);
            return live.Union(announced).Order().ToList();
        }
    }
}

/// <summary>One universe as the Host hands it out. Levels are 0-255, slot 1 at index 0.</summary>
public sealed record UniverseLevels(int Universe, byte[] Levels, byte Priority, IReadOnlyList<string> Sources, TimeSpan Age)
{
    /// <summary>`count` slots from DMX address `start` (1-based), clipped to the universe.</summary>
    public byte[] Slice(int start, int count)
    {
        int from = Math.Clamp(start, 1, 512) - 1;
        return Levels.AsSpan(from, Math.Clamp(count, 0, 512 - from)).ToArray();
    }
}
