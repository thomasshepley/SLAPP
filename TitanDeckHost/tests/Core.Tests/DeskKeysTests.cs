using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class DeskKeysTests
{
    [Fact]
    public void TitansKeyboardShortcuts()
    {
        Assert.Equal(new DeskKeys.Key(0x02), DeskKeys.All["1"]);
        Assert.Equal(new DeskKeys.Key(0x0B), DeskKeys.All["0"]);
        Assert.Equal(new DeskKeys.Key(0x37), DeskKeys.All["@"]);                    // number pad *
        Assert.Equal(new DeskKeys.Key(0x35, Extended: true), DeskKeys.All["thro"]); // number pad /
        Assert.Equal(new DeskKeys.Key(0x01), DeskKeys.All["exit"]);                 // Esc
        Assert.Equal(new DeskKeys.Key(0x1C), DeskKeys.All["enter"]);
    }

    [Fact]
    public void OnlyKeypadKeysCanBeTyped()
    {
        Assert.Null(DeskKeys.Problem(["1", "0", "2", "@", "5", "0", "enter"]));
        Assert.NotNull(DeskKeys.Problem(["a"]));             // no letters: nothing else can be typed on the PC
        Assert.NotNull(DeskKeys.Problem(["enter", "win"]));
        Assert.NotNull(DeskKeys.Problem(["clear"]));         // no Alt+C: CLEAR goes over CITP
        Assert.NotNull(DeskKeys.Problem(["next"]));          // no Alt+arrows either: they did nothing on Titan 19
        Assert.NotNull(DeskKeys.Problem([]));
        Assert.NotNull(DeskKeys.Problem(null));
        Assert.NotNull(DeskKeys.Problem(Enumerable.Repeat("1", DeskKeys.MaxPerRequest + 1).ToList()));
    }

    [Fact]
    public void OnlyTheNewestOfBackToBackLevelsIsTyped()
    {
        Assert.Equal(["@", "4", "8", "enter"],
            DeskKeys.Coalesce(["@", "6", "4", "enter", "@", "5", "6", "enter", "@", "4", "8", "enter"]));
        // A selection typed before a level is kept, and so is the level after it.
        Assert.Equal(["1", "0", "1", "@", "5", "0", "enter", "@", "6", "0", "enter"],
            DeskKeys.Coalesce(["1", "0", "1", "@", "5", "0", "enter", "@", "7", "0", "enter", "@", "6", "0", "enter"]));
        // Something typed in between keeps the level before it.
        Assert.Equal(["@", "5", "0", "enter", "1", "enter", "@", "6", "0", "enter"],
            DeskKeys.Coalesce(["@", "5", "0", "enter", "1", "enter", "@", "6", "0", "enter"]));
        // Keys still being typed (no Enter yet) are left alone.
        Assert.Equal(["@", "5", "0", "enter", "1", "0"], DeskKeys.Coalesce(["@", "5", "0", "enter", "1", "0"]));
        Assert.Empty(DeskKeys.Coalesce([]));
    }
}
