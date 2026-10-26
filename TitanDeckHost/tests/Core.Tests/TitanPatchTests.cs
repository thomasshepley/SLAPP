using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class TitanPatchTests
{
    [Fact]
    public void ReadsACsvPatchReport()
    {
        const string csv = """
            Titan Report,25/10/2026
            Patch View
            User No.,Fixture,Mode,Address,Legend,Location
            1,Robe Spiider,"Mode 1, 35 DMX",1.36,Spiider 1,
            2,Generic Dimmer,Dimmer,2.1,,
            2.1,,,,cell,
            3,Robe Spiider,"Mode 1, 35 DMX",Unpatched,,
            1,Duplicate,,1.99,,
            """;
        var patch = TitanPatch.Parse(csv, "Patch.csv");
        Assert.Equal(2, patch.Count);
        Assert.Equal(new PatchFixture(1, "Robe Spiider", "Mode 1, 35 DMX", 1, 36, 35, null, "Spiider 1"), patch[0]);
        Assert.Equal((2, 2, 1), (patch[1].UserNumber, patch[1].Line, patch[1].Address));
        Assert.Null(patch[1].Channels);
    }

    [Fact]
    public void ReadsSemicolonsAndATableInHtml()
    {
        var semicolons = TitanPatch.Parse("User Number;Address;Fixture Type\n101;3:12;LED Par\n", "p.csv");
        Assert.Equal((101, 3, 12, "LED Par"), (semicolons[0].UserNumber, semicolons[0].Line, semicolons[0].Address, semicolons[0].Model));

        const string html = """
            <html><body><h1>Patch View</h1><table>
            <tr><th>User no.</th><th>Fixture</th><th>Mode</th><th>Address</th></tr>
            <tr><td>12</td><td>Martin &amp; Co MAC</td><td>Mode 4, 16 DMX</td><td><b>1.200</b></td></tr>
            </table></body></html>
            """;
        var fixture = Assert.Single(TitanPatch.Parse(html, "report.html"));
        Assert.Equal((12, "Martin & Co MAC", 1, 200, 16), (fixture.UserNumber, fixture.Model, fixture.Line, fixture.Address, fixture.Channels));
    }

    [Fact]
    public void ReadsXmlWithAttributesOrChildElements()
    {
        const string attributes = """<Report><Fixture UserNumber="7" Address="2.5" Mode="Std, 8 DMX" /></Report>""";
        Assert.Equal((7, 2, 5, 8), Single(attributes));
        const string children = """
            <Report><Patch><Row><UserNo>8</UserNo><Fixture>Par</Fixture><DmxAddress>A.10</DmxAddress></Row></Patch></Report>
            """;
        Assert.Equal((8, 1, 10, (int?)null), Single(children));

        static (int, int, int, int?) Single(string xml)
        {
            var f = Assert.Single(TitanPatch.Parse(xml, "r.xml"));
            return (f.UserNumber, f.Line, f.Address, f.Channels);
        }
    }

    [Theory]
    [InlineData("1.36", 1, 36)]
    [InlineData("12:512", 12, 512)]
    [InlineData("2/1", 2, 1)]
    [InlineData("B.7", 2, 7)]
    [InlineData("U3 40", 3, 40)]
    [InlineData("513", 2, 1)]
    [InlineData("1.36, 2.1", 1, 36)]
    public void ParsesAddresses(string text, int line, int address) =>
        Assert.Equal((line, address), TitanPatch.ParseAddress(text));

    [Theory]
    [InlineData("Unpatched")]
    [InlineData("")]
    [InlineData("1.513")]
    [InlineData("-")]
    public void LeavesOutWhatIsntAnAddress(string text) => Assert.Null(TitanPatch.ParseAddress(text));

    [Fact]
    public void AReportAndAPersonalityGiveTheDimmer()
    {
        const string personality = """
            <?xml version="1.0" encoding="utf-8"?>
            <Fixture Name="Test RGBD" ShortName="Test RGBD" Company="TitanDeck" Version="1">
              <Control>
                <Attribute ID="Dimmer" Name="Dimmer" Group="I" />
              </Control>
              <Mode Name="RGBD" Channels="4">
                <Include>
                  <Attribute ID="Red" ChannelOffset="1" />
                  <Attribute ID="Green" ChannelOffset="2" />
                  <Attribute ID="Blue" ChannelOffset="3" />
                  <Attribute ID="Dimmer" ChannelOffset="4" />
                </Include>
              </Mode>
            </Fixture>
            """;
        const string report = "Patch View\r\nUser No.,Fixture,Mode,Address,Legend\r\n"
            + "1,Test RGBD,\"RGBD, 4 DMX\",1.1,One\r\n"
            + "2,Test RGBD,\"RGBD, 4 DMX\",1.5,Two\r\n"
            + "3,Test RGBD,\"RGBD, 4 DMX\",1.9,Three\r\n";
        var library = new PersonalityLibrary([]);
        library.Add(TitanPersonality.Read(personality)!);
        var patch = library.Fill(TitanPatch.Parse(report, "report.csv"));
        Assert.Equal(3, patch.Count);
        Assert.Equal((1, 9, 4), (patch[2].Line, patch[2].Address, patch[2].Channels));
        Assert.Equal([3], patch[2].Intensity);
    }
}

public class TitanPersonalityTests
{
    private const string Spot = """
        ﻿<?xml version="1.0" encoding="utf-8"?>
        <Fixture Name="Test Spot 300" ShortName="Spot 300" Company="Testco" Version="3">
          <Control><Attribute ID="Dimmer" Name="Dimmer" Group="I" Size="2" /></Control>
          <Mode Name="Standard" Channels="21">
            <Include>
              <Attribute ID="Pan" ChannelOffset="1,2" />
              <Attribute ID="Dimmer" ChannelOffset="12,13" Wheel="1" />
            </Include>
          </Mode>
          <Mode Name="Basic" Channels="16">
            <Include><Attribute ID="Dimmer" ChannelOffset="7" /></Include>
          </Mode>
          <Mode Name="Pixels" Channels="78">
            <Include><Attribute ID="Dimmer" Wheel="1" /></Include>
            <Cells>
              <Master><Attribute ID="Master_Dimmer" ChannelOffset="12,13" /></Master>
              <Cell ID="Cell1" ChannelOffset="22"><Attribute ID="Red" ChannelOffset="1" /></Cell>
            </Cells>
          </Mode>
          <Mode Name="R,G,B" Channels="3">
            <Include>
              <Attribute ID="Dimmer" Wheel="1" />
              <Attribute ID="Red" ChannelOffset="1" VirtualControl="Dimmer" />
              <Attribute ID="Green" ChannelOffset="2" VirtualControl="Dimmer" />
              <Attribute ID="Blue" ChannelOffset="3" VirtualControl="Dimmer" />
            </Include>
          </Mode>
        </Fixture>
        """;

    [Fact]
    public void FindsTheDimmerInEachMode()
    {
        var spot = TitanPersonality.Read(Spot)!;
        Assert.Equal(("Test Spot 300", "Spot 300", "Testco"), (spot.Name, spot.ShortName, spot.Company));
        Assert.Equal([11, 12], spot.Modes[0].Intensity);      // 1-based "12,13": coarse then fine
        Assert.Equal([6], spot.Modes[1].Intensity);
        Assert.Equal([11, 12], spot.Modes[2].Intensity);      // virtual Dimmer: the Master_Dimmer
        Assert.Equal([0, 1, 2], spot.Modes[3].Intensity);     // no dimmer channel: the colours
        Assert.Equal(21, spot.Modes[0].Channels);
    }

    [Fact]
    public void MatchesReportNamesAndModes()
    {
        var spot = TitanPersonality.Read(Spot)!;
        Assert.True(spot.Matches("Test Spot 300"));
        Assert.True(spot.Matches("Spot 300"));
        Assert.True(spot.Matches("Testco Spot 300"));
        Assert.False(spot.Matches("Spot 3000"));
        Assert.Equal("Standard", spot.Mode("Standard, 21 DMX", 21)?.Name);
        Assert.Equal("Basic", spot.Mode("Basic", null)?.Name);
        Assert.Equal("Basic", spot.Mode("Mode 2, 16 DMX", 16)?.Name);   // name unknown: the only 16-channel mode
        Assert.Null(spot.Mode("Mystery", null));
    }

    [Fact]
    public void IsNullForAnythingElse()
    {
        Assert.Null(TitanPersonality.Read("<Show />"));
        Assert.Null(TitanPersonality.Read("not xml"));
    }

    [Fact]
    public void TheLibraryFindsPersonalitiesOnDiskAndUserFilesWin()
    {
        var root = Directory.CreateTempSubdirectory("titandeck-d4-");
        try
        {
            var user = Directory.CreateDirectory(Path.Combine(root.FullName, "user")).FullName;
            var factory = Directory.CreateDirectory(Path.Combine(root.FullName, "factory", "Testco")).FullName;
            File.WriteAllText(Path.Combine(factory, "spot.d4"), Spot);
            File.WriteAllText(Path.Combine(user, "spot-edited.d4"), Spot.Replace("ChannelOffset=\"7\"", "ChannelOffset=\"9\""));
            File.WriteAllText(Path.Combine(factory, "broken.d4"), "<Fixture");
            var library = new PersonalityLibrary([user, Path.Combine(root.FullName, "factory"), Path.Combine(root.FullName, "missing")]);
            Assert.Equal(2, library.Count);
            var filled = library.Fill([
                new PatchFixture(1, "Spot 300", "Basic, 16 DMX", 1, 1, 16),
                new PatchFixture(2, "Unknown thing", null, 1, 20),
            ]);
            Assert.Equal([8], filled[0].Intensity);
            Assert.Null(filled[1].Intensity);
        }
        finally
        {
            root.Delete(recursive: true);
        }
    }
}
