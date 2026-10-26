using System.Text.Json.Nodes;
using TitanDeckHost.Core.Sacn;
using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class FakeTitanTests
{
    private static FakeReply Script(FakeTitan titan, string function, string query = "", FakeUser user = FakeUser.Api) =>
        titan.Handle("/titan/script/2/" + function, query, user);

    private static void Type(FakeTitan titan, string keys, FakeUser user = FakeUser.Api)
    {
        foreach (var key in keys) Script(titan, "Command/AppendStringAndPreview", "text=" + Uri.EscapeDataString(key.ToString()), user);
        var line = titan.Handle("/titan/get/2/Command/CommandLineText", "", user).Body!.GetValue<string>();
        Script(titan, "Command/RunCommand", "command=" + Uri.EscapeDataString(line), user);
        Script(titan, "Command/StartNewCommand", "", user);
    }

    [Fact]
    public void TheKeypadSelectsAndSetsLevelsLikeTitan()
    {
        var titan = new FakeTitan();
        Type(titan, "3@50");
        Assert.Equal(50, titan.Level(3));
        Assert.Equal([3], titan.Selected(FakeUser.Api));
        Type(titan, "@5");
        Assert.Equal(50, titan.Level(3));   // one digit is tens
        Type(titan, "@@");
        Assert.Contains("didn't understand", Script(titan, "Command/RunCommand", "command=%40%40").Note);
        Assert.Contains("isn't patched", Script(titan, "Command/RunCommand", "command=99").Note);
        Assert.Equal("", titan.Handle("/titan/get/2/Command/CommandLineText", "", FakeUser.Api).Body!.GetValue<string>());
    }

    [Fact]
    public void TheDeskAndTheWebApiAreSeparateUsersSharingOneShow()
    {
        var titan = new FakeTitan();
        Type(titan, "3", FakeUser.Desk);
        Assert.Equal([3], titan.Selected(FakeUser.Desk));
        Assert.Empty(titan.Selected(FakeUser.Api));
        Script(titan, "Command/AppendStringAndPreview", "text=7");
        Assert.Equal("", titan.Handle("/titan/get/2/Command/CommandLineText", "", FakeUser.Desk).Body!.GetValue<string>());
        Script(titan, "Programmer/Editor/Fixtures/IncrementDimmer", "value=409.6&timeDelta=1&shiftEnabled=false", FakeUser.Desk);
        Assert.Equal(10, titan.Level(3), 3);   // 409.6 wheel steps = 10%   // one show
        var ids = Script(titan, "Selection/Context/Global/GetAllSelectedFixtureIds", "", FakeUser.Desk).Body!.AsArray();
        Assert.Equal([5003], ids.Select(n => n!.GetValue<int>()));
        Assert.Empty(Script(titan, "Selection/Context/Global/GetAllSelectedFixtureIds").Body!.AsArray());
    }

    [Fact]
    public void DeskSelectIsLikeClickingInLayouts()
    {
        var titan = new FakeTitan();
        Assert.Contains("[3, 4]", titan.DeskSelect([3, 4, 99]));
        Assert.Equal([3, 4], titan.Selected(FakeUser.Desk));
        Assert.Contains("empty", titan.Handle("/fake/desk-select", "fixtures=", FakeUser.Api).Note);
        Assert.Empty(titan.Selected(FakeUser.Desk));
    }

    [Fact]
    public void FlashOutAndClearFlashPutItBackExactly()
    {
        var titan = new FakeTitan();
        Type(titan, "2@80");
        Script(titan, "Programmer/Editor/Fixtures/FlashOut");
        Assert.Equal(0, titan.Level(2));
        Script(titan, "Programmer/Editor/Fixtures/ClearFlash");
        Assert.Equal(80, titan.Level(2));
        Script(titan, "Programmer/Editor/Fixtures/SetDimmerLevel", "level=0");
        Script(titan, "Programmer/Editor/Fixtures/ClearSelectedControls", "release=true&releaseTime=5");
        Assert.Equal(80, titan.Level(2));
    }

    [Fact]
    public void PatchOnTheDeskIsFlagged()
    {
        var titan = new FakeTitan();
        titan.DeskSelect([5]);
        var desk = Script(titan, "Patch/Repatch/SetDmxAddressesFromSelectedFixture", "", FakeUser.Desk);
        Assert.True(desk.Flagged);
        Script(titan, "Selection/Context/Global/SelectFixturesFromHandles", "handleList_userNumberList=5");
        var api = Script(titan, "Patch/Repatch/SetDmxAddressesFromSelectedFixture");
        Assert.False(api.Flagged);
        Assert.Equal("1.17", titan.Handle("/titan/get/2/Patch/CurrentDmxAssignment", "", FakeUser.Api).Body!.GetValue<string>());
    }

    [Fact]
    public void CueFadeTimesNeedACueSelectedFirst()
    {
        var titan = new FakeTitan();
        Assert.Equal(409, titan.Set("/titan/set/2/Playbacks/Editor/Times/CueFadeInTime", "5").Status);
        Assert.Equal(200, Script(titan, "Playbacks/Editor/CueSelection/SelectCueByNumber", "handle_titanId=1012&cueNumber=1").Status);
        Assert.Equal(200, titan.Set("/titan/set/2/Playbacks/Editor/Times/CueFadeOutTime", "2.5").Status);
        Assert.Equal(2.5, titan.CueTime(12, "CueFadeOutTime"));
        Assert.Equal(200, titan.Set("/titan/set/2/Playbacks/Editor/Times/CueFadeInTime", "{\"value\":\"0.25\"}").Status);
        Assert.Equal(0.25, titan.CueTime(12, "CueFadeInTime"));
        Assert.Equal(400, titan.Set("/titan/set/2/Playbacks/Editor/Times/CueFadeInTime", "soon").Status);
        Assert.Equal(404, titan.Set("/titan/set/2/Show/Name", "x").Status);
    }

    [Fact]
    public void PlaybacksByUserNumberOrTitanId()
    {
        var titan = new FakeTitan(new FakeTitanOptions(Playbacks: 25));
        Assert.Equal(200, Script(titan, "Playbacks/FirePlaybackAtLevel", "handle_userNumber=3&level_level=1&alwaysRefire=false").Status);
        Assert.Equal(1, titan.PlaybackLevel(3));
        Script(titan, "Playbacks/FirePlaybackAtLevel", "handle_titanId=1012&level_level=1");
        Assert.Equal(1, titan.PlaybackLevel(12));
        Script(titan, "Playbacks/SetPlaybackLevel", "srcHandle_userNumber=3&level_level=0.5");
        Assert.Equal(0.5, titan.PlaybackLevel(3));
        Script(titan, "Playbacks/ReleasePlayback", "handle_userNumber=3");
        Assert.Equal(0, titan.PlaybackLevel(3));
        Assert.Equal(404, Script(titan, "Playbacks/FirePlaybackAtLevel", "handle_userNumber=99").Status);
        Assert.Equal(400, Script(titan, "Playbacks/FirePlaybackAtLevel").Status);

        var handles = titan.Handle("/titan/handles/Playbacks", "", FakeUser.Api).Body!.AsArray();
        Assert.Equal(25, handles.Count);
        var twelfth = handles[11]!.AsObject();
        Assert.Equal(1012, twelfth["titanId"]!.GetValue<int>());
        Assert.True(twelfth["Active"]!.GetValue<bool>());
        Assert.Equal(1, twelfth["handleLocation"]!["page"]!.GetValue<int>());   // 10 per page
        Assert.Contains(twelfth["properties"]!.AsArray(), p => p!["Key"]!.GetValue<string>() == "userNumber");
    }

    [Fact]
    public void HandlesPalettesWorkspacesAndUnknownCalls()
    {
        var titan = new FakeTitan();
        var fixtures = titan.Handle("/titan/handles/Fixtures", "", FakeUser.Api).Body!.AsArray();
        Assert.Equal(12, fixtures.Count);
        Assert.Equal(5001, fixtures[0]!["titanId"]!.GetValue<int>());
        Assert.Equal("3200K", titan.Handle("/titan/handles/Colours", "", FakeUser.Api).Body!.AsArray()[1]!["Legend"]!.GetValue<string>());
        Assert.Equal(200, Script(titan, "Workspace/Apply", "handle_userNumber=2").Status);
        Assert.Equal(404, Script(titan, "Workspace/Apply", "handle_userNumber=40").Status);
        Assert.Equal(400, Script(titan, "Palette/ApplyPalette").Status);
        Assert.Equal(404, Script(titan, "Show/NewShow").Status);
        Assert.Equal(404, titan.Handle("/nonsense", "", FakeUser.Api).Status);
        Assert.Equal(FakeTitan.Version, titan.Handle("/titan/get/System/SoftwareVersion", "", FakeUser.Api).Body!.GetValue<string>());
    }

    [Fact]
    public void ItSendsEachFixtureAsRgbAndDimmerOverSacn()
    {
        var titan = new FakeTitan();
        Type(titan, "3@60");
        var dmx = titan.Universe1();
        Assert.Equal([255, 180, 120, 153], dmx[8..12]);   // fixture 3 at 9-12, Dimmer 60%
        Assert.Equal(0, dmx[3]);
        var packet = SacnPacket.Build(1, dmx, 7, Guid.NewGuid(), "Fake Titan");
        var parsed = SacnPacket.ParseData(packet);
        Assert.NotNull(parsed);
        Assert.Equal("Fake Titan", parsed.SourceName);
        Assert.Equal(7, parsed.Sequence);
        Assert.Equal(153, parsed.Levels[11]);
        Assert.Contains("3:60%", titan.StatusLine());
    }

    [Fact]
    public void QueryStringsDecodeLikeABrowser()
    {
        var q = FakeTitan.ParseQuery("?command=3%4050&text=a+b&x=1&x=2&empty");
        Assert.Equal("3@50", q["command"]);
        Assert.Equal("a b", q["text"]);
        Assert.Equal("1", q["x"]);
        Assert.Equal("", q["empty"]);
    }
}

public class TitanLogTests
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 10, 0, 0, TimeSpan.Zero);

    [Fact]
    public void PollingIsCountedNotListed()
    {
        var log = new TitanLog();
        for (int i = 0; i < 50; i++)
            log.Add("Fake Titan - WebAPI", "10.0.0.9", "GET", "/titan/get/2/Command/CommandLineText", "", 200, 1, null, null, false, T0.AddSeconds(i));
        var cue = log.Add("Fake Titan - WebAPI", "10.0.0.9", "GET", "/titan/script/2/Playbacks/FirePlaybackAtLevel",
            "handle_userNumber=1", 200, 3, "playback 1 GO", "state", false, T0.AddSeconds(60));
        Assert.NotNull(cue);
        var (entries, polls) = log.Since(0);
        Assert.Equal(2, entries.Count);   // the first poll, then the GO
        Assert.Contains("counted", entries[0].Note);
        Assert.Equal(50, Assert.Single(polls).Count);
        // A poll whose answer changes is listed again.
        Assert.NotNull(log.Add("Fake Titan - WebAPI", "10.0.0.9", "GET", "/titan/get/2/Command/CommandLineText", "", 502, 1, null, null, false, T0));
        Assert.Equal(1, log.Since(cue!.Id).Entries.Count);
    }

    [Fact]
    public void KeepsTheNewestAndReadsOnFromAnId()
    {
        var log = new TitanLog();
        for (int i = 0; i < TitanLog.Capacity + 10; i++)
            log.Add("x", "", "GET", "/titan/script/2/Macros/Run", $"macroId={i}", 200, 0, null, null, false, T0);
        var (all, _) = log.Since(0, max: 10_000);
        Assert.Equal(TitanLog.Capacity, all.Count);
        Assert.Equal("macroId=10", all[0].Query);
        var (tail, _) = log.Since(all[^3].Id);
        Assert.Equal(2, tail.Count);
        Assert.Equal(5, log.Since(0, max: 5).Entries.Count);
        log.Clear();
        Assert.Empty(log.Since(0).Entries);
    }
}
