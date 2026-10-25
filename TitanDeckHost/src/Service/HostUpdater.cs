using System.Net.Http.Headers;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Update;

namespace TitanDeckHost.Service;

/// <summary>
/// Keeps an eye on GitHub for a newer TitanDeck Host and fetches it when asked.
/// Checks at start-up and every 6 hours (quietly: the show network often has
/// no internet). Downloads go to ProgramData\TitanDeck Host\Updates and are
/// only kept if they match GitHub's SHA-256; the Host window then runs the
/// installer, which asks Windows for permission, updates, and reopens the Host.
/// </summary>
public sealed class HostUpdater(HostPaths paths, ILogger<HostUpdater> log) : BackgroundService
{
    private static readonly TimeSpan CheckEvery = TimeSpan.FromHours(6);
    private static readonly HttpClient Http = CreateClient();

    private readonly SemaphoreSlim oneAtATime = new(1, 1);
    private HostRelease? latest;
    private DateTimeOffset? checkedAt;
    private string? problem;
    private double? downloading;
    private string? ready;

    private string Folder => Path.Combine(paths.Data, "Updates");

    public UpdateStatusDto Status() => new(
        HostInfo.Version,
        latest?.Version.ToString(3),
        latest is not null && HostUpdate.IsNewer(latest, HostInfo.Version),
        latest?.Notes,
        latest?.Published,
        checkedAt,
        problem,
        downloading,
        ready,
        ready is null ? null : latest?.Sha256);

    public async Task<UpdateStatusDto> Check()
    {
        try
        {
            using var response = await Http.GetAsync(HostUpdate.ReleasesUrl);
            if (!response.IsSuccessStatusCode)
            {
                problem = $"GitHub answered {(int)response.StatusCode} - try again later.";
                return Status();
            }
            var found = HostUpdate.Newest(await response.Content.ReadAsStringAsync());
            if (found?.Version != latest?.Version) ready = null;
            latest = found;
            checkedAt = DateTimeOffset.Now;
            problem = found is null ? "No TitanDeck Host releases found on GitHub." : null;
            if (latest is not null && Path.Combine(Folder, latest.AssetName) is var file && File.Exists(file)
                && Verified(file, latest)) ready = file;
        }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
        {
            problem = "Couldn't reach GitHub (no internet on this network?).";
        }
        return Status();
    }

    /// <summary>Downloads the newer version and checks it. Status().Ready is
    /// then the installer to run.</summary>
    public async Task<UpdateStatusDto> Download()
    {
        if (!await oneAtATime.WaitAsync(0)) return Status();   // already downloading
        try
        {
            downloading = 0;
            if (latest is null) await Check();
            if (latest is not { } release || !HostUpdate.IsNewer(release, HostInfo.Version))
            {
                downloading = null;
                problem = "There's no newer version to download.";
                return Status();
            }
            if (release.Sha256 is null || !HostUpdate.IsOfficial(release.Url))
            {
                downloading = null;
                problem = "GitHub didn't give a fingerprint for that installer, so it won't be used. Download it by hand.";
                return Status();
            }
            Directory.CreateDirectory(Folder);
            var target = Path.Combine(Folder, release.AssetName);
            if (File.Exists(target) && Verified(target, release))
            {
                downloading = null;
                ready = target;
                return Status();
            }
            var partial = target + ".partial";
            downloading = 0;
            problem = null;
            try
            {
                using var response = await Http.GetAsync(release.Url, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();
                await using (var source = await response.Content.ReadAsStreamAsync())
                await using (var file = File.Create(partial))
                {
                    var buffer = new byte[81920];
                    long done = 0;
                    int read;
                    while ((read = await source.ReadAsync(buffer)) > 0)
                    {
                        await file.WriteAsync(buffer.AsMemory(0, read));
                        done += read;
                        downloading = release.Size > 0 ? Math.Min(1, (double)done / release.Size) : null;
                    }
                }
                if (!Verified(partial, release))
                {
                    File.Delete(partial);
                    problem = "The download didn't match GitHub's fingerprint, so it was thrown away. Try again.";
                    return Status();
                }
                File.Move(partial, target, overwrite: true);
                ready = target;
                log.LogInformation("Downloaded and checked TitanDeck Host {Version}", release.Version);
                foreach (var old in Directory.EnumerateFiles(Folder, "TitanDeckHost-Setup-*.exe").Where(f => f != target))
                    File.Delete(old);
            }
            catch (Exception error) when (error is HttpRequestException or TaskCanceledException or IOException)
            {
                if (File.Exists(partial)) File.Delete(partial);
                problem = "The download stopped: " + error.Message;
            }
            finally
            {
                downloading = null;
            }
            return Status();
        }
        finally
        {
            oneAtATime.Release();
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stopping)
    {
        try
        {
            await Task.Delay(TimeSpan.FromSeconds(30), stopping);
            while (!stopping.IsCancellationRequested)
            {
                await Check();
                await Task.Delay(CheckEvery, stopping);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private static bool Verified(string file, HostRelease release)
    {
        if (release.Sha256 is null) return false;
        using var stream = File.OpenRead(file);
        return stream.Length == release.Size && HostUpdate.Matches(stream, release.Sha256);
    }

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("TitanDeckHost", HostInfo.Version));
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        return client;
    }
}
