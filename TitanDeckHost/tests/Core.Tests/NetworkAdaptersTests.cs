using TitanDeckHost.Core.Net;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class NetworkAdaptersTests
{
    private static readonly AdapterInfo Show = new("{1}", "Ethernet 1", "Intel I210", ["10.0.0.5"], true);
    private static readonly AdapterInfo Internet = new("{4}", "Ethernet 4", "Realtek USB", ["192.168.1.20"], true);
    private static readonly AdapterInfo Unplugged = new("{2}", "Ethernet 2", "Intel I219", ["2.0.0.1"], false);
    private static readonly AdapterInfo[] All = [Show, Internet, Unplugged];

    [Fact]
    public void AutomaticIsEveryAdapter() => Assert.Equal((null, null), NetworkAdapters.Resolve(All, null, null));

    [Fact]
    public void AChosenAdapterIsUsed() => Assert.Equal((Show, null), NetworkAdapters.Resolve(All, "{1}", "Ethernet 1"));

    [Fact]
    public void ANewIdFromWindowsStillFindsItByName() =>
        Assert.Equal(Show, NetworkAdapters.Resolve(All, "{gone}", "ethernet 1").Adapter);

    [Fact]
    public void UnpluggedOrMissingFallsBackToEveryAdapterAndSaysWhy()
    {
        var (adapter, problem) = NetworkAdapters.Resolve(All, "{2}", "Ethernet 2");
        Assert.Null(adapter);
        Assert.Contains("Ethernet 2 isn't connected", problem);

        (adapter, problem) = NetworkAdapters.Resolve(All, "{9}", "Ethernet 9");
        Assert.Null(adapter);
        Assert.Contains("Ethernet 9 isn't there", problem);
    }

    [Fact]
    public void ReadsThisMachinesAdaptersWithoutLoopback() =>
        Assert.DoesNotContain(NetworkAdapters.Read(), a => a.Ipv4.Contains("127.0.0.1"));
}
