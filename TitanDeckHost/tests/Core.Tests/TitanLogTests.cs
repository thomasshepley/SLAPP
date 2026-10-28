using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class TitanLogTests
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 10, 0, 0, TimeSpan.Zero);

    [Fact]
    public void PollingIsCountedNotListed()
    {
        var log = new TitanLog();
        for (int i = 0; i < 50; i++)
            log.Add("TitanDeck - WebAPI", "10.0.0.9", "GET", "/titan/get/2/Command/CommandLineText", "", 200, 1, null, null, false, T0.AddSeconds(i));
        var cue = log.Add("TitanDeck - WebAPI", "10.0.0.9", "GET", "/titan/script/2/Playbacks/FirePlaybackAtLevel",
            "handle_userNumber=1", 200, 3, "playback 1 GO", "state", false, T0.AddSeconds(60));
        Assert.NotNull(cue);
        var (entries, polls) = log.Since(0);
        Assert.Equal(2, entries.Count);   // the first poll, then the GO
        Assert.Contains("counted", entries[0].Note);
        Assert.Equal(50, Assert.Single(polls).Count);
        // A poll whose answer changes is listed again.
        Assert.NotNull(log.Add("TitanDeck - WebAPI", "10.0.0.9", "GET", "/titan/get/2/Command/CommandLineText", "", 502, 1, null, null, false, T0));
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

    [Fact]
    public void CitpHandshakeRepeatsAreCountedButSelectionAndProblemsAreListed()
    {
        var log = new TitanLog();
        for (int round = 0; round < 5; round++)
        {
            log.Add("CITP", "2.0.0.200", "IN", "CAEX EnterShow", "", 200, 0, "\"Show Test\"", null, false, T0.AddSeconds(round));
            log.Add("CITP", "2.0.0.200", "IN", "CAEX FixtureListRequest", "", 200, 0, null, null, false, T0.AddSeconds(round));
            log.Add("CITP", "2.0.0.200", "OUT", "CAEX NACK", "", 200, 0, "refused: TitanDeck Host never sends Titan a patch", null, false, T0.AddSeconds(round));
        }
        var (entries, polls) = log.Since(0);
        Assert.Equal(3, entries.Count);
        Assert.All(entries, e => Assert.True(e.Routine));
        Assert.Equal(5, polls.Single(p => p.Path == "OUT CAEX NACK").Count);

        Assert.NotNull(log.Add("CITP", "2.0.0.200", "IN", "CAEX FixtureSelection", "", 200, 0, "901", null, false, T0));
        Assert.NotNull(log.Add("CITP", "2.0.0.200", "IN", "CAEX FixtureSelection", "", 200, 0, "902", null, false, T0));
        var lost = log.Add("CITP", "2.0.0.200", "IN", "TCP connection", "", 200, 0, "link lost", null, true, T0);
        Assert.NotNull(lost);
        Assert.False(lost!.Routine);
        Assert.NotNull(log.Add("CITP", "2.0.0.200", "IN", "TCP connection", "", 200, 0, "link lost", null, true, T0));
        // Calls from TitanDeck are never routine.
        Assert.False(log.Add("TitanDeck - WebAPI", "10.0.0.9", "GET", "/titan/script/2/Playbacks/FirePlaybackAtLevel", "", 200, 1, null, null, false, T0)!.Routine);
    }
}
