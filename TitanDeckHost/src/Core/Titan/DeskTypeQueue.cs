using TitanDeckHost.Core.Api;

namespace TitanDeckHost.Core.Titan;

/// <summary>What became of keys the iPad asked to have typed.</summary>
public sealed record DeskTypeResult(bool Typed, string? Problem);

/// <summary>
/// Keypad lines from the iPad, waiting for the Host window app to type them
/// (the service runs in session 0 and can't type on the desktop), and what
/// became of each (Host 0.19). The window app long-polls for jobs, types each
/// one whole and reports back, so the iPad is told what happened and never
/// just "sent": typed, or exactly why not. A line is all or nothing: one
/// that has waited over a couple of seconds is refused rather than typed
/// late (an Enter long after it was pressed would be a surprise), and so is
/// one the window never confirms. No real clock or thread in here, so it's tested.
/// </summary>
public sealed class DeskTypeQueue(Func<DateTimeOffset>? clock = null)
{
    public static readonly TimeSpan TooOld = TimeSpan.FromSeconds(2);
    /// <summary>About how long the window takes over one key (hold, gap), for how long to wait on a line.</summary>
    public static readonly TimeSpan PerKey = TimeSpan.FromMilliseconds(90);

    private sealed record Waiting(DeskTypeJob Job, DateTimeOffset At, TaskCompletionSource<DeskTypeResult> Done);

    private readonly Func<DateTimeOffset> _now = clock ?? (() => DateTimeOffset.UtcNow);
    private readonly object _gate = new();
    private readonly List<Waiting> _queued = [];
    private readonly Dictionary<long, Waiting> _typing = [];
    private TaskCompletionSource _arrived = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private long _nextId;
    private int _waiting;
    private DateTimeOffset _lastPoll = DateTimeOffset.MinValue;

    /// <summary>The window app is waiting for keys, or was a moment ago.</summary>
    public bool WindowListening
    {
        get { lock (_gate) return _waiting > 0 || _now() - _lastPoll < TimeSpan.FromSeconds(5); }
    }

    /// <summary>How long a line of this many keys is given to be typed and confirmed.</summary>
    public static TimeSpan Patience(int keys) => TooOld + PerKey * keys + TimeSpan.FromSeconds(2);

    /// <summary>Queues a line; the task ends when the window has typed it, refused it, or `patience` runs out.</summary>
    public async Task<DeskTypeResult> Enqueue(IReadOnlyList<string> keys, TimeSpan? patience = null, CancellationToken cancel = default)
    {
        Waiting waiting;
        lock (_gate)
        {
            waiting = new Waiting(new DeskTypeJob(++_nextId, keys.ToList()), _now(),
                new TaskCompletionSource<DeskTypeResult>(TaskCreationOptions.RunContinuationsAsynchronously));
            _queued.Add(waiting);
            _arrived.TrySetResult();
        }
        try
        {
            return await waiting.Done.Task.WaitAsync(patience ?? Patience(keys.Count), cancel);
        }
        catch (Exception error) when (error is TimeoutException or OperationCanceledException)
        {
            lock (_gate)
            {
                // Still waiting to be picked up: take it back, so it can't be typed late.
                if (_queued.Remove(waiting))
                    return new DeskTypeResult(false, "TitanDeck Host's window didn't pick the keys up, so they weren't typed. Open TitanDeck Host on the PC.");
                _typing.Remove(waiting.Job.Id);
            }
            return new DeskTypeResult(false, "TitanDeck Host's window didn't confirm it typed the keys, so they may not all have been typed.");
        }
    }

    /// <summary>
    /// Every line waiting to be typed, in order (with only the newest of
    /// back-to-back levels, as <see cref="DeskKeys.Coalesce"/>), or none
    /// after <paramref name="wait"/>. Lines that waited too long are refused here.
    /// </summary>
    public async Task<IReadOnlyList<DeskTypeJob>> Next(TimeSpan wait, CancellationToken cancel)
    {
        lock (_gate) _waiting++;
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancel);
            timeout.CancelAfter(wait);
            while (true)
            {
                Task arrived;
                lock (_gate)
                {
                    var jobs = Take();
                    if (jobs.Count > 0) return jobs;
                    if (_arrived.Task.IsCompleted) _arrived = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
                    arrived = _arrived.Task;
                }
                await arrived.WaitAsync(timeout.Token);
            }
        }
        catch (OperationCanceledException)
        {
            return [];
        }
        finally
        {
            lock (_gate)
            {
                _waiting--;
                _lastPoll = _now();
            }
        }
    }

    /// <summary>The queued lines worth typing now. Call inside the gate.</summary>
    private List<DeskTypeJob> Take()
    {
        var now = _now();
        var fresh = new List<Waiting>();
        foreach (var waiting in _queued)
        {
            if (now - waiting.At <= TooOld) fresh.Add(waiting);
            else waiting.Done.TrySetResult(new DeskTypeResult(false, "The keys waited too long for TitanDeck Host's window, so they weren't typed late."));
        }
        _queued.Clear();
        var jobs = new List<DeskTypeJob>();
        for (var i = 0; i < fresh.Count; i++)
        {
            // A level with a newer level straight after it: only the newer one is typed.
            if (i + 1 < fresh.Count && DeskKeys.IsLevelOnly(fresh[i].Job.Keys) && DeskKeys.IsLevelOnly(fresh[i + 1].Job.Keys))
            {
                fresh[i].Done.TrySetResult(new DeskTypeResult(true, null));
                continue;
            }
            _typing[fresh[i].Job.Id] = fresh[i];
            jobs.Add(fresh[i].Job);
        }
        return jobs;
    }

    /// <summary>The window's report on a line it was given.</summary>
    public void Done(long id, bool typed, string? problem)
    {
        Waiting? waiting;
        lock (_gate)
        {
            if (!_typing.Remove(id, out waiting)) return;
        }
        waiting.Done.TrySetResult(new DeskTypeResult(typed, typed ? null : problem ?? "TitanDeck Host's window couldn't type the keys."));
    }
}
