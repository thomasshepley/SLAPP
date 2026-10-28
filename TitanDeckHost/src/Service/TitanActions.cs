using System.Diagnostics;
using System.Text;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// TitanDeck's cue fade and Clear keys, done here on the Titan PC through
/// Titan's WebAPI (4430), so a better way of doing them only needs a Host
/// update. Each way (<see cref="TitanRecipes"/>) is tried in turn and checked
/// (the time read back from the cue, the desk's selection over CITP), and
/// every call is in the Titan log. One action at a time: the WebAPI user's
/// editor is shared.
/// </summary>
public sealed class TitanActions(TitanLog titanLog, CitpService citp)
{
    private const string Who = "Host - Titan actions";
    private static readonly HttpClient Titan = new() { Timeout = TimeSpan.FromSeconds(3) };
    private readonly SemaphoreSlim one = new(1, 1);

    public async Task<TitanActionDto> CueFade(CueFadeRequest request, CancellationToken token)
    {
        await one.WaitAsync(token);
        try
        {
            return await RunCueFade(request.TitanId, request.FadeOut, request.Seconds, token);
        }
        finally
        {
            one.Release();
        }
    }

    public async Task<TitanActionDto> ClearSelection(CancellationToken token)
    {
        await one.WaitAsync(token);
        try
        {
            return await RunClear(token);
        }
        finally
        {
            one.Release();
        }
    }

    private async Task<TitanActionDto> RunCueFade(int titanId, bool fadeOut, double seconds, CancellationToken token)
    {
        var steps = new List<string>();
        var what = $"handle {titanId} fade {(fadeOut ? "out" : "in")} {TitanRecipes.Number(seconds)}s";
        if (!await Open(titanId, steps, token))
            return new TitanActionDto(false, $"Couldn't open cue 1 of handle {titanId} in Titan's editor: " + steps[^1], steps);
        var current = await Read(TitanRecipes.ReadFade(fadeOut), token);
        var other = fadeOut ? await Read(TitanRecipes.ReadFade(false), token) : null;
        steps.Add("Titan reads the time as " + (current ?? "nothing"));
        var currentSeconds = current is null ? null : TitanRecipes.Seconds(current);
        if (currentSeconds is { } now && Math.Abs(now - seconds) < 0.05)
            return new TitanActionDto(true, $"{what}: the cue already has it", steps);

        var errors = new List<string>();
        foreach (var attempt in TitanRecipes.CueFadeAttempts(titanId, fadeOut, seconds,
                     other is null ? null : TitanRecipes.Seconds(other), current))
        {
            var refused = await Run(attempt, steps, token);
            if (refused is not null)
            {
                errors.Add($"{attempt.Name}: {refused}");
                continue;
            }
            var first = await ReadSeconds(fadeOut, token);
            await Open(titanId, steps, token);
            var again = await ReadSeconds(fadeOut, token);
            if (first is { } a && again is { } b && Math.Abs(a - seconds) < 0.05 && Math.Abs(b - seconds) < 0.05)
                return new TitanActionDto(true, $"{what}: set with {attempt.Name}, checked on the cue", steps);
            var why = first is null ? "taken, but the time couldn't be read back"
                : Math.Abs(first.Value - seconds) >= 0.05 ? $"taken, but the time stayed {TitanRecipes.Number(first.Value)}s"
                : $"the editor showed {TitanRecipes.Number(first.Value)}s, but the cue still has {(again is null ? "an unreadable time" : TitanRecipes.Number(again.Value) + "s")}";
            errors.Add($"{attempt.Name}: {why}");
            steps.Add($"{attempt.Name}: {why}");
        }
        return new TitanActionDto(false,
            $"{what} not set. Tried {string.Join(" | ", errors)}. Titan read the time as {current ?? "nothing"}.", steps);
    }

    private async Task<TitanActionDto> RunClear(CancellationToken token)
    {
        var steps = new List<string>();
        var errors = new List<string>();
        var before = citp.Selection();
        switch (TitanRecipes.PlanClear(before.Linked, before.Fixtures.Count))
        {
            case TitanRecipes.ClearPlan.AlreadyClear:
                return new TitanActionDto(true, "Nothing selected on the desk (CITP), so nothing to clear", steps);
            case TitanRecipes.ClearPlan.CitpClear:
                if (citp.ClearDeskSelection())
                {
                    steps.Add($"CITP: told Titan nothing is selected ({before.Fixtures.Count} were)");
                    if (await DeskCleared(token)) return new TitanActionDto(true, "Cleared over CITP, checked over CITP", steps);
                    // No WebAPI clears after this: on Titan 19 they don't reach
                    // the desk's selection (0.13-0.14), and each one only held
                    // up the keys pressed after CLEAR by seconds.
                    var left = citp.Selection().Fixtures.Count;
                    steps.Add($"CITP clear: the desk still has {left} selected");
                    return new TitanActionDto(false, $"Sent the clear over CITP, but the desk still has {left} selected", steps);
                }
                else
                {
                    errors.Add("CITP clear: no CITP link to send it on");
                }
                break;
            default:
                steps.Add("CITP isn't linked, so the Host can't clear the desk's selection over CITP or check it");
                break;
        }
        foreach (var attempt in TitanRecipes.ClearSelectionAttempts())
        {
            var refused = await Run(attempt, steps, token);
            if (refused is not null)
            {
                errors.Add($"{attempt.Name}: {refused}");
                continue;
            }
            if (!citp.Selection().Linked)
                return new TitanActionDto(true, $"Cleared with {attempt.Name} (CITP isn't linked, so the desk's selection couldn't be checked)", steps);
            if (await DeskCleared(token)) return new TitanActionDto(true, $"Cleared with {attempt.Name}, checked over CITP", steps);
            var left = citp.Selection().Fixtures.Count;
            errors.Add($"{attempt.Name}: taken, but the desk still has {left} selected");
            steps.Add($"{attempt.Name}: the desk still has {left} selected (CITP)");
        }
        return new TitanActionDto(false, "The desk's selection didn't clear. Tried " + string.Join(" | ", errors), steps);
    }

    /// <summary>
    /// The desk's selection (CITP) is empty, or goes empty within a second
    /// (Titan sends a new selection as it changes). Short, because the keys
    /// pressed after CLEAR wait for it.
    /// </summary>
    private async Task<bool> DeskCleared(CancellationToken token)
    {
        for (var wait = 0; wait < 10 && citp.Selection().Fixtures.Count > 0; wait++)
            await Task.Delay(100, token);
        return citp.Selection().Fixtures.Count == 0;
    }

    /// <summary>Opens the cue; false if selecting it failed.</summary>
    private async Task<bool> Open(int titanId, List<string> steps, CancellationToken token)
    {
        var calls = TitanRecipes.OpenCue(titanId);
        foreach (var call in calls)
        {
            var (status, body) = await Send(call, token);
            if (call == calls[^1] && status is < 200 or >= 300)
            {
                steps.Add($"{call.PathAndQuery}: {Answer(status, body)}");
                return false;
            }
        }
        return true;
    }

    /// <summary>Runs an attempt's calls; null when Titan took them all, else what it said.</summary>
    private async Task<string?> Run(TitanAttempt attempt, List<string> steps, CancellationToken token)
    {
        foreach (var call in attempt.Calls)
        {
            var (status, body) = await Send(call, token);
            if (status is < 200 or >= 300)
            {
                steps.Add($"{attempt.Name}: {Answer(status, body)}");
                return Answer(status, body);
            }
        }
        steps.Add($"{attempt.Name}: Titan took it");
        return null;
    }

    private async Task<string?> Read(TitanCall call, CancellationToken token)
    {
        var (status, body) = await Send(call, token);
        return status == 200 ? body : null;
    }

    private async Task<double?> ReadSeconds(bool fadeOut, CancellationToken token) =>
        await Read(TitanRecipes.ReadFade(fadeOut), token) is { } text ? TitanRecipes.Seconds(text) : null;

    private async Task<(int Status, string Body)> Send(TitanCall call, CancellationToken token)
    {
        var watch = Stopwatch.StartNew();
        using var request = new HttpRequestMessage(new HttpMethod(call.Method), $"http://127.0.0.1:{TitanUiConfig.ApiPort}{call.PathAndQuery}");
        if (call.Body is not null) request.Content = new StringContent(call.Body, Encoding.UTF8, "application/json");
        var question = call.PathAndQuery.IndexOf('?');
        var path = question < 0 ? call.PathAndQuery : call.PathAndQuery[..question];
        var query = question < 0 ? "" : Uri.UnescapeDataString(call.PathAndQuery[(question + 1)..]);
        try
        {
            using var response = await Titan.SendAsync(request, token);
            var bytes = await response.Content.ReadAsByteArrayAsync(token);
            var status = (int)response.StatusCode;
            titanLog.Add(Who, "Host", call.Method, path, query + (call.Body is null ? "" : " " + call.Body), status,
                (int)watch.ElapsedMilliseconds, DeskLink.AnswerNote(bytes, response.IsSuccessStatusCode), null,
                !response.IsSuccessStatusCode, DateTimeOffset.Now);
            return (status, Encoding.UTF8.GetString(bytes).Trim());
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException && !token.IsCancellationRequested)
        {
            titanLog.Add(Who, "Host", call.Method, path, query, 502, (int)watch.ElapsedMilliseconds,
                "Titan's WebAPI isn't answering on " + TitanUiConfig.ApiPort, null, true, DateTimeOffset.Now);
            return (502, "Titan's WebAPI isn't answering");
        }
    }

    private static string Answer(int status, string body) =>
        $"HTTP {status}" + (body.Length == 0 ? "" : ": " + (body.Length <= 200 ? body : body[..200] + "..."));
}
