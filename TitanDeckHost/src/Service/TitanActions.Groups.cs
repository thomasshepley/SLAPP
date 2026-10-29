using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// TitanDeck's Groups page (Host 0.17): which fixtures a Titan group has, as
/// fixture numbers, so the deck can type them on the desk and the desk's own
/// selection becomes the group. The group is recalled on the WebAPI user
/// (4430) and read back as Titan ids, which Titan's CITP fixture list (or its
/// fixture handles) turns into fixture numbers; the WebAPI user's selection
/// goes back to the desk's afterwards. 0.18.1: a group made of other groups
/// selected nothing by its handle, so the other ways of recalling a group
/// are tried until one selects fixtures.
/// </summary>
public sealed partial class TitanActions
{
    public async Task<GroupFixturesDto> GroupFixtures(int groupTitanId, int? groupNumber, CancellationToken token)
    {
        await one.WaitAsync(token);
        try
        {
            var steps = new List<string>();
            IReadOnlyList<int>? ids = null;
            var tried = new List<string>();
            foreach (var (name, recall) in FxRecipes.RecallGroupWays(groupTitanId, groupNumber))
            {
                var got = await Members(recall, steps, token);
                steps.Add($"{name}: {(got is null ? "no answer" : $"{got.Count} selected")}");
                tried.Add(name);
                if (got is not { Count: > 0 }) continue;
                ids = got;
                break;
            }
            if (ids is null)
                return new GroupFixturesDto(false, [], $"Titan selected nothing for that group (tried {string.Join(", ", tried)})", steps);

            var numbers = citp.UserNumbers(ids).ToList();
            steps.Add($"Titan's CITP fixture list numbers {numbers.Count(n => n is not null)} of the group's {ids.Count} fixtures");
            if (numbers.Any(n => n is null) && await Read(FxRecipes.FixtureHandles(), token) is { } handles)
            {
                var fromHandles = FxRecipes.FixtureNumbers(handles);
                numbers = ids.Select((id, i) => numbers[i] ?? (fromHandles.TryGetValue(id, out var n) ? n : null)).ToList();
                steps.Add($"Titan's fixture handles number {fromHandles.Count} fixtures");
            }
            var missing = ids.Where((_, i) => numbers[i] is null).ToList();
            var fixtures = numbers.OfType<int>().Distinct().ToList();
            if (missing.Count > 0)
                steps.Add($"No fixture number for Titan ids {string.Join(", ", missing.Take(12))}");
            if (fixtures.Count == 0)
                return new GroupFixturesDto(false, [],
                    $"None of the group's {ids.Count} fixtures has a fixture number the Host knows (Titan ids {string.Join(", ", missing.Take(12))}); is CITP linked?",
                    steps);
            // Some numbered is better than none: say which weren't.
            var message = $"{fixtures.Count} fixture{(fixtures.Count == 1 ? "" : "s")}"
                          + (missing.Count > 0 ? $" ({missing.Count} more without a fixture number left out)" : "");
            return new GroupFixturesDto(true, fixtures, message, steps);
        }
        finally
        {
            await PutBackDeskSelection(token);
            one.Release();
        }
    }
}
