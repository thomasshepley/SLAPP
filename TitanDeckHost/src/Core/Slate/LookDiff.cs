using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Core.Slate;

/// <summary>
/// One thing that's different between two looks. <c>Fixture</c> is the user
/// number (null for a channel no patched fixture covers, named by its
/// address); <c>What</c> the attribute ("Dimmer", "Red 2", "Pan") or "U1.37".
/// Levels are percent, 0-100 (16-bit attributes to a finer step).
/// </summary>
public sealed record LookChange(int? Fixture, string What, double Before, double After);

/// <summary>
/// Compares two looks (every universe's 512 levels) in the words of the
/// patch: by fixture and attribute where Titan's patch and personalities say
/// what a channel is, else by address. Changes smaller than a step or two of
/// 255 are ignored, so a flicker of noise isn't a change. Pure, so it's tested.
/// </summary>
public static class LookDiff
{
    /// <summary>Changes of this many steps of 255 (about 0.8%) or more count.</summary>
    public const int Threshold = 2;

    public static IReadOnlyList<LookChange> Compare(IReadOnlyDictionary<int, byte[]> before, IReadOnlyDictionary<int, byte[]> after,
                                                    IReadOnlyList<PatchFixture> patch, ISet<(int Universe, int Slot)>? ignore = null)
    {
        var changes = new List<LookChange>();
        var covered = new HashSet<(int, int)>();
        foreach (var fixture in patch.OrderBy(f => f.UserNumber))
        {
            var attributes = fixture.Attributes is { Count: > 0 } known
                ? known
                : Enumerable.Range(0, fixture.Channels ?? 0).Select(i => new PersonalityAttribute($"Channel {i + 1}", [i])).ToList();
            foreach (var attribute in attributes)
            {
                var slots = attribute.Offsets.Select(o => fixture.Address - 1 + o).ToList();
                if (slots.Any(s => s is < 0 or >= 512)) continue;
                foreach (var slot in slots) covered.Add((fixture.Line, slot));
                if (ignore is not null && slots.Any(s => ignore.Contains((fixture.Line, s)))) continue;
                var was = Value(before, fixture.Line, slots);
                var now = Value(after, fixture.Line, slots);
                if (Math.Abs(Coarse(before, fixture.Line, slots[0]) - Coarse(after, fixture.Line, slots[0])) >= Threshold)
                    changes.Add(new LookChange(fixture.UserNumber, attribute.Name, was, now));
            }
        }
        foreach (var universe in before.Keys.Union(after.Keys).Order())
        {
            for (var slot = 0; slot < 512; slot++)
            {
                if (covered.Contains((universe, slot)) || ignore?.Contains((universe, slot)) == true) continue;
                int was = Coarse(before, universe, slot), now = Coarse(after, universe, slot);
                if (Math.Abs(was - now) >= Threshold)
                    changes.Add(new LookChange(null, $"U{universe}.{slot + 1}", Percent(was), Percent(now)));
            }
        }
        return changes;
    }

    /// <summary>"104 Dimmer 60 → 45%", "U1.37 12 → 0%".</summary>
    public static string Describe(LookChange change) =>
        $"{(change.Fixture is { } n ? $"{n} " : "")}{change.What} {Round(change.Before)} → {Round(change.After)}%";

    private static int Coarse(IReadOnlyDictionary<int, byte[]> look, int universe, int slot) =>
        look.TryGetValue(universe, out var levels) && slot < levels.Length ? levels[slot] : 0;

    private static double Value(IReadOnlyDictionary<int, byte[]> look, int universe, IReadOnlyList<int> slots)
    {
        if (slots.Count == 1) return Percent(Coarse(look, universe, slots[0]));
        var raw = Coarse(look, universe, slots[0]) * 256 + Coarse(look, universe, slots[1]);
        return Math.Round(raw / 65535.0 * 1000) / 10;
    }

    private static double Percent(int level) => Math.Round(level / 255.0 * 1000) / 10;

    private static string Round(double percent) => percent == Math.Floor(percent) ? $"{percent:0}" : $"{percent:0.#}";
}
