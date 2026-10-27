using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Core.Citp;

/// <summary>
/// Titan's patch as it shares it with a visualiser (CAEX FixtureList), in the
/// same shape as a patch report, so the Host knows every fixture's address
/// without anyone saving a report. Only patched fixtures with a user number.
/// </summary>
public static class CitpPatch
{
    /// <summary>
    /// The CAEX spec doesn't say whether Universe and UniverseChannel count
    /// from 0 or 1. A patched fixture at universe 0 or channel 0 can only be
    /// 0-based, so if any is, that number is taken as 0-based for them all.
    /// </summary>
    public static IReadOnlyList<PatchFixture> From(IEnumerable<CaexFixture> fixtures)
    {
        var patched = fixtures.Where(f => f.Patched && f.Channel > 0).ToList();
        var universeBase = patched.Any(f => f.Universe == 0) ? 1 : 0;
        var channelBase = patched.Any(f => f.UniverseChannel == 0) ? 1 : 0;
        return patched
            .Select(f => new PatchFixture(f.Channel, Text(f.Model), Text(f.Mode), f.Universe + universeBase,
                f.UniverseChannel + channelBase, f.ChannelCount > 0 ? f.ChannelCount : null))
            .Where(f => f.Line >= 1 && f.Address is >= 1 and <= 512)
            .GroupBy(f => f.UserNumber)
            .Select(g => g.First())
            .OrderBy(f => f.UserNumber)
            .ToList();
    }

    private static string? Text(string value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
