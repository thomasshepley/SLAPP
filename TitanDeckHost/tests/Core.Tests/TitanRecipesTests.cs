using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class TitanRecipesTests
{
    private const string Titan19Time = """{"TimeType":0,"TimeValue":"00:00:00","TotalSeconds":0,"TimeOrDefault":"00:00:00","HasValue":true}""";

    [Fact]
    public void OpensTheCueLikeEditTimes()
    {
        var calls = TitanRecipes.OpenCue(1903).Select(c => c.PathAndQuery).ToList();
        Assert.Equal(
        [
            "/titan/script/2/ActionScript/SetProperty?id=Playbacks.Editor.SelectedPlayback&value_titanId=1903",
            "/titan/script/2/Playbacks/TimesEdit/FillTimes?handle_titanId=1903",
            "/titan/script/2/Playbacks/Editor/CueSelection/SelectCueByNumber?handle_titanId=1903&cueNumber=1",
        ], calls);
    }

    [Fact]
    public void FadeAttemptsGoSafestFirstAndNeverSelectEveryCue()
    {
        var attempts = TitanRecipes.CueFadeAttempts(1903, fadeOut: false, 2.5, null, Titan19Time);
        Assert.Equal("SetProperty value_time", attempts[0].Name);
        Assert.Equal("/titan/script/2/ActionScript/SetProperty?id=Playbacks.Editor.Times.CueFadeInTime&value_time=2.5",
            attempts[0].Calls.Single().PathAndQuery);
        var command = attempts.Single(a => a.Name.StartsWith("command line"));
        Assert.Contains(command.Calls, c => c.PathAndQuery == "/titan/script/2/Command/RunCommand?command=CUE%201%20TIME%202.5");
        Assert.StartsWith("JSON", attempts[^1].Name);
        Assert.Equal("POST", attempts[^1].Calls.Single().Method);
        Assert.DoesNotContain(attempts.SelectMany(a => a.Calls), c => c.PathAndQuery.Contains("SelectAll"));
    }

    [Fact]
    public void FindsAnotherPlaybackToOpenInBetween()
    {
        const string handles = """
            [{"handleLocation":{"group":"Playbacks","index":0,"page":0},"titanId":1903,"type":"playbackHandle"},
             {"handleLocation":{"group":"Playbacks","index":0,"page":59},"titanId":1895,"type":"masterHandle"},
             {"handleLocation":{"group":"Playbacks","index":1,"page":0},"titanId":1904,"type":"playbackHandle"}]
            """;
        Assert.Equal(1904, TitanRecipes.OtherPlayback(handles, 1903));
        Assert.Equal(1903, TitanRecipes.OtherPlayback(handles, 1904));
        Assert.Equal(1895, TitanRecipes.OtherPlayback("""[{"titanId":1903},{"titanId":1895,"type":"masterHandle"}]""", 1903));
        Assert.Null(TitanRecipes.OtherPlayback("""[{"titanId":1903,"type":"playbackHandle"}]""", 1903));
        Assert.Null(TitanRecipes.OtherPlayback("not json", 1903));
    }

    [Fact]
    public void TriesTheCueSelectedBeforeTheTimesAreFilled()
    {
        var attempts = TitanRecipes.CueFadeAttempts(1903, fadeOut: false, 2.5, null, null);
        var picked = attempts.Single(a => a.Name.StartsWith("cue selected"));
        Assert.Equal(
        [
            "/titan/script/2/Playbacks/Editor/CueSelection/SelectCueByNumber?handle_titanId=1903&cueNumber=1",
            "/titan/script/2/Playbacks/TimesEdit/FillTimes?handle_titanId=1903",
            "/titan/script/2/ActionScript/SetProperty?id=Playbacks.Editor.Times.CueFadeInTime&value_time=2.5",
        ], picked.Calls.Select(c => c.PathAndQuery));
        Assert.Contains(attempts, a => a.Calls.Any(c => c.PathAndQuery.Contains("Playbacks.TimesEdit.CueNumber")));
    }

    [Fact]
    public void FadeOutOnTheCommandLineKeepsTheFadeIn()
    {
        var withIn = TitanRecipes.CueFadeAttempts(7, fadeOut: true, 3, otherSeconds: 1.5, current: null);
        Assert.Contains(withIn, a => a.Name == "command line CUE 1 TIME 1.5 AND 3");
        var without = TitanRecipes.CueFadeAttempts(7, fadeOut: true, 3, otherSeconds: null, current: null);
        Assert.DoesNotContain(without, a => a.Name.StartsWith("command line"));
        Assert.DoesNotContain(without, a => a.Name.StartsWith("JSON"));
    }

    [Fact]
    public void ReadsTitansTimes()
    {
        Assert.Equal(0, TitanRecipes.Seconds(Titan19Time));
        Assert.Equal(2.5, TitanRecipes.Seconds("""{"TimeType":0,"TimeValue":"00:00:02.5","TotalSeconds":2.5}"""));
        Assert.Equal(90.25, TitanRecipes.Seconds("\"00:01:30.25\""));
        Assert.Equal(4, TitanRecipes.Seconds("4"));
        Assert.Equal(2.5, TitanRecipes.Seconds("""{"Ticks":25000000}"""));
        Assert.Null(TitanRecipes.Seconds("""{"Name":"Cue 1"}"""));
        Assert.Null(TitanRecipes.Seconds("soon"));
    }

    [Fact]
    public void ShapesTheNewTimeLikeTitansOwn()
    {
        var body = TitanRecipes.Shaped(2.5, Titan19Time)!;
        Assert.Contains("\"TimeType\":0", body);
        Assert.Contains("\"TimeValue\":\"00:00:02.5\"", body);
        Assert.Contains("\"TotalSeconds\":2.5", body);
        Assert.Equal(2.5, TitanRecipes.Seconds(body));
        Assert.Null(TitanRecipes.Shaped(1, "3"));
        Assert.Equal("00:01:30.25", TitanRecipes.TimeText(90.25));
        Assert.Equal("00:00:02", TitanRecipes.TimeText(2));
    }

    [Fact]
    public void ClearNeverTouchesAProgrammer()
    {
        var calls = TitanRecipes.ClearSelectionAttempts().SelectMany(a => a.Calls).Select(c => c.PathAndQuery).ToList();
        Assert.All(calls, c => Assert.Contains("ClearSelection?", c));
        Assert.DoesNotContain(calls, c => c.Contains("ClearAll") || c.Contains("Programmer?"));
    }

    [Fact]
    public void ClearGoesOverCitpOnlyWithADeskSelection()
    {
        Assert.Equal(TitanRecipes.ClearPlan.CitpClear, TitanRecipes.PlanClear(citpLinked: true, deskSelected: 3));
        Assert.Equal(TitanRecipes.ClearPlan.AlreadyClear, TitanRecipes.PlanClear(citpLinked: true, deskSelected: 0));
        Assert.Equal(TitanRecipes.ClearPlan.WebApiOnly, TitanRecipes.PlanClear(citpLinked: false, deskSelected: 0));
    }
}
