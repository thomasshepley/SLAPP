namespace TitanDeckHost.Core.Levels;

/// <summary>
/// Lines up a second source of DMX levels with the sACN the Host already
/// trusts (Host 0.20.1). Titan sends its built-in visualiser every line's
/// levels on its own feed ("LiveDMX" in Titan's manual), which is the only
/// place a line that goes out of the DMX sockets alone can be heard. Its
/// universe numbers aren't documented, so before it's used it's compared
/// with sACN wherever both carry a universe: same numbers, or one out
/// either way. Pure, so it's tested.
/// </summary>
public static class FeedMatch
{
    /// <summary>Slots this far apart (of 255) are the same level, caught a moment apart.</summary>
    public const int Near = 3;

    /// <summary>
    /// The two are the same universe: at most one slot in eight of those in
    /// use differs (one always may), which is a few channels caught mid-move.
    /// A whole rig fading can fail this; the caller looks again in a moment,
    /// and keeps a match once it has one.
    /// </summary>
    public static bool Agrees(ReadOnlySpan<byte> first, ReadOnlySpan<byte> second)
    {
        var count = Math.Min(first.Length, second.Length);
        var different = 0;
        var used = 0;
        for (var i = 0; i < count; i++)
        {
            if (first[i] != 0 || second[i] != 0) used++;
            if (Math.Abs(first[i] - second[i]) > Near) different++;
        }
        return different <= Math.Max(1, used / 8);
    }

    /// <summary>
    /// How the second feed numbers its universes: `Offset` to add to an sACN
    /// universe to get the feed's. `Checked` is false when nothing lit was on
    /// both to compare (same numbers are then assumed). Null when they share
    /// universes and don't match any way round: the feed isn't to be used.
    /// </summary>
    public static (int Offset, bool Checked)? Offset(IReadOnlyList<int> sacn, Func<int, byte[]?> sacnLevels,
                                                     IReadOnlyList<int> feed, Func<int, byte[]?> feedLevels)
    {
        var overlapped = false;
        foreach (var offset in new[] { 0, -1, 1 })
        {
            var compared = 0;
            var lit = 0;
            var agrees = true;
            foreach (var universe in sacn)
            {
                if (!feed.Contains(universe + offset)) continue;
                if (sacnLevels(universe) is not { } a || feedLevels(universe + offset) is not { } b) continue;
                compared++;
                if (!Agrees(a, b))
                {
                    agrees = false;
                    break;
                }
                if (a.AsSpan().IndexOfAnyExcept((byte)0) >= 0) lit++;
            }
            if (compared == 0) continue;
            overlapped = true;
            // Dark universes agree with anything: only the same numbers are taken on that.
            if (agrees && (lit > 0 || offset == 0)) return (offset, lit > 0);
        }
        return overlapped ? null : (0, false);
    }
}
