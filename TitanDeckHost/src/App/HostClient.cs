using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Net;

namespace TitanDeckHost.App;

public sealed record Folders(string ToPC, string ToIPad, string Data);

/// <summary>Talks to the TitanDeck Host service on 127.0.0.1:4432.</summary>
public sealed class HostClient
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public static readonly Uri Local = new($"http://127.0.0.1:{Protocol.LocalPort}/local/");

    // Never by way of Windows' proxy settings: the service is on this PC (see LocalHttp).
    private readonly HttpClient _http = LocalHttp.Client(TimeSpan.FromSeconds(30), Local);

    /// <summary>
    /// Is the service there? Null when it answered, else why not in a few
    /// words. Nothing is worked out behind it, so a slow answer here is the
    /// link or the service itself, never the checklist.
    /// </summary>
    public async Task<string?> Ping()
    {
        try
        {
            using var patience = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            using var response = await _http.GetAsync("ping", patience.Token);
            // A service older than 0.19.1 has no ping, but it's there: its checklist says the rest.
            if (response.StatusCode == System.Net.HttpStatusCode.NotFound) return null;
            if (!response.IsSuccessStatusCode) return $"it answered {(int)response.StatusCode}";
            var ping = await response.Content.ReadFromJsonAsync<PingResponse>(Json, patience.Token);
            return ping?.Service == "TitanDeckHost" ? null : "something else answered there, not TitanDeck Host's service";
        }
        catch (Exception error)
        {
            return ServiceHealth.Describe(error);
        }
    }

    /// <summary>The checklist, or why it didn't come back.</summary>
    public async Task<(StatusResponse? Status, string? Problem)> Status()
    {
        try
        {
            using var patience = new CancellationTokenSource(TimeSpan.FromSeconds(20));
            return (await _http.GetFromJsonAsync<StatusResponse>("status", Json, patience.Token), null);
        }
        catch (Exception error)
        {
            return (null, ServiceHealth.Describe(error));
        }
    }
    public Task<PairingInfo?> Pairing() => Get<PairingInfo>("pairing");
    public Task<Folders?> Folders() => Get<Folders>("folders");

    public async Task<PairingInfo?> NewCode()
    {
        using var response = await _http.PostAsync("pairing/code", null);
        return await response.Content.ReadFromJsonAsync<PairingInfo>(Json);
    }

    public Task<RdpQualityDto?> Quality() => Get<RdpQualityDto>("rdp/quality");

    public async Task<RdpQualityDto?> SetQuality(string preset)
    {
        try
        {
            using var response = await _http.PostAsJsonAsync("rdp/quality", new RdpQualityRequest(preset, null, null, 0), Json);
            return response.IsSuccessStatusCode ? await response.Content.ReadFromJsonAsync<RdpQualityDto>(Json) : null;
        }
        catch (Exception)
        {
            return null;
        }
    }

    public async Task Revoke(string id) => await _http.DeleteAsync($"pairing/devices/{Uri.EscapeDataString(id)}");

    public async Task<FixResponse> Fix(string action)
    {
        try
        {
            using var response = await _http.PostAsJsonAsync("fix", new FixRequest(action), Json);
            return await response.Content.ReadFromJsonAsync<FixResponse>(Json) ?? new FixResponse(false, "No answer.");
        }
        catch (Exception error)
        {
            return new FixResponse(false, error.Message);
        }
    }

    // --- Updates, the Titan log ---

    public Task<UpdateStatusDto?> Update() => Get<UpdateStatusDto>("update");
    public Task<UpdateStatusDto?> CheckUpdate() => Post<UpdateStatusDto>("update/check");
    public Task<UpdateStatusDto?> DownloadUpdate() => Post<UpdateStatusDto>("update/download");

    public Task<NetworkDto?> Network() => Get<NetworkDto>("network");
    public Task<NetworkDto?> ChooseNetwork(string? id) => Post<NetworkDto>("network", new NetworkChoiceRequest(id));

    public Task<CitpStatusDto?> Citp() => Get<CitpStatusDto>("citp");
    public Task<CitpStatusDto?> SetCitp(bool enabled) => Post<CitpStatusDto>("citp", new CitpEnableRequest(enabled));

    public Task<ModeDto?> Mode() => Get<ModeDto>("mode");
    public Task<ModeDto?> SetMode(string mode) => Post<ModeDto>("mode", new ModeDto(mode));

    public Task<PatchDto?> Patch() => Get<PatchDto>("patch");
    public Task<PatchDto?> ReloadPatch() => Post<PatchDto>("patch/reload");
    public Task<PatchDto?> ImportPatch(string name, string text) => Post<PatchDto>("patch/import", new PatchImportRequest(name, text));
    public Task<PatchDto?> AskTitanForPatch() => Post<PatchDto>("patch/ask-titan");

    public Task<TitanLogDto?> TitanLog(long after) => Get<TitanLogDto>($"titanlog?after={after}");
    public Task ClearTitanLog() => Post<JsonElement>("titanlog/clear");

    private async Task<T?> Post<T>(string path, object? body = null)
    {
        try
        {
            using var response = body is null ? await _http.PostAsync(path, null) : await _http.PostAsJsonAsync(path, body, Json);
            if (!response.IsSuccessStatusCode || response.Content.Headers.ContentLength == 0) return default;
            return await response.Content.ReadFromJsonAsync<T>(Json);
        }
        catch (Exception)
        {
            return default;
        }
    }

    private async Task<T?> Get<T>(string path)
    {
        try
        {
            return await _http.GetFromJsonAsync<T>(path, Json);
        }
        catch (Exception)
        {
            return default;   // service stopped or starting; the window says so
        }
    }
}
