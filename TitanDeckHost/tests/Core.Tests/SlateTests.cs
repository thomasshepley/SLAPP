using TitanDeckHost.Core.Slate;
using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class SlateTests
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 27, 8, 0, 0, TimeSpan.Zero);

    private static Dictionary<int, byte[]> Look(params (int Universe, int Address, byte Level)[] levels)
    {
        var look = new Dictionary<int, byte[]> { [1] = new byte[512] };
        foreach (var (universe, address, level) in levels)
        {
            if (!look.ContainsKey(universe)) look[universe] = new byte[512];
            look[universe][address - 1] = level;
        }
        return look;
    }

    /// <summary>Fixture 101 at 1.1: Dimmer, then Pan coarse/fine, then CTC.</summary>
    private static readonly List<PatchFixture> Patch =
    [
        new(101, "Spot", "Std", 1, 1, 4, [0], null,
            [new PersonalityAttribute("Dimmer", [0]), new PersonalityAttribute("Pan", [1, 2]), new PersonalityAttribute("CTC", [3])]),
    ];

    [Theory]
    [InlineData("112", "113")]
    [InlineData("112B", "113")]
    [InlineData("SC5", "SC6")]
    [InlineData("", "1")]
    public void SlatesCountUp(string slate, string next) => Assert.Equal(next, SlateNumbers.Next(slate));

    [Theory]
    [InlineData("112", "112A")]
    [InlineData("112A", "112B")]
    [InlineData("112H", "112J")]   // no I: it reads as 1
    [InlineData("112N", "112P")]   // no O: it reads as 0
    [InlineData("112Z", "112ZA")]
    public void LettersSkipIAndO(string slate, string next) => Assert.Equal(next, SlateNumbers.NextLetter(slate));

    [Fact]
    public void ChangesAreNamedByFixtureAndAttribute()
    {
        var before = Look((1, 1, 153), (1, 2, 128), (1, 3, 0), (1, 4, 0), (1, 40, 50));
        var after = Look((1, 1, 115), (1, 2, 128), (1, 3, 1), (1, 4, 255), (1, 40, 0));
        var changes = LookDiff.Compare(before, after, Patch);
        Assert.Equal(3, changes.Count);
        Assert.Equal(new LookChange(101, "Dimmer", 60, 45.1), changes[0]);
        Assert.Equal("CTC", changes[1].What);   // Pan's fine channel alone moving isn't a change
        Assert.Equal(new LookChange(null, "U1.40", 19.6, 0), changes[2]);
        Assert.Equal("101 Dimmer 60 → 45.1%", LookDiff.Describe(changes[0]));
        Assert.Empty(LookDiff.Compare(before, Look((1, 1, 154), (1, 2, 128), (1, 40, 50)), Patch));   // one step is noise
    }

    [Fact]
    public void ALookIsLoggedOnceItSettles()
    {
        var watcher = new LookWatcher(TimeSpan.FromSeconds(2));
        var start = Look((1, 1, 100));
        Assert.False(watcher.Sample(start, T0));
        watcher.Accept(start);
        var moved = Look((1, 1, 150));
        Assert.False(watcher.Sample(moved, T0.AddSeconds(1)), "still moving");
        Assert.False(watcher.Sample(moved, T0.AddSeconds(2)), "not still for long enough yet");
        Assert.True(watcher.Sample(moved, T0.AddSeconds(3.5)), "still for 2 s: a new look");
        watcher.Accept(moved);
        Assert.False(watcher.Sample(moved, T0.AddSeconds(6)), "nothing new since");
    }

    [Fact]
    public void ARunningEffectIsNeitherAChangeNorInTheWay()
    {
        var watcher = new LookWatcher(TimeSpan.FromSeconds(2));
        var t = T0;
        watcher.Sample(Look((1, 1, 100), (1, 20, 0)), t);
        watcher.Accept(Look((1, 1, 100), (1, 20, 0)));
        // Channel 20 chases; nothing else moves.
        for (var i = 1; i <= 10; i++)
        {
            t = t.AddSeconds(0.5);
            Assert.False(watcher.Sample(Look((1, 1, 100), (1, 20, (byte)(i % 2 * 200))), t), $"sample {i}");
        }
        Assert.Contains((1, 19), watcher.Moving);
        // Now the dimmer changes while the chase carries on: logged once it's still.
        for (var i = 1; i <= 8; i++)
        {
            t = t.AddSeconds(0.5);
            var logged = watcher.Sample(Look((1, 1, 180), (1, 20, (byte)(i % 2 * 200))), t);
            Assert.Equal(i >= 5, logged);
        }
    }

    [Fact]
    public void TheBookKeepsSlateTakeAndWhatChanged()
    {
        var book = new SlateBook("2026-10-27", SlateState.Start with { Slate = "111" });
        var first = book.NewSlate(null, Look((1, 1, 153)), Patch, T0);
        Assert.Equal(("112", 1, SlateEntry.NewSlate), (first.Slate, first.Take, first.Kind));
        Assert.Empty(first.Changes);
        var change = book.Change(Look((1, 1, 115)), Patch, T0.AddMinutes(5))!;
        Assert.Equal(("112", 1), (change.Slate, change.Take));
        Assert.Equal("Dimmer", Assert.Single(change.Changes).What);
        var take = book.Take(Look((1, 1, 115)), Patch, T0.AddMinutes(9));
        Assert.Equal(2, take.Take);
        var letter = book.Letter(Look((1, 1, 115)), Patch, T0.AddMinutes(20));
        Assert.Equal(("112A", 1), (letter.Slate, letter.Take));
        book.Set(night: true, fx: true);
        var typed = book.NewSlate("140b", Look((1, 1, 115)), Patch, T0.AddMinutes(30));
        Assert.Equal(("140B", 1, true, true), (typed.Slate, typed.Take, typed.Night, typed.Fx));
        Assert.Equal([1L, 2, 3, 4, 5], book.Entries.Select(e => e.Id));
        Assert.True(book.Note(2, "  gaffer asked for less on 101 "));
        Assert.Equal("gaffer asked for less on 101", book.Entries[1].Note);
        Assert.Equal(115, SlateBook.Decode(book.Entries[^1].Levels)[1][0]);
    }

    [Fact]
    public void PersonalitiesListEveryAttribute()
    {
        const string xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <Fixture Name="Test Spot" ShortName="Test Spot" Company="TitanDeck" Version="1">
              <Mode Name="Std" Channels="5">
                <Include>
                  <Attribute ID="Dimmer" ChannelOffset="1" />
                  <Attribute ID="Pan" ChannelOffset="2,3" />
                  <Attribute ID="Colour_Wheel" ChannelOffset="4" />
                  <Attribute ID="Strobe" ChannelOffset="5" />
                  <Attribute ID="Virtual" />
                </Include>
              </Mode>
            </Fixture>
            """;
        var mode = Assert.Single(TitanPersonality.Read(xml)!.Modes);
        Assert.Equal(["Dimmer", "Pan", "Colour Wheel", "Strobe"], mode.Attributes!.Select(a => a.Name));
        Assert.Equal([1, 2], mode.Attributes![1].Offsets);
    }
}
