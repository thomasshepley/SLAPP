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
        Assert.NotNull(DeskKeys.Problem(["clear"]));         // the iPad can't ask for Alt+C: only the Host's own CLEAR types it
        Assert.NotNull(DeskKeys.Problem([]));
        Assert.NotNull(DeskKeys.Problem(null));
        Assert.NotNull(DeskKeys.Problem(Enumerable.Repeat("1", DeskKeys.MaxPerRequest + 1).ToList()));
    }

    [Fact]
    public void ClearIsAltCAndOnlyTheHostTypesIt()
    {
        var (modifier, key) = DeskKeys.Chords["clear"];
        Assert.Equal(new DeskKeys.Key(0x38), modifier);   // left Alt
        Assert.Equal(new DeskKeys.Key(0x2E), key);        // C
        Assert.DoesNotContain("clear", DeskKeys.All.Keys);
    }

    [Fact]
    public void AltCOnlyWhenTheDeskHasASelection()
    {
        // The desk's Clear clears the selection, then the programmer: with nothing
        // selected, Alt+C would clear the programmer, so it isn't typed.
        Assert.Equal(TitanRecipes.ClearPlan.TypeAltC, TitanRecipes.PlanClear(citpLinked: true, deskSelected: 3, canType: true));
        Assert.Equal(TitanRecipes.ClearPlan.AlreadyClear, TitanRecipes.PlanClear(citpLinked: true, deskSelected: 0, canType: true));
        Assert.Equal(TitanRecipes.ClearPlan.WebApiOnly, TitanRecipes.PlanClear(citpLinked: false, deskSelected: 0, canType: true));
        Assert.Equal(TitanRecipes.ClearPlan.WebApiOnly, TitanRecipes.PlanClear(citpLinked: true, deskSelected: 2, canType: false));
    }
}
