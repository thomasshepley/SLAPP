using TitanDeckHost.Core.Pairing;

public class PairingTests
{
    private DateTimeOffset _now = new(2026, 10, 24, 12, 0, 0, TimeSpan.Zero);
    private PairingStore NewStore(string? path = null) => new(path, () => _now);

    [Fact]
    public void RightCodePairsOnceAndTheTokenAuthenticates()
    {
        var store = NewStore();
        var code = store.NewCode(TimeSpan.FromMinutes(5));
        Assert.Matches("^[0-9]{6}$", code);

        var result = store.Pair(code, "Tom's iPad");
        Assert.True(result.Success);
        Assert.NotNull(result.Token);
        Assert.Equal("Tom's iPad", store.Authenticate(result.Token)?.Name);
        Assert.Null(store.Authenticate("not-a-token"));
        Assert.Null(store.Authenticate(""));

        // The code is single use.
        Assert.False(store.Pair(code, "Another").Success);
        Assert.Null(store.CurrentCode);
    }

    [Fact]
    public void TokensAreStoredHashed()
    {
        var store = NewStore();
        var token = store.Pair(store.NewCode(TimeSpan.FromMinutes(5)), "iPad").Token!;
        Assert.DoesNotContain(store.Devices, d => d.TokenHash.Contains(token));
        Assert.Equal(PairingStore.Hash(token), store.Devices.Single().TokenHash);
    }

    [Fact]
    public void CodesExpire()
    {
        var store = NewStore();
        var code = store.NewCode(TimeSpan.FromMinutes(5));
        _now = _now.AddMinutes(6);
        Assert.Null(store.CurrentCode);
        Assert.False(store.Pair(code, "iPad").Success);
    }

    [Fact]
    public void TooManyWrongGuessesKillTheCode()
    {
        var store = NewStore();
        var code = store.NewCode(TimeSpan.FromMinutes(5));
        var wrong = code == "000000" ? "111111" : "000000";
        for (var i = 0; i < PairingStore.MaxAttemptsPerCode; i++) Assert.False(store.Pair(wrong, "x").Success);
        Assert.False(store.Pair(code, "iPad").Success);
    }

    [Fact]
    public void DevicesSurviveARestartAndCanBeRevoked()
    {
        var path = Path.Combine(Path.GetTempPath(), $"pairing-{Guid.NewGuid():N}.json");
        try
        {
            var first = NewStore(path);
            var result = first.Pair(first.NewCode(TimeSpan.FromMinutes(5)), "iPad");
            var reopened = NewStore(path);
            Assert.NotNull(reopened.Authenticate(result.Token));
            Assert.True(reopened.Revoke(result.Device!.Id));
            Assert.Null(NewStore(path).Authenticate(result.Token));
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void ADamagedFileJustMeansPairingAgain()
    {
        var path = Path.Combine(Path.GetTempPath(), $"pairing-{Guid.NewGuid():N}.json");
        File.WriteAllText(path, "{not json");
        try { Assert.Empty(NewStore(path).Devices); } finally { File.Delete(path); }
    }
}
