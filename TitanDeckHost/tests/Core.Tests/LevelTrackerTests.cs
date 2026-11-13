using TitanDeckHost.Core.Levels;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Core.Tests;

public class LevelTrackerTests
{
    private readonly Dictionary<int, byte[]> _dmx = [];
    private DateTimeOffset _now = DateTimeOffset.UnixEpoch;

    private LevelTracker Tracker(IReadOnlyDictionary<string, int[]>? learnt = null) =>
        new(u => _dmx.GetValueOrDefault(u), () => _dmx.Keys.Order().ToList(), learnt, null, () => _now);

    private byte[] Universe(int number)
    {
        if (!_dmx.TryGetValue(number, out var levels)) _dmx[number] = levels = new byte[512];
        return levels;
    }

    private void Set(int universe, int address, byte value) => Universe(universe)[address - 1] = value;

    /// <summary>Two looks at the channels, as the service makes them.</summary>
    private static IReadOnlyList<LevelLesson>? Settle(LevelTracker tracker)
    {
        tracker.Observe();
        return tracker.Observe();
    }

    private static readonly PatchFixture Tube404 = new(404, "Titan Tube", "Mode 5", 17, 25, 10);
    private static readonly PatchFixture Tube405 = new(405, "Titan Tube", "Mode 5", 17, 35, 10);
    private static readonly PatchFixture Panel306 = new(306, "SkyPanel", "Mode 3", 12, 114, 6);

    [Fact]
    public void WhatOneFixtureShowsIsLearntForEveryFixtureOfItsType()
    {
        var patch = new[] { Tube404, Tube405, Panel306 };
        Universe(17);
        Set(17, 27, 200);    // 404's third channel: something else, sitting still
        Set(17, 36, 64);     // 405's dimmer (its second channel), already at 25%
        var tracker = Tracker();
        Assert.Equal(LevelGap.NoDimmerChannel, tracker.Levels(patch, [404])[0].Gap);

        tracker.Expect(patch, [404], 0.5);
        Assert.True(tracker.Watching);
        Set(17, 27, 200);
        Set(17, 28, 0);
        Set(17, 26, 128);    // its second channel goes to 50%
        var lessons = Settle(tracker);
        Assert.NotNull(lessons);
        Assert.Contains("channel 2", Assert.Single(lessons).What);
        Assert.False(tracker.Watching);

        var levels = tracker.Levels(patch, [404, 405]);
        Assert.Equal(128 / 255.0, levels[0].Level!.Value, 3);
        Assert.Equal("learnt", levels[0].Source);
        Assert.Equal(64 / 255.0, levels[1].Level!.Value, 3);   // 405 was never touched
        Assert.Equal(new[] { 1 }, tracker.Learnt["Titan Tube|Mode 5|10"]);
    }

    [Fact]
    public void ASixteenBitDimmerIsItsCoarseChannel()
    {
        var patch = new[] { Panel306 };
        Universe(12);
        var tracker = Tracker();
        tracker.Expect(patch, [306], 0.8);
        Set(12, 114, 204);
        Set(12, 115, 77);    // the fine half lands wherever
        Assert.Contains("channel 1, 2", Assert.Single(Settle(tracker)!).What);
        Set(12, 115, 255);
        Assert.Equal(0.8, tracker.Levels(patch)[0].Level!.Value, 2);
    }

    [Fact]
    public void AnEffectRunningOnTheFixtureTeachesNothing()
    {
        var patch = new[] { Tube404 };
        Universe(17);
        var tracker = Tracker();
        tracker.Expect(patch, [404], 0.5);
        Set(17, 25, 128);
        Set(17, 28, 90);
        Set(17, 30, 40);
        tracker.Observe();
        _now += LevelTracker.WatchFor;
        Assert.Empty(tracker.Observe()!);
        Assert.Empty(tracker.Learnt);
    }

    [Fact]
    public void ALevelPassingThroughOnAFadeIsntTaken()
    {
        var patch = new[] { Tube404 };
        Universe(17);
        var tracker = Tracker();
        tracker.Expect(patch, [404], 0.5);
        Set(17, 30, 128);              // another channel fading up through 50%...
        Assert.Null(tracker.Observe());
        Set(17, 30, 180);              // ...and on past it
        Assert.Null(tracker.Observe());
        Set(17, 25, 127);              // the dimmer gets there and stays, but channel 6 has moved too
        tracker.Observe();
        _now += LevelTracker.WatchFor;
        Assert.Empty(tracker.Observe()!);
    }

    [Fact]
    public void NothingArrivingEndsTheWatchWhenTimesUp()
    {
        var patch = new[] { Tube404 };
        Universe(17);
        var tracker = Tracker();
        tracker.Expect(patch, [404], 0.5);
        Assert.Null(tracker.Observe());
        _now += LevelTracker.WatchFor;
        Assert.Empty(tracker.Observe()!);
        Assert.Null(tracker.Observe());
    }

    [Fact]
    public void FixturesOfATypeThatDisagreeTeachNothing()
    {
        var patch = new[] { Tube404, Tube405 };
        Universe(17);
        var tracker = Tracker();
        tracker.Expect(patch, [404, 405], 0.5);
        Set(17, 25, 128);    // 404's first channel
        Set(17, 37, 128);    // 405's third
        Assert.Empty(Settle(tracker)!);
        Assert.Empty(tracker.Learnt);
    }

    [Fact]
    public void ALineSentOnAnotherUniverseIsFound()
    {
        var patch = new[] { Tube404 };
        Universe(5);         // line 17 goes out as sACN universe 5; nothing on 17
        var tracker = Tracker();
        Assert.Equal(LevelGap.NoSacn, tracker.Levels(patch)[0].Gap);
        Assert.Equal(17, tracker.Levels(patch)[0].Universe);

        tracker.Expect(patch, [404], 0.5);
        Set(5, 25, 128);
        var lessons = Settle(tracker)!;
        Assert.Contains(lessons, l => l.What.Contains("line 17") && l.What.Contains("universe 5"));
        Assert.Equal(5, tracker.UniverseOf(17));
        Assert.Equal(128 / 255.0, tracker.Levels(patch)[0].Level!.Value, 3);
    }

    [Fact]
    public void ItsOwnUniverseWinsOverALookAlikeElsewhere()
    {
        var patch = new[] { Tube404 };
        Universe(17);
        Universe(3);
        var tracker = Tracker();
        tracker.Expect(patch, [404], 0.5);
        Set(17, 25, 128);
        Set(3, 26, 128);     // something at the same address on another universe, the same moment
        Settle(tracker);
        Assert.Equal(17, tracker.UniverseOf(17));
        Assert.Equal(new[] { 0 }, tracker.Learnt["Titan Tube|Mode 5|10"]);
    }

    [Fact]
    public void WhyThereIsNoLevel()
    {
        var dimmer = new PatchFixture(1, "Dimmer", null, 1, 10, 1);
        var known = new PatchFixture(2, "Spot", "Standard", 1, 20, 16, Intensity: [5]);
        Universe(1);
        Set(1, 10, 255);
        Set(1, 25, 51);      // fixture 2's sixth channel
        var levels = Tracker().Levels([dimmer, known, Tube404], [1, 2, 404, 999]);
        Assert.Equal((1.0, "dimmer"), (levels[0].Level!.Value, levels[0].Source));
        Assert.Equal((0.2, "personality"), (Math.Round(levels[1].Level!.Value, 2), levels[1].Source));
        Assert.Equal(LevelGap.NoSacn, levels[2].Gap);
        Assert.Equal(LevelGap.NotPatched, levels[3].Gap);
    }

    [Fact]
    public void WhatWasLearntOnThisRigWinsOverThePersonality()
    {
        var fixture = new PatchFixture(2, "Spot", "Standard", 1, 20, 16, Intensity: [5]);
        Universe(1);
        Set(1, 20, 100);
        var tracker = Tracker(new Dictionary<string, int[]> { ["Spot|Standard|16"] = [0] });
        Assert.Equal(100 / 255.0, tracker.Levels([fixture])[0].Level!.Value, 3);
        tracker.Forget();
        Assert.Equal("personality", tracker.Levels([fixture])[0].Source);
    }

    [Fact]
    public void ArrivedReadsTheChannelsThatWentToTheLevel()
    {
        Assert.Equal([2], LevelLearning.Arrived([0, 0, 10, 0], [0, 0, 128, 0], 128)!);
        Assert.Equal([0, 1, 2], LevelLearning.Arrived([0, 0, 0, 9], [255, 255, 255, 9], 255)!);   // RGB with no dimmer, to full
        Assert.Null(LevelLearning.Arrived([128, 0], [128, 0], 128));                                  // already there: can't tell
        Assert.Null(LevelLearning.Arrived([0, 0, 0], [128, 0, 60], 128));                              // something else moved, not next door
        Assert.Equal([1], LevelLearning.Arrived([40, 200], [40, 0], 0)!);                              // down to 0
    }
}
