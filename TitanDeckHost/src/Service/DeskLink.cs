using System.Diagnostics;
using System.Net.Http.Headers;
using TitanDeckHost.Core.Titan;

namespace TitanDeckHost.Service;

/// <summary>
/// Titan's UI WebAPI (see <see cref="TitanUiConfig"/>): finds Titan's config
/// files, says whether the UI WebAPI answers, and passes /titan/... requests
/// from the iPad on port 4434 through to it on this PC. It's Titan's own API
/// passed straight through, so it's no more open than Titan's port 4430.
/// </summary>
public sealed class DeskLink(TitanLog titanLog, ILogger<DeskLink> log)
{
    private static readonly TimeSpan ConfigCacheFor = TimeSpan.FromSeconds(30);
    private static readonly HttpClient Titan = new() { Timeout = TimeSpan.FromSeconds(3) };
    private static readonly HttpClient Probe = new() { Timeout = TimeSpan.FromMilliseconds(800) };

    private readonly object gate = new();
    private (DateTimeOffset At, IReadOnlyList<(string Path, TitanUiConfig.State State)> Files,
             IReadOnlyList<(string Path, bool? Pre19)> Services)? cached;

    /// <summary>Titan's settings files under Avolites' install folders
    /// (Titan.dll.config from Titan 19, which runs on .NET 8; Titan.exe.config before):
    /// only ones that already have webapi.enabled in them.</summary>
    public IReadOnlyList<(string Path, TitanUiConfig.State State)> Configs(bool fresh = false)
    {
        lock (gate)
        {
            if (!fresh && cached is { } c && DateTimeOffset.UtcNow - c.At < ConfigCacheFor) return c.Files;
        }
        var found = new List<(string, TitanUiConfig.State)>();
        var services = new List<(string, bool?)>();
        foreach (var root in InstallRoots())
        {
            IEnumerable<string> files;
            try
            {
                files = Directory.EnumerateFiles(root, "*.config",
                        new EnumerationOptions { RecurseSubdirectories = true, MaxRecursionDepth = 4, IgnoreInaccessible = true })
                    .Where(f => TitanUiConfig.IsSettingsFileName(f) || WebApiServiceConfig.IsServiceConfig(f));
            }
            catch (IOException) { continue; }
            catch (UnauthorizedAccessException) { continue; }
            foreach (var file in files)
            {
                try
                {
                    if (new FileInfo(file).Length > 2_000_000) continue;
                    var text = File.ReadAllText(file);
                    if (WebApiServiceConfig.IsServiceConfig(file)) services.Add((file, WebApiServiceConfig.ReadPre19(text)));
                    else if (TitanUiConfig.Read(text) is { } state) found.Add((file, state));
                }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException)
                {
                    log.LogDebug("Couldn't read {File}: {Error}", file, error.Message);
                }
            }
        }
        lock (gate) cached = (DateTimeOffset.UtcNow, found, services);
        return found;
    }

    /// <summary>Titan 19's WebAPI service settings files (WebAPI\&lt;version&gt;\WebAPIService.dll.config)
    /// and their pre19Compatibility switch (null when the file hasn't got one).</summary>
    public IReadOnlyList<(string Path, bool? Pre19)> WebApiServices(bool fresh = false)
    {
        Configs(fresh);
        lock (gate) return cached?.Services ?? [];
    }

    /// <summary>
    /// Turns on pre19Compatibility in every Titan 19.2+ WebAPI service settings
    /// file (a copy of each kept first), then restarts that service if it is a
    /// Windows service; otherwise Titan restarting it is enough.
    /// </summary>
    public string EnableWebApiCompatibility()
    {
        var files = WebApiServices(fresh: true).Where(f => f.Pre19 is not null).ToList();
        if (files.Count == 0)
            throw new InvalidOperationException("Couldn't find Titan 19's WebAPI settings (WebAPIService.dll.config with " +
                                                "webapi.pre19Compatibility in it). Titan 19.2 or later has it.");
        foreach (var (path, pre19) in files)
        {
            if (pre19 == true) continue;
            var text = File.ReadAllText(path);
            var backup = path + TitanUiConfig.BackupSuffix;
            if (!File.Exists(backup)) File.WriteAllText(backup, text);
            File.WriteAllText(path, WebApiServiceConfig.TurnOnPre19(text));
            log.LogInformation("Turned on pre19Compatibility in {File}", path);
        }
        lock (gate) cached = null;
        var restarted = RestartWebApiService();
        return "Turned on (the old file is kept next to it as *" + TitanUiConfig.BackupSuffix + "). " +
               (restarted is null
                   ? "Restart Titan so its WebAPI picks it up."
                   : $"Restarted the {restarted} service, so it's on now. If TitanDeck still gets errors, restart Titan.");
    }

    /// <summary>Restarts the Windows service running WebAPIService, if there is one; its name, or null.</summary>
    private string? RestartWebApiService()
    {
        if (!OperatingSystem.IsWindows()) return null;
        try
        {
            using var services = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services");
            if (services is null) return null;
            foreach (var name in services.GetSubKeyNames())
            {
                using var key = services.OpenSubKey(name);
                if (key?.GetValue("ImagePath") is not string image
                    || !image.Contains("WebAPIService", StringComparison.OrdinalIgnoreCase)) continue;
                using var service = new System.ServiceProcess.ServiceController(name);
                if (service.Status != System.ServiceProcess.ServiceControllerStatus.Stopped)
                {
                    service.Stop();
                    service.WaitForStatus(System.ServiceProcess.ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(20));
                }
                service.Start();
                service.WaitForStatus(System.ServiceProcess.ServiceControllerStatus.Running, TimeSpan.FromSeconds(20));
                return service.DisplayName;
            }
        }
        catch (Exception error)
        {
            log.LogWarning("Couldn't restart Titan's WebAPI service: {Error}", error.Message);
        }
        return null;
    }

    /// <summary>Titan's UI WebAPI answers on this PC.</summary>
    public bool UiAnswers()
    {
        try
        {
            using var response = Probe.GetAsync($"http://127.0.0.1:{TargetPort}/titan/get/System/SoftwareVersion")
                .GetAwaiter().GetResult();
            return response.IsSuccessStatusCode;
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
        {
            return false;
        }
    }

    /// <summary>Where Titan's UI WebAPI is on this PC: 4430 when Titan's
    /// settings file already runs it there, else 4433.</summary>
    public int TargetPort => TitanUiConfig.TargetPort(Configs().Select(c => c.State).ToList());

    /// <summary>Turns the UI WebAPI on at port 4433 in every Titan config
    /// found, keeping a copy of each file as it was first. Never when it's
    /// already on at 4430: that's the WebAPI TitanDeck uses for everything.</summary>
    public string Enable()
    {
        var files = Configs(fresh: true);
        if (TitanUiConfig.UiIsOnApiPort(files.Select(f => f.State).ToList()))
            return $"Nothing to change: Titan's WebAPI already runs inside Titan on port {TitanUiConfig.ApiPort}, and the desk link uses it.";
        if (files.Count == 0)
            throw new InvalidOperationException("Couldn't find Titan's settings file. Add webapi.enabled = true and " +
                                                $"webapi.port = {TitanUiConfig.UiPort} to it by hand.");
        foreach (var (path, _) in files)
        {
            var text = File.ReadAllText(path);
            var backup = path + TitanUiConfig.BackupSuffix;
            if (!File.Exists(backup)) File.WriteAllText(backup, text);
            File.WriteAllText(path, TitanUiConfig.Enable(text));
            log.LogInformation("Turned on Titan's UI WebAPI in {File}", path);
        }
        lock (gate) cached = null;
        return $"Turned on in {string.Join(", ", files.Select(f => Path.GetFileName(f.Path)))}. Restart Titan to finish. " +
               $"(The old file is kept next to it as *{TitanUiConfig.BackupSuffix}.)";
    }

    /// <summary>Passes one request through to Titan's UI WebAPI.</summary>
    public Task Forward(HttpContext http) =>
        Send(http, "Desk link - Titan UI", TargetPort, TitanUiConfig.ProxyAllows, "Titan's UI WebAPI");

    /// <summary>
    /// Passes one request through to Titan's WebAPI on this PC (4430), for an
    /// iPad set to send its Titan calls through the Host. It's the same API
    /// TitanDeck would call directly, so nothing is refused, but every call
    /// lands in the Titan log, with Titan's answer when it's an error.
    /// </summary>
    public Task PassThrough(HttpContext http) =>
        Send(http, "TitanDeck - WebAPI", TitanUiConfig.ApiPort, _ => true, "Titan's WebAPI");

    private async Task Send(HttpContext http, string who, int port, Func<string, bool> allows, string name)
    {
        var watch = Stopwatch.StartNew();
        var path = http.Request.Path.Value ?? "";
        var patch = path.Contains("/Patch", StringComparison.OrdinalIgnoreCase);
        void Log(int status, string? note, bool flagged) => titanLog.Add(who,
            http.Connection.RemoteIpAddress?.ToString() ?? "", http.Request.Method, path,
            Uri.UnescapeDataString((http.Request.QueryString.Value ?? "").TrimStart('?')), status,
            (int)watch.ElapsedMilliseconds, note, null, flagged, DateTimeOffset.Now);
        if (!allows(path))
        {
            http.Response.StatusCode = StatusCodes.Status403Forbidden;
            await http.Response.WriteAsync("The desk link doesn't pass that call on to Titan.");
            Log(403, "refused: the desk link never passes this on to the desk", true);
            return;
        }
        var target = $"http://127.0.0.1:{port}{http.Request.Path}{http.Request.QueryString}";
        using var request = new HttpRequestMessage(new HttpMethod(http.Request.Method), target);
        if (http.Request.ContentLength > 0 || http.Request.Headers.TransferEncoding.Count > 0)
        {
            // Whole, with a length: a stream goes out chunked, and Titan (and
            // fake_titan.py) may read only Content-Length - a fade time from
            // the deck arrived as an empty body.
            using var buffer = new MemoryStream();
            await http.Request.Body.CopyToAsync(buffer, http.RequestAborted);
            request.Content = new ByteArrayContent(buffer.ToArray());
            if (http.Request.ContentType is { } type) request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(type);
        }
        try
        {
            using var response = await Titan.SendAsync(request, http.RequestAborted);
            // Titan's answers are small: send them whole, with a length, not
            // chunked (some HTTP clients time out on chunked replies).
            var body = await response.Content.ReadAsByteArrayAsync(http.RequestAborted);
            http.Response.StatusCode = (int)response.StatusCode;
            if (response.Content.Headers.ContentType is { } contentType) http.Response.ContentType = contentType.ToString();
            http.Response.ContentLength = body.Length;
            await http.Response.Body.WriteAsync(body, http.RequestAborted);
            Log((int)response.StatusCode, AnswerNote(body, response.IsSuccessStatusCode, patch), !response.IsSuccessStatusCode || patch);
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
        {
            http.Response.StatusCode = StatusCodes.Status502BadGateway;
            await http.Response.WriteAsync($"{name} isn't answering on port {port}.");
            Log(502, $"{name} isn't answering on {port}", true);
        }
    }

    /// <summary>A short answer as it came; an error's text (Titan explains a 500 in it) up to 400 characters.</summary>
    public static string? AnswerNote(byte[] body, bool success, bool patch = false)
    {
        var text = System.Text.Encoding.UTF8.GetString(body).Trim();
        var shown = text.Length == 0 ? null
            : success ? (text.Length <= 120 ? "answered " + text : null)
            : "Titan said: " + (text.Length <= 400 ? text : text[..400] + "...");
        return patch ? "Patch call (the 4430 WebAPI user's Patch, never the desk's)" + (shown is null ? "" : "; " + shown) : shown;
    }

    private static IEnumerable<string> InstallRoots()
    {
        foreach (var folder in new[] { Environment.SpecialFolder.ProgramFiles, Environment.SpecialFolder.ProgramFilesX86 })
        {
            var path = Environment.GetFolderPath(folder);
            if (string.IsNullOrEmpty(path)) continue;
            var avolites = Path.Combine(path, "Avolites");
            if (Directory.Exists(avolites)) yield return avolites;
        }
    }
}
