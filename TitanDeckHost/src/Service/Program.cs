using System.Net;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Files;
using TitanDeckHost.Core.Pairing;
using TitanDeckHost.Core.Rdp;
using TitanDeckHost.Core.Sacn;
using TitanDeckHost.Core.Titan;
using TitanDeckHost.Core.Update;
using TitanDeckHost.Service;

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = AppContext.BaseDirectory,
});
builder.Host.UseWindowsService(options => options.ServiceName = "TitanDeckHost");
// Stops promptly (the installer waits for it before replacing files), and one
// background job failing is logged rather than stopping the whole service.
builder.Services.Configure<HostOptions>(options =>
{
    options.ShutdownTimeout = TimeSpan.FromSeconds(5);
    options.BackgroundServiceExceptionBehavior = BackgroundServiceExceptionBehavior.Ignore;
});
if (OperatingSystem.IsWindows()) builder.Logging.AddEventLog(settings => settings.SourceName = "TitanDeck Host");
builder.WebHost.ConfigureKestrel(kestrel =>
{
    kestrel.ListenAnyIP(Protocol.NetworkPort);
    kestrel.Listen(IPAddress.Loopback, Protocol.LocalPort);
    kestrel.ListenAnyIP(TitanUiConfig.ProxyPort);   // desk link: Titan's UI WebAPI, passed through
    kestrel.ListenAnyIP(TitanUiConfig.PassThroughPort);   // Titan's WebAPI through the Host, for the Titan log
    kestrel.Limits.MaxRequestBodySize = null;   // photos and videos from the iPad
});

var paths = new HostPaths();
builder.Services.AddSingleton(paths);
builder.Services.AddSingleton(new PairingStore(paths.PairingFile));
builder.Services.AddSingleton<WindowsProbe>();
// The status (firewall rules, running programs, registry) is slow to read on
// a busy PC: one reading at a time, shared by everyone asking, kept 2 s.
builder.Services.AddSingleton(services => new SharedAnswer<StatusResponse>(
    () => Status(services.GetRequiredService<WindowsProbe>(), services.GetRequiredService<DeskLink>(), paths,
        services.GetRequiredService<HostModeStore>(), services.GetRequiredService<ILogger<WindowsProbe>>()),
    TimeSpan.FromSeconds(2)));
builder.Services.AddSingleton<TitanLog>();
builder.Services.AddSingleton<DeskLink>();
builder.Services.AddSingleton<HostModeStore>();
builder.Services.AddSingleton<PatchReader>();
builder.Services.AddSingleton<HostUpdater>();
builder.Services.AddHostedService(services => services.GetRequiredService<HostUpdater>());
builder.Services.AddSingleton<Fixer>();
builder.Services.AddSingleton<NetworkChoice>();
builder.Services.AddHostedService<Advertiser>();
builder.Services.AddSingleton<DmxUniverses>();
builder.Services.AddSingleton<SacnListener>();
builder.Services.AddHostedService(services => services.GetRequiredService<SacnListener>());
builder.Services.AddSingleton(new DeskTypeQueue());
builder.Services.AddSingleton<LevelService>();
builder.Services.AddSingleton<SlateService>();
builder.Services.AddHostedService(services => services.GetRequiredService<SlateService>());
builder.Services.AddSingleton<CitpService>();
builder.Services.AddSingleton<TitanActions>();
builder.Services.AddSingleton<PrismMediaFinder>();
builder.Services.AddHostedService(services => services.GetRequiredService<CitpService>());

var app = builder.Build();
var pairing = app.Services.GetRequiredService<PairingStore>();
app.Services.GetRequiredService<PatchReader>().Warm();

// --- The iPad's API (port 4431). Everything but hello and pair needs a token. ---

var network = app.MapGroup("/api/v1").AddEndpointFilter(async (context, next) =>
{
    var http = context.HttpContext;
    if (http.Connection.LocalPort != Protocol.NetworkPort) return Results.NotFound();
    // Only these two exact paths work unpaired.
    var path = http.Request.Path.Value ?? "";
    if (path.Equals("/api/v1/hello", StringComparison.OrdinalIgnoreCase)
        || path.Equals("/api/v1/pair", StringComparison.OrdinalIgnoreCase)) return await next(context);
    var header = http.Request.Headers.Authorization.ToString();
    var token = header.StartsWith("Bearer ", StringComparison.Ordinal) ? header[7..] : null;
    if (pairing.Authenticate(token) is null) return Results.Unauthorized();
    return await next(context);
});

network.MapGet("/hello", (HttpContext http) =>
{
    var header = http.Request.Headers.Authorization.ToString();
    var paired = header.StartsWith("Bearer ") && pairing.Authenticate(header[7..]) is not null;
    return new HelloResponse("TitanDeck Host", Environment.MachineName, HostInfo.Version, Protocol.ApiVersion, paired);
});

network.MapPost("/pair", (PairRequest request) =>
{
    var result = pairing.Pair(request.Code, request.DeviceName);
    return result.Success
        ? Results.Ok(new PairResponse(result.Token!, Environment.MachineName, result.Device!.Id))
        : Results.Json(new { error = result.Error }, statusCode: StatusCodes.Status403Forbidden);
});

network.MapGet("/status", (SharedAnswer<StatusResponse> status) => status.Get());

network.MapPost("/fix", async (FixRequest request, Fixer fixer, SharedAnswer<StatusResponse> status) =>
{
    if (!Enum.TryParse<FixAction>(request.Action, out var action) || !Fixer.AllowedFromIPad.Contains(action))
        return Results.Json(new FixResponse(false, "That fix has to be done on the PC."), statusCode: StatusCodes.Status403Forbidden);
    var result = await fixer.Apply(action);
    status.Forget();   // the checklist has changed
    return Results.Ok(result);
});

network.MapPost("/rdpwrap/ini", async (HttpRequest request, WindowsProbe probe) =>
{
    using var reader = new StreamReader(request.Body);
    var text = await reader.ReadToEndAsync();
    var ini = RdpWrapIni.Parse(text);
    if (ini is null) return Results.BadRequest(new { error = "That isn't an rdpwrap.ini file." });
    await File.WriteAllTextAsync(paths.UploadedIni, text);
    string build;
    try { build = WindowsProbe.TermsrvVersion(); }
    catch (IOException) { build = ""; }   // no termsrv.dll: nothing for the ini to support
    return Results.Ok(new { supportsThisPc = ini.Supports(build), build, updated = ini.Updated?.ToString("yyyy-MM-dd") });
});

network.MapPost("/files", async (HttpRequest request, string name) =>
{
    var clean = SafeFileName.Clean(name);
    var saved = SafeFileName.Unique(clean, n => File.Exists(Path.Combine(paths.ToPC, n)));
    var target = Path.Combine(paths.ToPC, saved);
    var partial = target + ".partial";
    try
    {
        await using (var file = File.Create(partial))
        {
            await request.Body.CopyToAsync(file, request.HttpContext.RequestAborted);
        }
        File.Move(partial, target);
    }
    catch
    {
        File.Delete(partial);
        throw;
    }
    return Results.Ok(new UploadResponse(saved, new FileInfo(target).Length));
});

// The official RDP Wrapper zip, fetched by the iPad for a PC without internet.
// Checked before it's kept; installing it still needs a click on the PC.
network.MapPost("/rdpwrap/package", async (HttpRequest request) =>
{
    using var body = new MemoryStream();
    await request.Body.CopyToAsync(body, request.HttpContext.RequestAborted);
    if (body.Length > 20_000_000) return Results.BadRequest(new { error = "That's far too big to be RDP Wrapper." });
    body.Position = 0;
    if (!RdpWrapperRelease.IsOfficial(body))
        return Results.BadRequest(new { error = $"That isn't the official RDP Wrapper v{RdpWrapperRelease.Version} release." });
    Directory.CreateDirectory(paths.RdpWrapperPackage);
    await File.WriteAllBytesAsync(Path.Combine(paths.RdpWrapperPackage, RdpWrapperRelease.FileName), body.ToArray());
    // Remembers that it came, so Install can tell if Defender took it away again.
    await File.WriteAllTextAsync(RdpWrapperInstaller.SentMarker(paths), DateTimeOffset.Now.ToString("O"));
    return Results.Ok(new { saved = RdpWrapperRelease.FileName });
});

network.MapGet("/rdp/quality", () => QualityResult(RdpQualitySettings.Read));

network.MapPost("/rdp/quality", (RdpQualityRequest request) => SetQuality(request));

network.MapGet("/outbox", () => Outbox(paths));

// What the Host saw go to Titan: for a log view on the iPad.
network.MapGet("/titanlog", (long? after, TitanLog log) => TitanLogResult(log, after));

// Live sACN levels, for showing a fixture's intensity on the deck.
network.MapGet("/dmx", (DmxUniverses store, SacnListener listener) => DmxSummary(store, listener));

// Fixtures' levels now, worked out here from sACN and Titan's patch (Host 0.20):
// "users=404,405" for those, or the whole patch. Expect is TitanDeck saying it's
// about to set a level, so the Host can learn which channel is the dimmer.
network.MapGet("/levels", (string? users, LevelService levels) =>
{
    List<int>? wanted = null;
    if (!string.IsNullOrWhiteSpace(users))
    {
        wanted = [];
        foreach (var part in users.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (!int.TryParse(part, out var user) || user <= 0) return Results.BadRequest(new { error = "users is fixture numbers, with commas." });
            wanted.Add(user);
        }
        if (wanted.Count > 2000) return Results.BadRequest(new { error = "That's too many fixtures to ask for at once." });
    }
    return Results.Ok(levels.Levels(wanted));
});
network.MapPost("/levels/expect", (LevelsExpectRequest request, LevelService levels) =>
{
    if (request.Fixtures is not { Count: > 0 and <= 2000 } || request.Fixtures.Any(f => f <= 0) || !double.IsFinite(request.Level) || request.Level is < 0 or > 1)
        return Results.BadRequest(new { error = "That isn't fixture numbers and a level from 0 to 1." });
    levels.Expect(request.Fixtures.ToHashSet(), request.Level);
    return Results.Ok();
});
network.MapPost("/levels/forget", (LevelService levels) =>
{
    levels.Forget();
    return Results.Ok();
});

// The show's patch from Titan's patch report, for finding a fixture's intensity channel.
network.MapGet("/patch", (PatchReader patch) => patch.Status());

// The deck's keypad typed on the PC, so it lands on the desk's own command line
// (Titan 19's WebAPI is a separate user). Keypad keys only; the Host window types them.
network.MapPost("/desk/keys", async (DeskKeysRequest request, DeskTypeQueue queue, TitanLog log, HttpContext http) =>
{
    if (DeskKeys.Problem(request.Keys) is { } problem) return Results.BadRequest(new { error = problem });
    if (!queue.WindowListening)
        return Results.Json(new { error = "TitanDeck Host's window isn't running on the PC, so it can't type on the desk. Open TitanDeck Host there." },
            statusCode: StatusCodes.Status409Conflict);
    if (!WindowsProbe.IsTitanRunning())
        return Results.Json(new { error = "Titan isn't running, so the keypad isn't typed on the PC." }, statusCode: StatusCodes.Status409Conflict);
    // Host 0.19: the answer waits for the window to say what it did with the
    // line (typed whole, or why not), so the deck never shows "sent" for keys
    // that went nowhere.
    var started = DateTimeOffset.Now;
    var result = await queue.Enqueue(request.Keys, cancel: http.RequestAborted);
    var took = (int)(DateTimeOffset.Now - started).TotalMilliseconds;
    log.Add("Desk keys", http.Connection.RemoteIpAddress?.ToString() ?? "", "TYPE", string.Join(" ", request.Keys), "",
        result.Typed ? 200 : 409, took, result.Typed ? "typed on the PC for Titan" : "NOT typed: " + result.Problem, null, !result.Typed, started);
    return result.Typed
        ? Results.Ok(new DeskKeysResponse(request.Keys.Count, true))
        : Results.Json(new { error = result.Problem }, statusCode: StatusCodes.Status409Conflict);
});

// TitanDeck's cue fade and Clear keys, done here so a better way only needs a
// Host update. Every call goes in the Titan log; the answer says what worked.
network.MapPost("/actions/cue-fade", async (CueFadeRequest request, TitanActions actions, HttpContext http) =>
{
    if (request.TitanId <= 0 || request.Seconds is < 0 or > 3600 || double.IsNaN(request.Seconds))
        return Results.BadRequest(new { error = "That isn't a playback and a fade time." });
    return Results.Ok(await actions.CueFade(request, http.RequestAborted));
});
network.MapPost("/actions/clear-selection", async (TitanActions actions, HttpContext http) =>
    Results.Ok(await actions.ClearSelection(http.RequestAborted)));

// TitanDeck's Groups page: a group's fixture numbers, for the deck to type
// on the desk (read only on Titan; the WebAPI user's selection is put back).
network.MapGet("/groups/{titanId:int}/fixtures", async (int titanId, int? number, TitanActions actions, HttpContext http) =>
    titanId <= 0 ? Results.BadRequest(new { error = "Which group?" }) : Results.Ok(await actions.GroupFixtures(titanId, number, http.RequestAborted)));

// TitanDeck's FX page (Prism layers and their pixel maps): Test mode only
// while it's new.
network.MapPost("/fx/layer", async (FxLayerRequest request, TitanActions actions, HostModeStore mode, HttpContext http) =>
{
    if (mode.IsShow) return FxShowMode();
    if (request.Fixture <= 0 || request.Values.Any(v => string.IsNullOrWhiteSpace(v.Control) || !double.IsFinite(v.Value)))
        return Results.BadRequest(new { error = "That isn't a Prism layer fixture number and control values." });
    return Results.Ok(await actions.FxLayer(request, http.RequestAborted));
});
network.MapPost("/fx/group", async (FxGroupRequest request, TitanActions actions, HostModeStore mode, HttpContext http) =>
{
    if (mode.IsShow) return FxShowMode();
    if (request.Group <= 0 || request.Fixtures.Any(f => f <= 0))
        return Results.BadRequest(new { error = "That isn't a group number and fixture numbers." });
    return Results.Ok(await actions.FxGroup(request, http.RequestAborted));
});
network.MapGet("/fx/probe", async (int fixture, string? names, TitanActions actions, HostModeStore mode, HttpContext http) =>
{
    if (mode.IsShow) return FxShowMode();
    if (fixture <= 0) return Results.BadRequest(new { error = "Which Prism layer fixture?" });
    var extra = (names ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    return Results.Ok(await actions.FxProbe(fixture, extra, http.RequestAborted));
});

// The FX tab's Prism sync: which clips Prism has in which bank, read from
// Prism's files on this PC (nothing is sent to Titan or Prism, so any mode).
network.MapGet("/fx/media", async (string? folder, PrismMediaFinder prism, HttpContext http) =>
    Results.Ok(await Task.Run(() => prism.Read(folder), http.RequestAborted)));

// The desk's selection over CITP (experimental, Test mode only).
network.MapGet("/citp/selection", (CitpService citp) => citp.Selection());

// The Slate Book: the look per slate and take, logged from Titan's sACN (read only).
network.MapGet("/slate", (bool? summary, SlateService slate) => slate.Status(entries: summary != true));
network.MapGet("/slate/day/{day}", (string day, SlateService slate) => slate.Day(day) is { } book ? Results.Ok(book) : Results.NotFound());
network.MapPost("/slate/take", (SlateService slate) => slate.Take());
network.MapPost("/slate/new", (SlateNewRequest request, SlateService slate) => slate.NewSlate(request.Slate));
network.MapPost("/slate/letter", (SlateService slate) => slate.Letter());
network.MapPost("/slate/set", (SlateSetRequest request, SlateService slate) => slate.Set(request));
network.MapPost("/slate/note", (SlateNoteRequest request, SlateService slate) => slate.Note(request));
network.MapGet("/slate/match/{day}/{id:long}", (string day, long id, SlateService slate) => slate.Match(day, id));

network.MapGet("/dmx/{universe:int}", (int universe, int? start, int? count, DmxUniverses store, SacnListener listener) =>
    DmxLevels(universe, start ?? 1, count ?? 512, store, listener));

network.MapGet("/outbox/{name}", (string name) =>
{
    // Full path, so it's always served from disk, never as a "virtual" web path.
    var path = Path.GetFullPath(Path.Combine(paths.ToIPad, SafeFileName.Clean(name)));
    return File.Exists(path)
        ? Results.File(path, "application/octet-stream", Path.GetFileName(path), enableRangeProcessing: true)
        : Results.NotFound();
});

network.MapPost("/outbox/{name}/received", (string name) =>
{
    var clean = SafeFileName.Clean(name);
    var path = Path.Combine(paths.ToIPad, clean);
    if (!File.Exists(path)) return Results.NotFound();
    var sent = SafeFileName.Unique(clean, n => File.Exists(Path.Combine(paths.ToIPadSent, n)));
    File.Move(path, Path.Combine(paths.ToIPadSent, sent));
    return Results.Ok();
});

// --- /titan/... only. Desk link (port 4434): Titan's UI WebAPI passed through.
//     Port 4436: Titan's WebAPI (4430) passed through, so every call is in the Titan log. ---

app.Map("/titan/{**rest}", (HttpContext http, DeskLink desk) => http.Connection.LocalPort switch
{
    TitanUiConfig.ProxyPort => desk.Forward(http),
    TitanUiConfig.PassThroughPort => desk.PassThrough(http),
    _ => NotFound(http),
});

static Task NotFound(HttpContext http)
{
    http.Response.StatusCode = StatusCodes.Status404NotFound;
    return Task.CompletedTask;
}

// --- The Host window's API (127.0.0.1:4432 only). ---

var local = app.MapGroup("/local").AddEndpointFilter(async (context, next) =>
{
    var connection = context.HttpContext.Connection;
    if (connection.LocalPort != Protocol.LocalPort || connection.RemoteIpAddress is null
        || !IPAddress.IsLoopback(connection.RemoteIpAddress)) return Results.NotFound();
    return await next(context);
});

// Answers at once, with no work behind it: how the window tells "the service
// is there" from "its checklist is slow" (Host 0.19.1).
local.MapGet("/ping", () => new PingResponse("TitanDeckHost", HostInfo.Version));

local.MapGet("/status", (SharedAnswer<StatusResponse> status) => status.Get());

// Test or Show. Show hides the test tools (asking Titan for a patch report).
local.MapGet("/mode", (HostModeStore mode) => new ModeDto(mode.Mode));

// The network adapter TitanDeck uses (announced on, and shown as the address to type).
local.MapGet("/network", (NetworkChoice network) => network.Status());
local.MapPost("/network", (NetworkChoiceRequest request, NetworkChoice network) => network.Choose(request.Id));
local.MapPost("/mode", (ModeDto request, HostModeStore mode, SharedAnswer<StatusResponse> status) =>
{
    if (request.Mode is not ("test" or "show")) return Results.BadRequest(new { error = "Mode is test or show." });
    mode.Set(request.Mode == "show");
    status.Forget();   // the status says which mode
    return Results.Ok(new ModeDto(mode.Mode));
});

// Follow the desk's selection over CITP: off by default, works in Test and Show.
local.MapGet("/citp", (CitpService citp) => citp.Status());
local.MapPost("/citp", (CitpEnableRequest request, CitpService citp) => citp.SetEnabled(request.Enabled));

// The Host window waits here for keypad lines to type (long poll), and says
// what it did with each. Ends at once when the service stops: the window's
// 20 s wait otherwise held a stop up for 20 s.
local.MapGet("/desk/jobs/wait", async (DeskTypeQueue queue, IHostApplicationLifetime life, CancellationToken cancel) =>
{
    using var either = CancellationTokenSource.CreateLinkedTokenSource(cancel, life.ApplicationStopping);
    return await queue.Next(TimeSpan.FromSeconds(20), either.Token);
});
local.MapPost("/desk/jobs/done", (DeskJobDoneRequest done, DeskTypeQueue queue) =>
{
    queue.Done(done.Id, done.Typed, done.Problem);
    return Results.Ok();
});

local.MapGet("/pairing", () => PairingInfo(pairing));

local.MapPost("/pairing/code", () =>
{
    pairing.NewCode(TimeSpan.FromMinutes(5));
    return PairingInfo(pairing);
});

local.MapDelete("/pairing/devices/{id}", (string id) => pairing.Revoke(id) ? Results.Ok() : Results.NotFound());

local.MapPost("/fix", async (FixRequest request, Fixer fixer, SharedAnswer<StatusResponse> status) =>
{
    if (!Enum.TryParse<FixAction>(request.Action, out var action)) return Results.BadRequest(new FixResponse(false, "Unknown fix."));
    var result = await fixer.Apply(action);
    status.Forget();   // the checklist has changed
    return Results.Ok(result);
});

local.MapGet("/rdp/quality", () => QualityResult(RdpQualitySettings.Read));

local.MapPost("/rdp/quality", (RdpQualityRequest request) => SetQuality(request));

local.MapGet("/dmx", (DmxUniverses store, SacnListener listener) => DmxSummary(store, listener));

// The Titan log, the patch and Host updates (the Host window).
local.MapGet("/titanlog", (long? after, TitanLog log) => TitanLogResult(log, after));
local.MapGet("/patch", (PatchReader patch) => patch.Status());
local.MapPost("/patch/reload", (PatchReader patch) => patch.Reload());
local.MapPost("/patch/import", (PatchImportRequest request, PatchReader patch) => patch.Import(request));
local.MapPost("/patch/ask-titan", (PatchReader patch) => patch.AskTitan());
local.MapPost("/titanlog/clear", (TitanLog log) =>
{
    log.Clear();
    return Results.Ok();
});
local.MapGet("/update", (HostUpdater updater) => updater.Status());
local.MapPost("/update/check", (HostUpdater updater) => updater.Check());
// Starts the download and answers straight away; the window watches Downloading, then Ready.
local.MapPost("/update/download", (HostUpdater updater) =>
{
    _ = updater.Download();
    return updater.Status();
});

local.MapGet("/folders", () => new { toPC = paths.ToPC, toIPad = paths.ToIPad, data = paths.Data });

// Keep last-seen times on disk without writing on every request.
var flush = new Timer(_ => pairing.Flush(), null, TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(5));
app.Lifetime.ApplicationStopping.Register(() =>
{
    flush.Dispose();
    pairing.Flush();
});

app.Run();

static TitanLogDto TitanLogResult(TitanLog log, long? after)
{
    var (entries, polls) = log.Since(after ?? 0);
    return new TitanLogDto(entries, polls);
}

static DmxSummaryDto DmxSummary(DmxUniverses store, SacnListener listener) =>
    new(store.Known(DateTimeOffset.UtcNow), listener.Listening, listener.Problem);

static IResult DmxLevels(int universe, int start, int count, DmxUniverses store, SacnListener listener)
{
    if (universe is < 1 or > SacnPacket.MaxUniverse)
        return Results.BadRequest(new { error = $"sACN universes are 1-{SacnPacket.MaxUniverse}." });
    listener.Want(universe);   // so the next ask has levels, if Titan sends it
    var levels = store.Get(universe, DateTimeOffset.UtcNow);
    if (levels is null)
        return Results.Json(new { error = $"Nothing is sending sACN universe {universe}.", problem = listener.Problem },
            statusCode: StatusCodes.Status404NotFound);
    var first = Math.Clamp(start, 1, 512);
    return Results.Ok(new DmxLevelsDto(universe, first, levels.Slice(first, count).Select(b => (int)b).ToList(),
        levels.Priority, levels.Sources, (int)levels.Age.TotalMilliseconds));
}

static IResult FxShowMode() => Results.Json(
    new { error = "FX is Test mode only for now: switch TitanDeck Host to Test mode to use it." },
    statusCode: StatusCodes.Status409Conflict);

static StatusResponse Status(WindowsProbe probe, DeskLink desk, HostPaths paths, HostModeStore mode, ILogger log)
{
    var watch = System.Diagnostics.Stopwatch.StartNew();
    var facts = probe.Gather();
    var checks = RdpDiagnosis.Run(facts);
    // Desk link is extra: it doesn't count towards remote desktop's overall state.
    Check? deskCheck, webApiCheck;
    try
    {
        deskCheck = TitanUiConfig.Diagnose(desk.Configs().Select(c => c.State).ToList(), desk.UiAnswers(), facts.TitanRunning);
        webApiCheck = WebApiServiceConfig.Diagnose(desk.WebApiServices().Select(s => s.Pre19).ToList());
    }
    catch (Exception)
    {
        deskCheck = webApiCheck = null;   // like every probe fact: one that can't be read doesn't sink the rest
    }
    int waiting;
    try { waiting = Outbox(paths).Count; }
    catch (Exception error) when (error is IOException or UnauthorizedAccessException) { waiting = 0; }   // the folder's gone: not worth losing the status over
    // Worth knowing about (Event Viewer), but not every 2 s.
    if (watch.Elapsed > TimeSpan.FromSeconds(5) && SlowStatus.ShouldLog())
        log.LogWarning("Checking this PC took {Seconds:0.0} s (firewall rules, running programs, Titan's settings). " +
                       "The Host window and TitanDeck wait that long for the checklist.", watch.Elapsed.TotalSeconds);
    return new StatusResponse(
        RdpDiagnosis.Overall(checks).ToString().ToLowerInvariant(),
        checks.Append(webApiCheck).Append(deskCheck).OfType<Check>().Select(CheckDto.From).ToList(),
        facts.IsHome ? "Windows Home" : facts.Edition,
        facts.WindowsVersion,
        facts.TermsrvVersion,
        facts.TitanRunning,
        waiting,
        HostInfo.Version,
        mode.Mode);
}

// Picture quality isn't a security setting, so a paired iPad may change it.
static IResult QualityResult(Func<RdpServerQuality> read)
{
    try
    {
        return Results.Ok(RdpQualityDto.From(read()));
    }
    catch (Exception error)
    {
        return Results.Json(new { error = "Couldn't change the remote desktop settings: " + error.Message }, statusCode: 500);
    }
}

static IResult SetQuality(RdpQualityRequest request)
{
    if (request.Resolve() is not { } quality) return Results.BadRequest(new { error = "Unknown picture setting." });
    return QualityResult(() => RdpQualitySettings.Apply(quality));
}

static List<FileEntry> Outbox(HostPaths paths) =>
    new DirectoryInfo(paths.ToIPad).EnumerateFiles()
        .Where(f => !f.Name.EndsWith(".partial") && !f.Attributes.HasFlag(FileAttributes.Hidden))
        .OrderBy(f => f.LastWriteTimeUtc)
        .Select(f => new FileEntry(f.Name, f.Length, f.LastWriteTimeUtc))
        .ToList();

static PairingInfo PairingInfo(PairingStore pairing) =>
    new(pairing.CurrentCode, pairing.CodeExpires,
        pairing.Devices.Select(d => new DeviceDto(d.Id, d.Name, d.PairedAt, d.LastSeen)).ToList());

/// <summary>A slow status is logged at most once an hour.</summary>
static class SlowStatus
{
    private static long _last;

    public static bool ShouldLog()
    {
        var now = Environment.TickCount64;
        var last = Interlocked.Read(ref _last);
        if (last != 0 && now - last < 3_600_000) return false;
        return Interlocked.CompareExchange(ref _last, now, last) == last;
    }
}
