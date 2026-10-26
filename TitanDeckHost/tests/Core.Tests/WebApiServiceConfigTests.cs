using TitanDeckHost.Core.Rdp;
using TitanDeckHost.Core.Titan;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class WebApiServiceConfigTests
{
    // The appSettings of a real Titan 19.2.104.5 WebAPIService.dll.config.
    private const string Shipped = """
        <?xml version="1.0" encoding="utf-8"?>
        <configuration>
          <startup>
            <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.7.2"/>
          </startup>
          <appSettings>
            <add key="webapi.enabled" value="true"/>
            <add key="webapi.port" value="4430"/>
            <add key="webapi.pre19Compatibility" value="false"/>
          </appSettings>
        </configuration>
        """;

    [Fact]
    public void ReadsTheSwitch()
    {
        Assert.False(WebApiServiceConfig.ReadPre19(Shipped));
        Assert.True(WebApiServiceConfig.ReadPre19(Shipped.Replace("value=\"false\"", "value=\"True\"")));
        Assert.Null(WebApiServiceConfig.ReadPre19("<configuration><appSettings><add key=\"webapi.enabled\" value=\"true\"/></appSettings></configuration>"));
        Assert.Null(WebApiServiceConfig.ReadPre19("not xml"));
    }

    [Fact]
    public void TurnsItOnAndLeavesEverythingElse()
    {
        var edited = WebApiServiceConfig.TurnOnPre19(Shipped);
        Assert.True(WebApiServiceConfig.ReadPre19(edited));
        Assert.Contains("<add key=\"webapi.port\" value=\"4430\"", edited);
        Assert.Contains("<add key=\"webapi.enabled\" value=\"true\"", edited);
        Assert.StartsWith("<?xml version=\"1.0\" encoding=\"utf-8\"?>", edited);
        Assert.Equal(Shipped.Split('\n').Length, edited.Split('\n').Length);   // no reformatting
    }

    [Fact]
    public void OnlyItsOwnFileName()
    {
        Assert.True(WebApiServiceConfig.IsServiceConfig(@"C:\Program Files\Avolites\WebAPI\19.2.104.5\WebAPIService.dll.config"));
        Assert.False(WebApiServiceConfig.IsServiceConfig(@"C:\Program Files\Avolites\Titan\19.2.104.5\Titan.dll.config"));
        Assert.False(TitanUiConfig.IsSettingsFileName(@"C:\Program Files\Avolites\WebAPI\19.2.104.5\WebAPIService.dll.config"));
    }

    [Fact]
    public void ChecklistOffersTheFixOnlyWhenItsOff()
    {
        var off = WebApiServiceConfig.Diagnose([false])!;
        Assert.Equal(CheckState.Problem, off.State);
        Assert.Equal(FixAction.EnableWebApiCompatibility, off.Fix);
        Assert.Contains("HTTP 500", off.Detail);
        Assert.Equal(CheckState.Ok, WebApiServiceConfig.Diagnose([true])!.State);
        Assert.Equal(CheckState.Problem, WebApiServiceConfig.Diagnose([true, false])!.State);
        Assert.Null(WebApiServiceConfig.Diagnose([]));   // not Titan 19
        Assert.Null(WebApiServiceConfig.Diagnose([null]));   // Titan 19.0/19.1: no switch to turn on
    }
}
