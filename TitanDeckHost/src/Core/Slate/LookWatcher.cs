namespace TitanDeckHost.Core.Slate;

/// <summary>
/// Watches the output for a new look: something changed since the last look
/// logged, and it's been still for a couple of seconds. Channels that keep
/// moving (a chase or an effect) are left out, so a running effect neither
/// counts as a change nor stops a look ever settling. Fed a sample of every
/// universe a couple of times a second. Pure (time comes in), so it's tested.
/// </summary>
public sealed class LookWatcher(TimeSpan settle)
{
    /// <summary>A channel that changed in this many of the recent samples is "moving".</summary>
    private const int MovingAfter = 3;
    private const int History = 6;

    private Dictionary<int, byte[]>? last;
    private Dictionary<int, byte[]>? logged;
    private readonly Dictionary<(int, int), int> recent = [];   // a bit per recent sample: changed or not
    private DateTimeOffset stillSince = DateTimeOffset.MinValue;

    /// <summary>Channels moving right now (left out of looks).</summary>
    public IReadOnlySet<(int Universe, int Slot)> Moving =>
        recent.Where(r => System.Numerics.BitOperations.PopCount((uint)r.Value) >= MovingAfter).Select(r => r.Key).ToHashSet();

    /// <summary>The look last logged (null until the first).</summary>
    public IReadOnlyDictionary<int, byte[]>? Logged => logged;

    /// <summary>Takes a sample. True when it's a new look to log (then call <see cref="Accept"/>).</summary>
    public bool Sample(IReadOnlyDictionary<int, byte[]> look, DateTimeOffset now)
    {
        var current = Copy(look);
        var changedNow = new HashSet<(int, int)>();
        if (last is not null)
        {
            foreach (var universe in current.Keys.Union(last.Keys))
            {
                var a = last.GetValueOrDefault(universe);
                var b = current.GetValueOrDefault(universe);
                for (var slot = 0; slot < 512; slot++)
                    if (Math.Abs(At(a, slot) - At(b, slot)) >= LookDiff.Threshold) changedNow.Add((universe, slot));
            }
        }
        foreach (var key in recent.Keys.ToList())
        {
            recent[key] = ((recent[key] << 1) | (changedNow.Contains(key) ? 1 : 0)) & ((1 << History) - 1);
            if (recent[key] == 0) recent.Remove(key);
        }
        foreach (var key in changedNow.Where(k => !recent.ContainsKey(k))) recent[key] = 1;
        last = current;

        var moving = Moving;
        if (stillSince == DateTimeOffset.MinValue || changedNow.Any(k => !moving.Contains(k))) stillSince = now;
        if (logged is null) return false;   // nothing to compare with until the first look is logged
        if (now - stillSince < settle) return false;
        return Differs(logged, current, moving);
    }

    /// <summary>The look that's been logged (a take, a new slate or a settled change).</summary>
    public void Accept(IReadOnlyDictionary<int, byte[]> look) => logged = Copy(look);

    private static bool Differs(Dictionary<int, byte[]> a, Dictionary<int, byte[]> b, IReadOnlySet<(int, int)> moving)
    {
        foreach (var universe in a.Keys.Union(b.Keys))
        {
            var x = a.GetValueOrDefault(universe);
            var y = b.GetValueOrDefault(universe);
            for (var slot = 0; slot < 512; slot++)
                if (!moving.Contains((universe, slot)) && Math.Abs(At(x, slot) - At(y, slot)) >= LookDiff.Threshold) return true;
        }
        return false;
    }

    private static int At(byte[]? levels, int slot) => levels is not null && slot < levels.Length ? levels[slot] : 0;

    private static Dictionary<int, byte[]> Copy(IReadOnlyDictionary<int, byte[]> look) =>
        look.ToDictionary(p => p.Key, p => p.Value.ToArray());
}
