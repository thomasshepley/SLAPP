namespace TitanDeckHost.Core.Api;

/// <summary>
/// One slow answer shared by everyone asking for it (Host 0.19.1): worked out
/// by one caller at a time, off the caller's thread, and kept for a moment.
/// The service's status reads the firewall's rules, the running programs and
/// the registry, which can take seconds on a busy PC; the Host window asks
/// every 3 seconds and each iPad asks too. Before this, every ask did all of
/// it again side by side, so a slow PC only got slower, until the window
/// gave up waiting and said the service wasn't running. No real clock in
/// here, so it's tested.
/// </summary>
public sealed class SharedAnswer<T>(Func<T> make, TimeSpan keepFor, Func<DateTimeOffset>? clock = null)
{
    private readonly Func<DateTimeOffset> _now = clock ?? (() => DateTimeOffset.UtcNow);
    private readonly object _gate = new();
    private Task<T>? _running;
    private (DateTimeOffset At, T Value)? _kept;
    private long _generation;

    /// <summary>The kept answer while it's fresh, else the one being worked out (started now if nobody has).</summary>
    public Task<T> Get()
    {
        lock (_gate)
        {
            if (_kept is { } kept && _now() - kept.At < keepFor) return Task.FromResult(kept.Value);
            if (_running is not null) return _running;
            var generation = _generation;
            return _running = Task.Run(() => Make(generation));
        }
    }

    /// <summary>Something changed (a fix was applied): the next ask works it out afresh.</summary>
    public void Forget()
    {
        lock (_gate)
        {
            _generation++;
            _kept = null;
            _running = null;   // anyone already waiting still gets theirs; new asks start again
        }
    }

    private T Make(long generation)
    {
        try
        {
            var value = make();
            lock (_gate)
            {
                // Not kept if something changed while it was being worked out.
                if (generation == _generation) _kept = (_now(), value);
            }
            return value;
        }
        finally
        {
            lock (_gate)
            {
                if (generation == _generation) _running = null;
            }
        }
    }
}
