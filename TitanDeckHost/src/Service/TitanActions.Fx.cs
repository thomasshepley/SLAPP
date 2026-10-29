using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// TitanDeck's FX page (Host 0.16, Test mode): a Prism layer's controls set
/// or released, a layer's pixel map group changed, and a probe of which
/// controls a layer fixture has. Done on the WebAPI user (4430), which can
/// only change things through its own selection, so the desk's selection
/// (CITP) is put back on it afterwards. See <see cref="FxRecipes"/>.
/// </summary>
public sealed partial class TitanActions
{
    public async Task<TitanActionDto> FxLayer(FxLayerRequest request, CancellationToken token)
    {
        await one.WaitAsync(token);
        try
        {
            return await RunFxLayer(request, token);
        }
        finally
        {
            await PutBackDeskSelection(token);
            one.Release();
        }
    }

    public async Task<TitanActionDto> FxGroup(FxGroupRequest request, CancellationToken token)
    {
        await one.WaitAsync(token);
        try
        {
            return await RunFxGroup(request, token);
        }
        finally
        {
            await PutBackDeskSelection(token);
            one.Release();
        }
    }

    public async Task<FxProbeDto> FxProbe(int fixture, IReadOnlyList<string> names, CancellationToken token)
    {
        await one.WaitAsync(token);
        try
        {
            var steps = new List<string>();
            var controls = new List<FxControlDto>();
            if (await SelectOnly(fixture, steps, token))
            {
                foreach (var name in FxRecipes.ProbeNames.Concat(names).Where(n => !string.IsNullOrWhiteSpace(n))
                             .Distinct(StringComparer.OrdinalIgnoreCase))
                {
                    var answer = await Read(FxRecipes.ControlId(name), token);
                    controls.Add(new FxControlDto(name, answer is null ? null : FxRecipes.ControlIdFrom(answer)));
                }
            }
            return new FxProbeDto(fixture, controls, steps);
        }
        finally
        {
            await PutBackDeskSelection(token);
            one.Release();
        }
    }

    private async Task<TitanActionDto> RunFxLayer(FxLayerRequest request, CancellationToken token)
    {
        var steps = new List<string>();
        if (!await SelectOnly(request.Fixture, steps, token))
            return new TitanActionDto(false, steps[^1], steps);
        var errors = new List<string>();
        foreach (var value in request.Values)
        {
            string? refused = null;
            foreach (var attempt in FxRecipes.SetControlAttempts(value.Control, value.Value))
            {
                refused = await Run(attempt, steps, token);
                if (refused is null) break;
            }
            if (refused is not null) errors.Add($"{value.Control}: {refused}");
        }
        if (request.Release)
        {
            var (status, body) = await Send(FxRecipes.Release(), token);
            if (status is < 200 or >= 300) errors.Add("Release: " + Answer(status, body));
            else steps.Add("Released the layer's controls");
        }
        var what = $"Prism layer fixture {request.Fixture}";
        if (errors.Count > 0)
            return new TitanActionDto(false, $"{what}: Titan didn't take " + string.Join(" | ", errors), steps);
        var done = request.Values.Select(v => $"{v.Control} {TitanRecipes.Number(v.Value)}").ToList();
        if (request.Release) done.Add("released");
        return new TitanActionDto(true, $"{what}: " + string.Join(", ", done), steps);
    }

    private async Task<TitanActionDto> RunFxGroup(FxGroupRequest request, CancellationToken token)
    {
        var steps = new List<string>();
        if (FxRecipes.Mode(request.Mode) is not { } mode)
            return new TitanActionDto(false, $"\"{request.Mode}\" isn't replace, add, remove or zone", steps);

        // The fixtures asked for, as Titan reads them back (Titan ids).
        IReadOnlyList<int>? given;
        if (mode == FxGroupMode.Zone)
        {
            if (request.ZoneTitanId is not { } zone) return new TitanActionDto(false, "No zone group given", steps);
            given = await Members(FxRecipes.RecallGroupHandle(zone), steps, token);
        }
        else
        {
            await Send(FxRecipes.ClearSelection(), token);
            if (request.Fixtures.Count > 0) await Send(FxRecipes.SelectFixtures(request.Fixtures), token);
            given = await ReadIds(steps, token);
        }
        if (given is null) return new TitanActionDto(false, "Titan didn't say which fixtures that is", steps);
        steps.Add($"The fixtures given: {given.Count} (Titan ids {string.Join(", ", given.Take(30))})");

        IReadOnlyList<int>? current = mode is FxGroupMode.Add or FxGroupMode.Remove
            ? await Members(FxRecipes.RecallGroup(request.Group), steps, token)
            : [];
        if (current is null) return new TitanActionDto(false, $"Titan didn't say what's in group {request.Group}", steps);
        var wanted = FxRecipes.Plan(mode, current, given);
        if (wanted.Count == 0)
            return new TitanActionDto(false,
                $"That would leave group {request.Group} empty, so it's left as it is (STOP or RELEASE the layer instead)", steps);

        var errors = new List<string>();
        foreach (var attempt in FxRecipes.ReplaceGroupAttempts(request.Group))
        {
            await Send(FxRecipes.ClearSelection(), token);
            await Send(FxRecipes.SelectTitanIds(wanted), token);
            var refused = await Run(attempt, steps, token);
            if (refused is not null)
            {
                errors.Add($"{attempt.Name}: {refused}");
                continue;
            }
            var after = await Members(FxRecipes.RecallGroup(request.Group), steps, token);
            if (after is not null && FxRecipes.SameFixtures(after, wanted))
                return new TitanActionDto(true, $"Group {request.Group} now has {wanted.Count} fixture{(wanted.Count == 1 ? "" : "s")} ({attempt.Name}, checked)", steps);
            var why = after is null ? "taken, but the group couldn't be read back" : $"taken, but the group has {after.Count}, not {wanted.Count}";
            errors.Add($"{attempt.Name}: {why}");
            steps.Add($"{attempt.Name}: {why}");
        }
        return new TitanActionDto(false, $"Group {request.Group} didn't change. Tried " + string.Join(" | ", errors), steps);
    }

    /// <summary>Just this fixture selected (by user number); false (with why in steps) if Titan has no such fixture.</summary>
    private async Task<bool> SelectOnly(int fixture, List<string> steps, CancellationToken token)
    {
        await Send(FxRecipes.ClearSelection(), token);
        await Send(FxRecipes.SelectFixtures([fixture]), token);
        var ids = await ReadIds(steps, token);
        if (ids is { Count: > 0 }) return true;
        steps.Add($"Fixture {fixture} couldn't be selected: is that the Prism layer's fixture number in Titan?");
        return false;
    }

    /// <summary>A group's fixtures: recalled onto a cleared selection, then read.</summary>
    private async Task<IReadOnlyList<int>?> Members(TitanCall recall, List<string> steps, CancellationToken token)
    {
        await Send(FxRecipes.ClearSelection(), token);
        var (status, body) = await Send(recall, token);
        if (status is < 200 or >= 300)
        {
            steps.Add($"{recall.PathAndQuery}: {Answer(status, body)}");
            return null;
        }
        return await ReadIds(steps, token);
    }

    private async Task<IReadOnlyList<int>?> ReadIds(List<string> steps, CancellationToken token)
    {
        var answer = await Read(FxRecipes.ReadSelection(), token);
        var ids = answer is null ? null : FxRecipes.Ids(answer);
        if (ids is null) steps.Add("Titan's selection couldn't be read: " + (answer ?? "no answer"));
        return ids;
    }

    /// <summary>The WebAPI user's selection back to the desk's (CITP), as TitanDeck mirrors it.</summary>
    private async Task PutBackDeskSelection(CancellationToken token)
    {
        try
        {
            await Send(FxRecipes.ClearSelection(), CancellationToken.None);
            var desk = citp.Selection();
            if (desk.Linked && desk.Fixtures.Count > 0) await Send(FxRecipes.SelectFixtures(desk.Fixtures), CancellationToken.None);
        }
        catch (Exception)
        {
            // Titan not answering: the iPad mirrors the desk again on its next change.
        }
    }
}
