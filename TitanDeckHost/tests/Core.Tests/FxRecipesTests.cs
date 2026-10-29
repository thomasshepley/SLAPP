using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class FxRecipesTests
{
    [Fact]
    public void SelectsAndRecallsByNumber()
    {
        Assert.Equal("/titan/script/2/Selection/Context/Global/SelectFixturesFromHandles?handleList_userNumberList=101%2C102",
            FxRecipes.SelectFixtures([101, 102, 101]).PathAndQuery);
        Assert.Equal("/titan/script/2/Selection/Context/Global/SelectFixturesWithTitanIds?titanIds=5001%2C5002",
            FxRecipes.SelectTitanIds([5001, 5002]).PathAndQuery);
        Assert.Equal("/titan/script/2/Group/RecallGroupNumeric?userId=12", FxRecipes.RecallGroup(12).PathAndQuery);
        Assert.Equal("/titan/script/2/Group/RecallGroup?handle_titanId=4400", FxRecipes.RecallGroupHandle(4400).PathAndQuery);
        Assert.Equal("/titan/script/2/Selection/Context/Global/GetAllSelectedFixtureIds", FxRecipes.ReadSelection().PathAndQuery);
    }

    [Fact]
    public void ReplacesAGroupTwoWays()
    {
        var attempts = FxRecipes.ReplaceGroupAttempts(12);
        Assert.Equal("/titan/script/2/Group/ReplaceGroupOnHandle?handle_userNumber=12", attempts[0].Calls.Single().PathAndQuery);
        Assert.Equal("/titan/script/2/Group/StoreGroupReplace?groupId=12", attempts[1].Calls.Single().PathAndQuery);
    }

    [Fact]
    public void SetsAControlIntoTheProgrammerByName()
    {
        var attempts = FxRecipes.SetControlAttempts("Folder", 3);
        Assert.Equal("/titan/script/2/Programmer/Editor/Fixtures/SetControlValueByName?controlName=Folder&functionName=Folder&value=3&programmer=true&createRestorePoint=false",
            attempts[0].Calls.Single().PathAndQuery);
        Assert.Contains("functionName=&", attempts[1].Calls.Single().PathAndQuery);
        Assert.Equal("/titan/script/2/Programmer/Editor/Fixtures/ClearSelectedControls?release=true&releaseTime=0",
            FxRecipes.Release().PathAndQuery);
        Assert.Contains("controlName=Colour%20Adjust", FxRecipes.ControlId("Colour Adjust").PathAndQuery);
    }

    [Fact]
    public void PlansTheGroup()
    {
        Assert.Equal([1, 2, 3], FxRecipes.Plan(FxGroupMode.Add, [1, 2], [2, 3]));
        Assert.Equal([1], FxRecipes.Plan(FxGroupMode.Remove, [1, 2], [2, 3]));
        Assert.Equal([2, 3], FxRecipes.Plan(FxGroupMode.Replace, [1, 2], [2, 3, 3]));
        Assert.Equal([7], FxRecipes.Plan(FxGroupMode.Zone, [1, 2], [7]));
        Assert.True(FxRecipes.SameFixtures([1, 2], [2, 1]));
        Assert.False(FxRecipes.SameFixtures([1, 2], [1]));
        Assert.Equal(FxGroupMode.Add, FxRecipes.Mode("ADD"));
        Assert.Null(FxRecipes.Mode("delete"));
    }

    [Fact]
    public void ReadsTitansAnswers()
    {
        Assert.Equal([5001, 5002], FxRecipes.Ids("[5001,5002]"));
        Assert.Equal([5001], FxRecipes.Ids("""[{"titanId":5001},{"Name":"x"}]"""));
        Assert.Empty(FxRecipes.Ids("[]")!);
        Assert.Null(FxRecipes.Ids("""{"a":1}"""));
        Assert.Null(FxRecipes.Ids("nope"));
        Assert.Equal(42, FxRecipes.ControlIdFrom("42"));
        Assert.Equal(42, FxRecipes.ControlIdFrom("\"42\""));
        Assert.Null(FxRecipes.ControlIdFrom("-1"));
        Assert.Null(FxRecipes.ControlIdFrom(""));
    }

    [Fact]
    public void NumbersFixturesFromTitansHandles()
    {
        var numbers = FxRecipes.FixtureNumbers("""
            [{"titanId":1105,"userNumber":105},
             {"titanId":1106,"properties":[{"Key":"UserNumber","Value":"106"}]},
             {"titanId":1107,"Legend":"no number"},
             {"userNumber":9}]
            """);
        Assert.Equal(new Dictionary<int, int> { [1105] = 105, [1106] = 106 }, numbers);
        Assert.Empty(FxRecipes.FixtureNumbers("nope"));
    }
}
