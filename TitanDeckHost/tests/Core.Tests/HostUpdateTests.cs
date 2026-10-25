using System.Security.Cryptography;
using System.Text;
using TitanDeckHost.Core.Update;
using Xunit;

namespace TitanDeckHost.Core.Tests;

public class HostUpdateTests
{
    // Shaped like GitHub's GET /repos/{owner}/{repo}/releases.
    private const string Releases = """
        [
          {"tag_name":"freerdpkit-3.32.2","draft":false,"prerelease":true,"assets":[
            {"name":"FreeRDPKit.zip","size":10,"digest":"sha256:aa","browser_download_url":"https://github.com/thomasshepley/SLAPP/releases/download/freerdpkit-3.32.2/FreeRDPKit.zip"}]},
          {"tag_name":"host-v0.4.0","draft":false,"prerelease":true,"published_at":"2026-10-24T22:35:01Z",
           "body":"## 0.4.0 - Desk link\n\n- Something\r\n\n**Install:** download the Setup .exe below",
           "assets":[{"name":"TitanDeckHost-Setup-0.4.0.exe","size":79553907,
             "digest":"sha256:3CCD30EFE7E96FF2E4ED277C147AA553AB7E338C320F8F2C373FDCA391334D5E",
             "browser_download_url":"https://github.com/thomasshepley/SLAPP/releases/download/host-v0.4.0/TitanDeckHost-Setup-0.4.0.exe"}]},
          {"tag_name":"host-v0.10.0","draft":true,"assets":[{"name":"TitanDeckHost-Setup-0.10.0.exe","size":1,
             "browser_download_url":"https://github.com/thomasshepley/SLAPP/releases/download/host-v0.10.0/TitanDeckHost-Setup-0.10.0.exe"}]},
          {"tag_name":"host-v0.9.0","draft":false,"assets":[{"name":"TitanDeckHost-Setup-0.9.0.exe","size":1,
             "browser_download_url":"https://evil.example.com/TitanDeckHost-Setup-0.9.0.exe"}]},
          {"tag_name":"host-v0.3.0","draft":false,"assets":[{"name":"TitanDeckHost-Setup-0.3.0.exe","size":5,
             "browser_download_url":"https://github.com/thomasshepley/SLAPP/releases/download/host-v0.3.0/TitanDeckHost-Setup-0.3.0.exe"}]}
        ]
        """;

    [Fact]
    public void PicksTheNewestOfficialHostRelease()
    {
        var newest = HostUpdate.Newest(Releases);
        Assert.NotNull(newest);
        Assert.Equal(new Version(0, 4, 0), newest.Version);   // not the draft, not the off-site one
        Assert.Equal("TitanDeckHost-Setup-0.4.0.exe", newest.AssetName);
        Assert.Equal(79553907, newest.Size);
        Assert.Equal("3ccd30efe7e96ff2e4ed277c147aa553ab7e338c320f8f2c373fdca391334d5e", newest.Sha256);
        Assert.Equal("## 0.4.0 - Desk link\n\n- Something", newest.Notes);
        Assert.NotNull(newest.Published);
        Assert.Null(HostUpdate.Newest("[]"));
        Assert.Null(HostUpdate.Newest("{\"message\":\"rate limited\"}"));
    }

    [Fact]
    public void ComparesVersionsNumerically()
    {
        var release = HostUpdate.Newest(Releases)!;
        Assert.True(HostUpdate.IsNewer(release, "0.3.0"));
        Assert.False(HostUpdate.IsNewer(release, "0.4.0"));
        Assert.False(HostUpdate.IsNewer(release, "0.10.0"));   // 0.10 is newer than 0.4, not older
        Assert.False(HostUpdate.IsNewer(release, "0.4.0+abc123"));
    }

    [Fact]
    public void OnlyThisRepositorysDownloadsAndMatchingFiles()
    {
        Assert.True(HostUpdate.IsOfficial("https://github.com/thomasshepley/SLAPP/releases/download/host-v0.5.0/TitanDeckHost-Setup-0.5.0.exe"));
        Assert.False(HostUpdate.IsOfficial("http://github.com/thomasshepley/SLAPP/releases/download/host-v0.5.0/x.exe"));
        Assert.False(HostUpdate.IsOfficial("https://github.com/someone/SLAPP/releases/download/host-v0.5.0/x.exe"));
        var bytes = Encoding.UTF8.GetBytes("installer");
        var sha = Convert.ToHexString(SHA256.HashData(bytes));
        Assert.True(HostUpdate.Matches(new MemoryStream(bytes), sha));
        Assert.False(HostUpdate.Matches(new MemoryStream(bytes), new string('0', 64)));
    }
}
