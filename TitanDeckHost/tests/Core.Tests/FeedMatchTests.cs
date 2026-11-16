using TitanDeckHost.Core.Levels;

namespace TitanDeckHost.Core.Tests;

public class FeedMatchTests
{
    private static byte[] Universe(params (int Address, byte Level)[] lit)
    {
        var levels = new byte[512];
        foreach (var (address, level) in lit) levels[address - 1] = level;
        return levels;
    }

    private static (int Offset, bool Checked)? Match(Dictionary<int, byte[]> sacn, Dictionary<int, byte[]> feed) =>
        FeedMatch.Offset(sacn.Keys.Order().ToList(), u => sacn.GetValueOrDefault(u), feed.Keys.Order().ToList(), u => feed.GetValueOrDefault(u));

    [Fact]
    public void TheSameNumbersWhenTheLevelsMatch()
    {
        var one = Universe((1, 200), (40, 90));
        var sacn = new Dictionary<int, byte[]> { [1] = one };
        var feed = new Dictionary<int, byte[]> { [1] = one.ToArray(), [4] = Universe((9, 255)) };   // 4 is on the DMX sockets only
        Assert.Equal((0, true), Match(sacn, feed));
    }

    [Fact]
    public void AFeedThatCountsFromNoughtIsOneOut()
    {
        var sacn = new Dictionary<int, byte[]> { [1] = Universe((1, 200)), [2] = Universe((7, 30)) };
        var feed = new Dictionary<int, byte[]> { [0] = Universe((1, 200)), [1] = Universe((7, 30)), [3] = Universe((9, 255)) };
        Assert.Equal((-1, true), Match(sacn, feed));
    }

    [Fact]
    public void AFeedThatMatchesNoWayRoundIsntUsed()
    {
        var sacn = new Dictionary<int, byte[]> { [1] = Universe((1, 200)) };
        var feed = new Dictionary<int, byte[]> { [1] = Enumerable.Repeat((byte)77, 512).ToArray() };
        Assert.Null(Match(sacn, feed));
    }

    [Fact]
    public void NothingOnBothIsTakenAsTheSameNumbersUnchecked()
    {
        var sacn = new Dictionary<int, byte[]> { [12] = Universe((114, 128)) };
        var feed = new Dictionary<int, byte[]> { [4] = Universe((1, 255)) };
        Assert.Equal((0, false), Match(sacn, feed));
        Assert.Equal((0, false), Match([], feed));
    }

    [Fact]
    public void DarkUniversesOnlyVouchForTheSameNumbers()
    {
        var sacn = new Dictionary<int, byte[]> { [1] = Universe(), [2] = Universe() };
        var feed = new Dictionary<int, byte[]> { [1] = Universe(), [2] = Universe() };
        Assert.Equal((0, false), Match(sacn, feed));
        // Dark and one out would "agree" too: that isn't taken as proof of anything.
        var shifted = new Dictionary<int, byte[]> { [0] = Universe(), [5] = Universe((1, 9)) };
        Assert.Null(Match(new Dictionary<int, byte[]> { [1] = Universe() }, shifted));
    }

    [Fact]
    public void AFewChannelsCaughtMidMoveStillAgree()
    {
        var a = Enumerable.Range(1, 40).Select(i => (i, (byte)100)).ToArray();
        var b = a.Select(slot => slot.i <= 3 ? (slot.i, (byte)140) : slot).ToArray();
        Assert.True(FeedMatch.Agrees(Universe(a), Universe(b)));
        Assert.False(FeedMatch.Agrees(Universe((1, 200)), Universe((7, 30))), "two different sparse universes");
        Assert.False(FeedMatch.Agrees(Universe(a), Enumerable.Repeat((byte)255, 512).ToArray()));
    }
}
