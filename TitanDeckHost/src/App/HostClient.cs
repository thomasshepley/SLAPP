using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using TitanDeckHost.Core.Api;

namespace TitanDeckHost.App;

public sealed record Folders(string ToPC, string ToIPad, string Data);

/// <summary>Talks to the TitanDeck Host service on 127.0.0.1:4432.</summary>
public sealed class HostClient
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly HttpClient _http = new()
    {
        BaseAddress = new Uri($"http://127.0.0.1:{Protocol.LocalPort}/local/"),
        Timeout = TimeSpan.FromSeconds(30),
    };

    public Task<StatusResponse?> Status() => Get<StatusResponse>("status");
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

    // --- Updates, Fake Titan, the Titan log ---

    public Task<UpdateStatusDto?> Update() => Get<UpdateStatusDto>("update");
    public Task<UpdateStatusDto?> CheckUpdate() => Post<UpdateStatusDto>("update/check");
    public Task<UpdateStatusDto?> DownloadUpdate() => Post<UpdateStatusDto>("update/download");

    public Task<FakeTitanStatusDto?> FakeTitan() => Get<FakeTitanStatusDto>("faketitan");
    public Task<FakeTitanStatusDto?> StartFakeTitan(FakeTitanStartRequest request) => Post<FakeTitanStatusDto>("faketitan/start", request);
    public Task<FakeTitanStatusDto?> StopFakeTitan() => Post<FakeTitanStatusDto>("faketitan/stop");

    public async Task<string?> DeskSelect(string fixtures)
    {
        var answer = await Post<JsonElement>("faketitan/desk-select", new DeskSelectRequest(fixtures));
        return answer.ValueKind == JsonValueKind.Object && answer.TryGetProperty("note", out var note) ? note.GetString() : null;
    }

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
