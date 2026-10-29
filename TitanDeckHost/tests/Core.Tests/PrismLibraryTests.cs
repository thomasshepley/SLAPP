using TitanDeckHost.Core.Prism;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class PrismLibraryTests
{
    [Fact]
    public void ReadsBanksAndClipsFromJson()
    {
        var banks = PrismLibrary.Parse("""
            { "project": "Tour", "banks": [
                { "name": "Fire", "elements": [
                    { "name": "Big fire", "media": { "path": "D:\\Media\\fire_big.mov" } },
                    { "media": { "path": "D:\\Media\\fire_small.mp4" } } ] },
                { "name": "Police", "elements": [
                    { "name": "Blue lights", "path": "D:\\Media\\police.mov" } ] } ] }
            """)!;
        Assert.Equal(["Fire", "Police"], banks.Select(b => b.Name));
        Assert.Equal([0, 1], banks.Select(b => b.Index));
        Assert.Equal(["Big fire", "fire_small"], banks[0].Clips.Select(c => c.Name));
        Assert.Equal(@"D:\Media\fire_small.mp4", banks[0].Clips[1].Path);
        Assert.Equal("Blue lights", Assert.Single(banks[1].Clips).Name);
    }

    [Fact]
    public void FollowsMediaIdsAndPrefersBanksOverTheMediaList()
    {
        var banks = PrismLibrary.Parse("""
            { "media": [ { "id": "m1", "file": "C:/Prism/Media/candle.mov" },
                         { "id": "m2", "file": "C:/Prism/Media/tv.mp4" } ],
              "Banks": [ { "Name": "Bank A", "Items": [ { "slot": 2, "mediaId": "m1" }, { "slot": 1, "mediaId": "m2" } ] } ] }
            """)!;
        var bank = Assert.Single(banks);
        Assert.Equal("Bank A", bank.Name);
        Assert.Equal(["tv", "candle"], bank.Clips.Select(c => c.Name));
    }

    [Fact]
    public void ReadsXmlIncludingOneClipBanks()
    {
        var banks = PrismLibrary.Parse("""
            <?xml version="1.0"?>
            <Project>
              <Bank Name="Lightning">
                <Element Name="Strike"><Source>E:\clips\strike.mov</Source></Element>
                <Element Name="Rumble"><Source>E:\clips\rumble.mov</Source></Element>
              </Bank>
              <Bank Name="TV">
                <Element Name="Flicker" Path="E:\clips\tv.png" />
              </Bank>
            </Project>
            """)!;
        Assert.Equal(["Lightning", "TV"], banks.Select(b => b.Name));
        Assert.Equal(["Strike", "Rumble"], banks[0].Clips.Select(c => c.Name));
        Assert.Equal(@"E:\clips\rumble.mov", banks[0].Clips[1].Path);
        Assert.Equal("Flicker", Assert.Single(banks[1].Clips).Name);
    }

    [Fact]
    public void IgnoresFilesWithoutMediaOrThatArentJsonOrXml()
    {
        Assert.Null(PrismLibrary.Parse("not a project"));
        Assert.Empty(PrismLibrary.Parse("""{ "settings": { "uploadFolder": "D:\\Upload" }, "recent": ["a.prism"] }""")!);
        Assert.Null(PrismLibrary.Parse("{ broken"));
    }

    [Fact]
    public void ReadsAFolderOfMediaAsBanks()
    {
        var banks = PrismLibrary.FromFolder([
            @"002 Police\001 Blue.mov", @"001 Fire\002 Small.mov", @"001 Fire\001 Big.mov",
            @"001 Fire\notes.txt", "loose.mp4",
        ]);
        Assert.Equal(["001 Fire", "002 Police", "(top folder)"], banks.Select(b => b.Name));
        Assert.All(banks, b => Assert.Null(b.Number));
        var named = PrismLibrary.FromFolder([@"002 Police\001 Blue.mov", @"001 Fire\002 Small.mov", @"001 Fire\001 Big.mov"]);
        Assert.Equal([1, 2], named.Select(b => b.Number));
        Assert.Equal(["001 Big", "002 Small"], named[0].Clips.Select(c => c.Name));
        Assert.Equal([1, 2], named[0].Clips.Select(c => c.Number));
        Assert.Equal("001 Fire/001 Big.mov", named[0].Clips[0].Path);
    }

    [Fact]
    public void KnowsMediaFiles()
    {
        Assert.True(PrismLibrary.IsMedia(@"C:\a\b.MOV"));
        Assert.True(PrismLibrary.IsMedia("x.png"));
        Assert.False(PrismLibrary.IsMedia("x.wav"));
        Assert.False(PrismLibrary.IsMedia("<b>.mov"));
        Assert.Equal(12, PrismLibrary.Leading("012 Fire"));
        Assert.Null(PrismLibrary.Leading("Fire"));
    }
}
