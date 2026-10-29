using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// TitanDeck's Groups page (Host 0.17): which fixtures a Titan group has, as
/// fixture numbers, so the deck can type them on the desk and the desk's own
/// selection becomes the group. The group is recalled on the WebAPI user
/// (4430) and read back as Titan ids, which Titan's CITP fixture list (or its
/// fixture handles) turns into fixture numbers; the WebAPI user's selection
/// goes back to the desk's afterwards.
/// </summary>
public sealed partial class TitanActions
{
    public async Task<GroupFixturesDto> GroupFixtures(int groupTitanId, CancellationToken token)
    {
        await one.WaitAsync(token);
        try
        {
            var steps = new List<string>();
            var ids = await Members(FxRecipes.RecallGroupHandle(groupTitanId), steps, token);
            if (ids is null) return new GroupFixturesDto(false, [], "Titan didn't say what's in that group", steps);
            if (ids.Count == 0) return new GroupFixturesDto(false, [], "That group has no fixtures", steps);

            var numbers = citp.UserNumbers(ids).ToList();
            steps.Add($"Titan's CITP fixture list numbers {numbers.Count(n => n is not null)} of the group's {ids.Count} fixtures");
            if (numbers.Any(n => n is null) && await Read(FxRecipes.FixtureHandles(), token) is { } handles)
            {
                var fromHandles = FxRecipes.FixtureNumbers(handles);
                numbers = ids.Select((id, i) => numbers[i] ?? (fromHandles.TryGetValue(id, out var n) ? n : null)).ToList();
                steps.Add($"Titan's fixture handles number {fromHandles.Count} fixtures");
            }
            var missing = ids.Where((_, i) => numbers[i] is null).ToList();
            if (missing.Count > 0)
                return new GroupFixturesDto(false, [],
                    $"{missing.Count} of the group's {ids.Count} fixtures have no fixture number the Host knows (Titan ids {string.Join(", ", missing.Take(12))}); is CITP linked?",
                    steps);
            var fixtures = numbers.Select(n => n!.Value).Distinct().ToList();
            return new GroupFixturesDto(true, fixtures, $"{fixtures.Count} fixture{(fixtures.Count == 1 ? "" : "s")}", steps);
        }
        finally
        {
            await PutBackDeskSelection(token);
            one.Release();
        }
    }
}
