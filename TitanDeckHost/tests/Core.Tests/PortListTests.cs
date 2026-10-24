using TitanDeckHost.Core.Net;

public class PortListTests
{
    [Theory]
    [InlineData("3389", 3389, true)]
    [InlineData("3389,4430", 4430, true)]
    [InlineData(" 80 , 443 ", 443, true)]
    [InlineData("1000-5000", 4431, true)]
    [InlineData("1000 - 5000", 999, false)]
    [InlineData("*", 1, true)]
    [InlineData("", 3389, false)]
    [InlineData(null, 3389, false)]
    [InlineData("RPC", 3389, false)]
    [InlineData("33890", 3389, false)]
    public void Matches(string? ports, int port, bool expected) => Assert.Equal(expected, PortList.Contains(ports, port));
}
