using TitanDeckHost.Core.Api;

namespace TitanDeckHost.Core.Tests;

public class SharedAnswerTests
{
    [Fact]
    public async Task EveryoneAskingAtOnceSharesOneReading()
    {
        var made = 0;
        using var release = new ManualResetEventSlim();
        var answer = new SharedAnswer<int>(() =>
        {
            release.Wait(TimeSpan.FromSeconds(5));
            return Interlocked.Increment(ref made);
        }, TimeSpan.FromSeconds(2));
        var asks = Enumerable.Range(0, 20).Select(_ => answer.Get()).ToList();
        release.Set();
        var answers = await Task.WhenAll(asks);
        Assert.All(answers, a => Assert.Equal(1, a));
        Assert.Equal(1, made);
    }

    [Fact]
    public async Task KeptForAMomentThenReadAgain()
    {
        var now = DateTimeOffset.UnixEpoch;
        var made = 0;
        var answer = new SharedAnswer<int>(() => ++made, TimeSpan.FromSeconds(2), () => now);
        Assert.Equal(1, await answer.Get());
        now += TimeSpan.FromSeconds(1.9);
        Assert.Equal(1, await answer.Get());
        now += TimeSpan.FromSeconds(0.2);
        Assert.Equal(2, await answer.Get());
    }

    [Fact]
    public async Task ForgottenWhenSomethingChanges()
    {
        var made = 0;
        var answer = new SharedAnswer<int>(() => ++made, TimeSpan.FromMinutes(1));
        Assert.Equal(1, await answer.Get());
        answer.Forget();
        Assert.Equal(2, await answer.Get());
    }

    [Fact]
    public async Task AReadingFromBeforeAChangeIsntKept()
    {
        var made = 0;
        using var started = new ManualResetEventSlim();
        using var release = new ManualResetEventSlim();
        var answer = new SharedAnswer<int>(() =>
        {
            var mine = Interlocked.Increment(ref made);
            if (mine == 1)
            {
                started.Set();
                release.Wait(TimeSpan.FromSeconds(5));
            }
            return mine;
        }, TimeSpan.FromMinutes(1));
        var before = answer.Get();
        Assert.True(started.Wait(TimeSpan.FromSeconds(5)));
        answer.Forget();   // a fix was applied while the old reading was under way
        var after = answer.Get();
        release.Set();
        Assert.Equal(1, await before);
        Assert.Equal(2, await after);
        Assert.Equal(2, await answer.Get());
    }

    [Fact]
    public async Task AFailedReadingIsTriedAgain()
    {
        var made = 0;
        var answer = new SharedAnswer<int>(() => ++made == 1 ? throw new InvalidOperationException("no") : made, TimeSpan.FromMinutes(1));
        await Assert.ThrowsAsync<InvalidOperationException>(() => answer.Get());
        Assert.Equal(2, await answer.Get());
    }
}
