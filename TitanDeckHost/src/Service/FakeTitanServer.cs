using System.Diagnostics;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Sacn;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// Fake Titan, run from the Host window: the WebAPI on 4430 (Titan's port, so
/// TitanDeck needs no changes), the desk's UI WebAPI on 4433 (which the desk
/// link passes on as 4434, as with real Titan), and the fixtures' levels as
/// sACN universe 1, which the Host's own sACN listener hears for live
/// intensity. The ports are only open while it runs, and it won't start
/// while something (real Titan) has them. Every call goes in the Titan log.
/// </summary>
public sealed class FakeTitanServer(TitanLog log, PatchReader patch, ILogger<FakeTitanServer> logger)
{
    public const int ApiPort = 4430;
    private static readonly Guid SacnSource = Guid.Parse("6d1b2c3a-0000-4000-8000-0000000fa4e0");
    private static readonly IPEndPoint SacnUniverse1 = new(new IPAddress(SacnPacket.MulticastGroup(1)), SacnPacket.Port);

    private readonly SemaphoreSlim oneAtATime = new(1, 1);
    private WebApplication? server;
    private FakeTitan? titan;
    private Timer? sacnTimer;
    private UdpClient? sacnOut;
    private byte sequence;
    private FakeTitanStartRequest settings = new(12, 20, true, true, 0);
    private string? problem;

    public FakeTitanStatusDto Status()
    {
        var running = server is not null && titan is not null;
        var ports = running ? (settings.Desk ? new[] { ApiPort, TitanUiConfig.UiPort } : [ApiPort]) : [];
        return new FakeTitanStatusDto(running, settings.Fixtures, settings.Playbacks, settings.Desk, settings.Sacn,
            settings.LatencyMs, problem, running ? titan!.StatusLine() : null, ports);
    }

    public async Task<FakeTitanStatusDto> Start(FakeTitanStartRequest request)
    {
        await oneAtATime.WaitAsync();
        try
        {
            await StopLocked();
            settings = request with
            {
                Fixtures = Math.Clamp(request.Fixtures, 1, 120),
                Playbacks = Math.Clamp(request.Playbacks, 1, 600),
                LatencyMs = Math.Clamp(request.LatencyMs, 0, 5000),
            };
            var wanted = settings.Desk ? new[] { ApiPort, TitanUiConfig.UiPort } : [ApiPort];
            var busy = Busy(wanted);
            if (busy.Count > 0)
            {
                problem = $"Port {string.Join(" and ", busy)} is in use: close Titan first (Fake Titan and Titan can't both run).";
                return Status();
            }
            titan = new FakeTitan(new FakeTitanOptions(settings.Fixtures, settings.Playbacks));
            var builder = WebApplication.CreateSlimBuilder();
            builder.Logging.ClearProviders();
            builder.WebHost.ConfigureKestrel(kestrel =>
            {
                foreach (var port in wanted) kestrel.ListenAnyIP(port);
            });
            var app = builder.Build();
            app.Run(Handle);
            try
            {
                await app.StartAsync();
            }
            catch (Exception error) when (error is IOException or SocketException or InvalidOperationException)
            {
                await app.DisposeAsync();
                titan = null;
                problem = $"Couldn't open port {string.Join(" / ", wanted)}: {error.Message}";
                return Status();
            }
            server = app;
            problem = null;
            if (settings.Sacn) StartSacn();
            patch.UseFake(titan.PatchReportCsv());
            log.Add("Fake Titan", "Host", "START", $"ports {string.Join(", ", wanted)}", "", 200, 0,
                $"started: {settings.Fixtures} fixtures, {settings.Playbacks} playbacks" +
                $"{(settings.Desk ? ", desk on 4433 (desk link 4434)" : "")}{(settings.Sacn ? ", sACN universe 1" : "")}" +
                $"{(settings.LatencyMs > 0 ? $", +{settings.LatencyMs} ms latency" : "")}", null, false, DateTimeOffset.Now);
            logger.LogInformation("Fake Titan started on {Ports}", string.Join(", ", wanted));
            return Status();
        }
        finally
        {
            oneAtATime.Release();
        }
    }

    public async Task<FakeTitanStatusDto> Stop()
    {
        await oneAtATime.WaitAsync();
        try
        {
            if (server is not null) log.Add("Fake Titan", "Host", "STOP", "", "", 200, 0, "stopped", null, false, DateTimeOffset.Now);
            await StopLocked();
            problem = null;
            return Status();
        }
        finally
        {
            oneAtATime.Release();
        }
    }

    /// <summary>As if the operator selected fixtures in Layouts: "3,4", "1-10", or empty.</summary>
    public string DeskSelect(string fixtures)
    {
        if (titan is not { } t) return "Fake Titan isn't running.";
        var note = t.DeskSelect(ParseFixtures(fixtures));
        log.Add("Fake Titan - desk (UI WebAPI)", "Host window", "SELECT", "Layouts", fixtures, 200, 0, note, t.StatusLine(), false, DateTimeOffset.Now);
        return note;
    }

    /// <summary>"3,4", "1-4, 9" or "1 thru 4" -> fixture numbers.</summary>
    public static IEnumerable<int> ParseFixtures(string text)
    {
        foreach (var part in text.Replace("thru", "-", StringComparison.OrdinalIgnoreCase).Split(',', ' ', ';'))
        {
            var range = part.Split('-', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            if (range.Length == 1 && int.TryParse(range[0], out var one)) yield return one;
            else if (range.Length == 2 && int.TryParse(range[0], out var from) && int.TryParse(range[1], out var to))
                for (int n = Math.Min(from, to); n <= Math.Max(from, to) && n - Math.Min(from, to) < 512; n++) yield return n;
        }
    }

    private async Task Handle(HttpContext http)
    {
        var t = titan;
        if (t is null)
        {
            http.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            return;
        }
        var watch = Stopwatch.StartNew();
        if (settings.LatencyMs > 0) await Task.Delay(settings.LatencyMs);
        var user = http.Connection.LocalPort == TitanUiConfig.UiPort ? FakeUser.Desk : FakeUser.Api;
        var path = http.Request.Path.Value ?? "/";
        var query = http.Request.QueryString.Value ?? "";
        FakeReply reply;
        if (HttpMethods.IsPost(http.Request.Method))
        {
            using var reader = new StreamReader(http.Request.Body, Encoding.UTF8);
            reply = t.Set(path, await reader.ReadToEndAsync());
        }
        else
        {
            reply = t.Handle(path, query, user);
        }
        var payload = reply.Body is null ? [] : Encoding.UTF8.GetBytes(reply.Body.ToJsonString());
        http.Response.StatusCode = reply.Status;
        http.Response.ContentType = "application/json";
        http.Response.ContentLength = payload.Length;
        await http.Response.Body.WriteAsync(payload);

        var poll = TitanLog.IsPoll(http.Request.Method, path);
        log.Add(user == FakeUser.Desk ? "Fake Titan - desk (UI WebAPI)" : "Fake Titan - WebAPI",
            http.Connection.RemoteIpAddress?.ToString() ?? "", http.Request.Method, path, Uri.UnescapeDataString(query.TrimStart('?')),
            reply.Status, (int)watch.ElapsedMilliseconds, reply.Note, poll || reply.Status != 200 ? null : t.StatusLine(),
            reply.Flagged || reply.Status is 404 or 400, DateTimeOffset.Now);
    }

    private void StartSacn()
    {
        try
        {
            sacnOut = new UdpClient(AddressFamily.InterNetwork) { MulticastLoopback = true };
            sacnOut.Client.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.MulticastTimeToLive, 1);
        }
        catch (SocketException error)
        {
            problem = "Couldn't send sACN: " + error.Message;
            return;
        }
        sacnTimer = new Timer(_ =>
        {
            if (titan is not { } t || sacnOut is not { } udp) return;
            try
            {
                udp.Send(SacnPacket.Build(1, t.Universe1(), sequence++, SacnSource, "Fake Titan"), SacnUniverse1);
            }
            catch (Exception error) when (error is SocketException or ObjectDisposedException)
            {
                // No network up just now: try again on the next tick.
            }
        }, null, TimeSpan.Zero, TimeSpan.FromMilliseconds(100));
    }

    private async Task StopLocked()
    {
        patch.UseFake(null);
        sacnTimer?.Dispose();
        sacnTimer = null;
        sacnOut?.Dispose();
        sacnOut = null;
        if (server is { } app)
        {
            server = null;
            try
            {
                using var giveUp = new CancellationTokenSource(TimeSpan.FromSeconds(3));
                await app.StopAsync(giveUp.Token);
            }
            finally
            {
                await app.DisposeAsync();
            }
        }
        titan = null;
    }

    private static List<int> Busy(IEnumerable<int> ports)
    {
        try
        {
            var listening = IPGlobalProperties.GetIPGlobalProperties().GetActiveTcpListeners().Select(e => e.Port).ToHashSet();
            return ports.Where(listening.Contains).ToList();
        }
        catch (NetworkInformationException)
        {
            return [];
        }
    }
}
