using System.Net;
using System.Net.Sockets;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Net;

namespace TitanDeckHost.Core.Tests;

public class ServiceHealthTests
{
    [Fact]
    public void AllWellSaysNothing()
    {
        Assert.Null(ServiceHealth.Diagnose(WindowsServiceState.Running, null, null));
    }

    [Fact]
    public void RunningInWindowsButNotAnsweringIsNotCalledNotRunning()
    {
        var trouble = ServiceHealth.Diagnose(WindowsServiceState.Running, "no answer in time", null)!;
        Assert.DoesNotContain("isn't running", trouble.Headline);
        Assert.Contains("is running", trouble.Headline);
        Assert.Contains("no answer in time", trouble.Detail);
        Assert.Contains("127.0.0.1:4432", trouble.Detail);
        Assert.Equal("Restart the service", trouble.Button);
        Assert.True(trouble.Restart);
        Assert.False(trouble.Reachable);
    }

    [Fact]
    public void StoppedOffersToStartIt()
    {
        var trouble = ServiceHealth.Diagnose(WindowsServiceState.Stopped, "nothing is listening there", null)!;
        Assert.Equal("The TitanDeck Host service isn't running", trouble.Headline);
        Assert.Equal("Start the service", trouble.Button);
        Assert.False(trouble.Restart);
    }

    [Fact]
    public void StartingAndNotInstalledHaveNoButton()
    {
        var starting = ServiceHealth.Diagnose(WindowsServiceState.Starting, "nothing is listening there", null)!;
        Assert.Null(starting.Button);
        Assert.False(starting.Severe);
        var missing = ServiceHealth.Diagnose(WindowsServiceState.NotInstalled, "nothing is listening there", null)!;
        Assert.Null(missing.Button);
        Assert.Contains("installer", missing.Detail);
    }

    [Fact]
    public void WhenWindowsWontSayTheReasonIsStillShown()
    {
        var trouble = ServiceHealth.Diagnose(WindowsServiceState.Unknown, "Windows blocked the connection", null)!;
        Assert.Contains("Windows blocked the connection", trouble.Detail);
        Assert.Equal("Start the service", trouble.Button);
    }

    [Fact]
    public void ASlowChecklistLeavesTheRestOfTheWindowWorking()
    {
        var trouble = ServiceHealth.Diagnose(WindowsServiceState.Running, null, "no answer in time")!;
        Assert.True(trouble.Reachable);
        Assert.False(trouble.Severe);
        Assert.Null(trouble.Button);
        Assert.Contains("no answer in time", trouble.Detail);
    }

    [Fact]
    public void FailuresAreSaidInPlainWords()
    {
        Assert.Equal("no answer in time", ServiceHealth.Describe(new TaskCanceledException()));
        Assert.Equal("it answered 500", ServiceHealth.Describe(new HttpRequestException("x", null, HttpStatusCode.InternalServerError)));
        Assert.Equal("nothing is listening there",
            ServiceHealth.Describe(new HttpRequestException("x", new SocketException((int)SocketError.ConnectionRefused))));
        Assert.Contains("different versions", ServiceHealth.Describe(new System.Text.Json.JsonException("bad")));
        Assert.Equal("the pipe broke", ServiceHealth.Describe(new IOException("the pipe broke.\r\n")));
    }

    [Fact]
    public void CallsOnThisPCNeverUseAProxy()
    {
        using var handler = LocalHttp.Handler();
        Assert.False(handler.UseProxy);
        using var client = LocalHttp.Client(TimeSpan.FromSeconds(3), new Uri("http://127.0.0.1:4432/local/"));
        Assert.Equal(TimeSpan.FromSeconds(3), client.Timeout);
    }

    [Fact]
    public async Task ALocalCallIgnoresAProxyThatIsSet()
    {
        // A proxy that would swallow the call: nothing listens on port 9.
        var before = HttpClient.DefaultProxy;
        HttpClient.DefaultProxy = new WebProxy("http://127.0.0.1:9");
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        try
        {
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;
            var serve = Task.Run(async () =>
            {
                using var socket = await listener.AcceptTcpClientAsync();
                var stream = socket.GetStream();
                var buffer = new byte[2048];
                _ = await stream.ReadAsync(buffer);
                await stream.WriteAsync("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"u8.ToArray());
            });
            using var client = LocalHttp.Client(TimeSpan.FromSeconds(5));
            Assert.Equal("ok", await client.GetStringAsync($"http://127.0.0.1:{port}/local/ping"));
            await serve;
        }
        finally
        {
            listener.Stop();
            HttpClient.DefaultProxy = before;
        }
    }
}
