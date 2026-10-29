using System.Threading.Channels;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// Keypad keys from the iPad, waiting for the Host window app to type them
/// (the service runs in session 0 and can't type on the desktop). The window
/// app long-polls <c>/local/desk/keys/wait</c>. Keys older than a couple of
/// seconds are dropped rather than typed late (an Enter long after it was
/// pressed would be a surprise).
/// </summary>
public sealed class DeskKeyQueue
{
    private static readonly TimeSpan TooOld = TimeSpan.FromSeconds(2);
    private readonly Channel<(DateTimeOffset At, IReadOnlyList<string> Keys)> _keys =
        Channel.CreateUnbounded<(DateTimeOffset, IReadOnlyList<string>)>();
    private int _waiting;
    private DateTimeOffset _lastPoll = DateTimeOffset.MinValue;

    /// <summary>The window app is waiting for keys, or was a moment ago.</summary>
    public bool WindowListening => Volatile.Read(ref _waiting) > 0 || DateTimeOffset.UtcNow - _lastPoll < TimeSpan.FromSeconds(5);

    public void Enqueue(IReadOnlyList<string> keys) => _keys.Writer.TryWrite((DateTimeOffset.UtcNow, keys));

    /// <summary>
    /// Everything waiting to be typed, in order and in one go (with only the
    /// newest of back-to-back levels, <see cref="DeskKeys.Coalesce"/>), or
    /// none after <paramref name="wait"/>.
    /// </summary>
    public async Task<IReadOnlyList<string>> Next(TimeSpan wait, CancellationToken cancel)
    {
        Interlocked.Increment(ref _waiting);
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancel);
            timeout.CancelAfter(wait);
            while (true)
            {
                var (at, keys) = await _keys.Reader.ReadAsync(timeout.Token);
                var all = DateTimeOffset.UtcNow - at <= TooOld ? keys.ToList() : [];
                // And whatever else has come in meanwhile.
                while (_keys.Reader.TryRead(out var more))
                    if (DateTimeOffset.UtcNow - more.At <= TooOld) all.AddRange(more.Keys);
                if (all.Count > 0) return DeskKeys.Coalesce(all);
            }
        }
        catch (OperationCanceledException)
        {
            return [];
        }
        finally
        {
            _lastPoll = DateTimeOffset.UtcNow;
            Interlocked.Decrement(ref _waiting);
        }
    }
}
