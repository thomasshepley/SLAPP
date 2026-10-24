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
