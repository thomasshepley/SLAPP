using TitanDeckHost.Core.Rdp;
using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class DeskLinkTests
{
    // Shaped like Titan's shipped config: the keys are there, switched off.
    private const string Shipped = """
        <?xml version="1.0" encoding="utf-8"?>
        <configuration>
          <startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.7.2" /></startup>
          <appSettings>
            <add key="some.other" value="42" />
            <add key="webapi.enabled" value="false" />
            <add key="webapi.port" value="4431" />
          </appSettings>
        </configuration>
        """;

    [Fact]
    public void ReadsTitansSwitch()
    {
        Assert.Equal(new TitanUiConfig.State(false, 4431), TitanUiConfig.Read(Shipped));
        Assert.Null(TitanUiConfig.Read("<configuration><appSettings><add key=\"x\" value=\"1\"/></appSettings></configuration>"));
        Assert.Null(TitanUiConfig.Read("not xml"));
        Assert.Null(TitanUiConfig.Read("<html/>"));
        var noPort = TitanUiConfig.Read("<configuration><appSettings><add key=\"webapi.enabled\" value=\"True\"/></appSettings></configuration>");
        Assert.Equal(new TitanUiConfig.State(true, null), noPort);
        Assert.Equal(4431, noPort!.EffectivePort);
    }

    [Fact]
    public void TurnsItOnAtTheDeskPortAndLeavesTheRestAlone()
    {
        var edited = TitanUiConfig.Enable(Shipped);
        Assert.Equal(new TitanUiConfig.State(true, TitanUiConfig.UiPort), TitanUiConfig.Read(edited));
        Assert.Contains("<add key=\"some.other\" value=\"42\" />", edited);
        Assert.Contains("sku=\".NETFramework,Version=v4.7.2\"", edited);
        Assert.StartsWith("<?xml version=\"1.0\" encoding=\"utf-8\"?>", edited);
        Assert.Equal(edited, TitanUiConfig.Enable(edited));   // twice is the same as once

        var bare = TitanUiConfig.Enable("<configuration></configuration>");
        Assert.Equal(new TitanUiConfig.State(true, TitanUiConfig.UiPort), TitanUiConfig.Read(bare));
    }

    [Fact]
    public void ChecklistSaysWhatToDo()
    {
        var off = TitanUiConfig.Diagnose([new(false, 4431)], uiAnswers: false, titanRunning: true);
        Assert.Equal(CheckState.Warning, off.State);
        Assert.Equal(FixAction.EnableDeskLink, off.Fix);

        var clash = TitanUiConfig.Diagnose([new(true, 4431)], false, true);
        Assert.Equal(CheckState.Problem, clash.State);
        Assert.Equal(FixAction.EnableDeskLink, clash.Fix);

        var restart = TitanUiConfig.Diagnose([new(true, TitanUiConfig.UiPort)], false, true);
        Assert.Contains("Restart Titan", restart.Detail);
        Assert.Equal(FixAction.None, restart.Fix);

        Assert.Equal(CheckState.Ok, TitanUiConfig.Diagnose([new(true, TitanUiConfig.UiPort)], true, true).State);
        Assert.Equal(FixAction.None, TitanUiConfig.Diagnose([], false, true).Fix);
        Assert.Equal("desklink", off.Id);
    }

    [Fact]
    public void AWebApiAlreadyInTitansUiOn4430IsLeftAlone()
    {
        IReadOnlyList<TitanUiConfig.State> on4430 = [new(true, TitanUiConfig.ApiPort)];
        Assert.True(TitanUiConfig.UiIsOnApiPort(on4430));
        Assert.Equal(TitanUiConfig.ApiPort, TitanUiConfig.TargetPort(on4430));   // the desk link uses 4430

        var check = TitanUiConfig.Diagnose(on4430, uiAnswers: true, titanRunning: true);
        Assert.Equal(CheckState.Ok, check.State);
        Assert.Equal(FixAction.None, check.Fix);   // never offer to move the WebAPI TitanDeck uses
        Assert.Contains("Nothing to change", check.Detail);

        var quiet = TitanUiConfig.Diagnose(on4430, uiAnswers: false, titanRunning: true);
        Assert.Equal(CheckState.Warning, quiet.State);
        Assert.Equal(FixAction.None, quiet.Fix);

        // Otherwise it's the separate 4433 one, as before.
        Assert.Equal(TitanUiConfig.UiPort, TitanUiConfig.TargetPort([new(false, 4431)]));
        Assert.Equal(TitanUiConfig.UiPort, TitanUiConfig.TargetPort([new(false, TitanUiConfig.ApiPort)]));   // off at 4430 doesn't count
    }

    [Theory]
    [InlineData("/titan/script/2/Selection/Context/Global/GetAllSelectedFixtureIds", true)]
    [InlineData("/titan/script/2/Command/AppendStringAndPreview", true)]
    [InlineData("/titan/get/2/Command/CommandLineText", true)]
    [InlineData("/titan/script/2/Programmer/Editor/Fixtures/FlashOut", true)]
    [InlineData("/titan/script/2/Playbacks/FirePlaybackAtLevel", true)]
    [InlineData("/titan/handles/Fixtures", true)]
    [InlineData("/titan/get/System/SoftwareVersion", true)]
    [InlineData("/titan/script/2/Patch/Repatch/SetDmxAddressesFromSelectedFixture", false)]
    [InlineData("/titan/get/2/Patch/CurrentDmxAssignment", false)]
    [InlineData("/titan/script/2/Fixtures/PatchFixtures", false)]
    [InlineData("/titan/script/2/Programmer/Editor/Fixtures/Patch/SetLimitToCurrent", false)]
    [InlineData("/titan/script/2/Selection/Context/Patch/GetSelectedFixtureIds", false)]
    [InlineData("/titan/script/2/Show/NewShow", false)]
    [InlineData("/titan/script/2/Dmx/FreezeDmx", false)]
    [InlineData("/titan/get/System/SoftwareVersionX", false)]
    public void ProxyOnlyPassesTitanDecksCalls(string path, bool allowed) =>
        Assert.Equal(allowed, TitanUiConfig.ProxyAllows(path));
}
