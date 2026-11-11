using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class DeskTypeQueueTests
{
    private static readonly TimeSpan Short = TimeSpan.FromMilliseconds(100);
    private static readonly TimeSpan Long = TimeSpan.FromSeconds(5);

    [Fact]
    public async Task ALineIsAnsweredOnlyWhenTheWindowHasTypedIt()
    {
        var queue = new DeskTypeQueue();
        var asked = queue.Enqueue(["1", "0", "1", "enter"], Long);
        var jobs = await queue.Next(Long, default);
        var job = Assert.Single(jobs);
        Assert.Equal(["1", "0", "1", "enter"], job.Keys);
        Assert.False(asked.IsCompleted, "not typed yet, so not answered yet");
        queue.Done(job.Id, typed: true, problem: null);
        Assert.Equal(new DeskTypeResult(true, null), await asked);
    }

    [Fact]
    public async Task TheWindowsReasonComesBack()
    {
        var queue = new DeskTypeQueue();
        var asked = queue.Enqueue(["@", "5", "0", "enter"], Long);
        var job = Assert.Single(await queue.Next(Long, default));
        queue.Done(job.Id, typed: false, problem: "Titan isn't the window in front");
        var result = await asked;
        Assert.False(result.Typed);
        Assert.Equal("Titan isn't the window in front", result.Problem);
    }

    [Fact]
    public async Task ALineThatWaitedTooLongIsRefusedNotTypedLate()
    {
        var now = DateTimeOffset.UtcNow;
        var queue = new DeskTypeQueue(() => now);
        var asked = queue.Enqueue(["1", "enter"], Long);
        now += TimeSpan.FromSeconds(3);
        Assert.Empty(await queue.Next(Short, default));
        var result = await asked;
        Assert.False(result.Typed);
        Assert.Contains("too long", result.Problem);
    }

    [Fact]
    public async Task ALineNobodyPicksUpIsTakenBack()
    {
        var queue = new DeskTypeQueue();
        var result = await queue.Enqueue(["1", "enter"], Short);
        Assert.False(result.Typed);
        Assert.Contains("didn't pick the keys up", result.Problem);
        Assert.Empty(await queue.Next(Short, default));   // and can't be typed afterwards
    }

    [Fact]
    public async Task ALineTheWindowNeverConfirmsSaysSo()
    {
        var queue = new DeskTypeQueue();
        var asked = queue.Enqueue(["1", "enter"], TimeSpan.FromMilliseconds(300));
        Assert.Single(await queue.Next(Long, default));
        var result = await asked;
        Assert.False(result.Typed);
        Assert.Contains("didn't confirm", result.Problem);
    }

    [Fact]
    public async Task OnlyTheNewestOfBackToBackLevelsIsTyped()
    {
        var queue = new DeskTypeQueue();
        var first = queue.Enqueue(["@", "6", "4", "enter"], Long);
        var selection = queue.Enqueue(["1", "0", "1", "enter"], Long);
        var second = queue.Enqueue(["@", "5", "6", "enter"], Long);
        var third = queue.Enqueue(["@", "4", "8", "enter"], Long);
        var jobs = await queue.Next(Long, default);
        Assert.Equal(3, jobs.Count);   // the first level stays: a selection came after it
        Assert.Equal(["@", "6", "4", "enter"], jobs[0].Keys);
        Assert.Equal(["1", "0", "1", "enter"], jobs[1].Keys);
        Assert.Equal(["@", "4", "8", "enter"], jobs[2].Keys);
        Assert.True((await second).Typed, "superseded by the newer level, not a failure");
        foreach (var job in jobs) queue.Done(job.Id, true, null);
        Assert.True((await first).Typed);
        Assert.True((await selection).Typed);
        Assert.True((await third).Typed);
    }

    [Fact]
    public async Task KnowsWhenTheWindowIsListening()
    {
        var queue = new DeskTypeQueue();
        Assert.False(queue.WindowListening);
        var waiting = queue.Next(Long, default);
        Assert.True(queue.WindowListening);
        _ = queue.Enqueue(["1", "enter"], Long);
        await waiting;
        Assert.True(queue.WindowListening, "between polls");
    }

    [Fact]
    public void KnowsTitansOwnWindows()
    {
        Assert.True(DeskKeys.IsTitanProcess("Titan"));
        Assert.True(DeskKeys.IsTitanProcess("TitanGo"));
        Assert.False(DeskKeys.IsTitanProcess("TitanDeckHost"));
        Assert.False(DeskKeys.IsTitanProcess("TitanDeckHost.Service"));
        Assert.False(DeskKeys.IsTitanProcess("explorer"));
        Assert.True(DeskKeys.IsLevelOnly(["@", "5", "0", "enter"]));
        Assert.False(DeskKeys.IsLevelOnly(["1", "@", "5", "0", "enter"]));
    }
}
