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
    private (DateTimeOffset At, IReadOnlyList<(string Path, TitanUiConfig.State State)> Files)? cached;

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
        foreach (var root in InstallRoots())
        {
            IEnumerable<string> files;
            try
            {
                files = Directory.EnumerateFiles(root, "*.config",
                        new EnumerationOptions { RecurseSubdirectories = true, MaxRecursionDepth = 4, IgnoreInaccessible = true })
                    .Where(TitanUiConfig.IsSettingsFileName);
            }
            catch (IOException) { continue; }
            catch (UnauthorizedAccessException) { continue; }
            foreach (var file in files)
            {
                try
                {
                    if (new FileInfo(file).Length > 2_000_000) continue;
                    if (TitanUiConfig.Read(File.ReadAllText(file)) is { } state) found.Add((file, state));
                }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException)
                {
                    log.LogDebug("Couldn't read {File}: {Error}", file, error.Message);
                }
            }
        }
        lock (gate) cached = (DateTimeOffset.UtcNow, found);
        return found;
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
    public async Task Forward(HttpContext http)
    {
        var watch = Stopwatch.StartNew();
        var path = http.Request.Path.Value ?? "";
        void Log(int status, string? note, bool flagged) => titanLog.Add("Desk link - Titan UI",
            http.Connection.RemoteIpAddress?.ToString() ?? "", http.Request.Method, path,
            Uri.UnescapeDataString((http.Request.QueryString.Value ?? "").TrimStart('?')), status,
            (int)watch.ElapsedMilliseconds, note, null, flagged, DateTimeOffset.Now);
        if (!TitanUiConfig.ProxyAllows(path))
        {
            http.Response.StatusCode = StatusCodes.Status403Forbidden;
            await http.Response.WriteAsync("The desk link doesn't pass that call on to Titan.");
            Log(403, "refused: the desk link never passes this on to the desk", true);
            return;
        }
        var port = TargetPort;
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
            Log((int)response.StatusCode, body.Length is > 0 and <= 120 ? "answered " + System.Text.Encoding.UTF8.GetString(body) : null,
                !response.IsSuccessStatusCode);
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
        {
            http.Response.StatusCode = StatusCodes.Status502BadGateway;
            await http.Response.WriteAsync($"Titan's UI WebAPI isn't answering on port {port}.");
            Log(502, $"Titan's UI WebAPI isn't answering on {port}", true);
        }
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
