using System.Text.Json;
using TitanDeckHost.Core.Api;
using TitanDeckHost.Core.Net;

namespace TitanDeckHost.Service;

/// <summary>
/// The network adapter TitanDeck uses (Data\network.json), or automatic. The
/// name is kept too, so it's still found if Windows gives the adapter a new id.
/// </summary>
public sealed class NetworkChoice
{
    private sealed record Saved(string? Id, string? Name);

    private readonly string _file;
    private Saved _saved = new(null, null);

    public NetworkChoice(HostPaths paths)
    {
        _file = Path.Combine(paths.Data, "network.json");
        try
        {
            if (File.Exists(_file)) _saved = JsonSerializer.Deserialize<Saved>(File.ReadAllText(_file)) ?? _saved;
        }
        catch (Exception)
        {
            // Unreadable: automatic, which always works.
        }
    }

    /// <summary>Raised when the choice changes, so the Host announces itself again.</summary>
    public event Action? Changed;

    public (AdapterInfo? Adapter, string? Problem) Current() =>
        NetworkAdapters.Resolve(NetworkAdapters.Read(), _saved.Id, _saved.Name);

    public NetworkDto Status()
    {
        var adapters = NetworkAdapters.Read();
        var (adapter, problem) = NetworkAdapters.Resolve(adapters, _saved.Id, _saved.Name);
        var announcing = adapter?.Ipv4 ?? adapters.Where(a => a.Up).SelectMany(a => a.Ipv4).ToList();
        return new NetworkDto(_saved.Id, _saved.Name, announcing, problem,
            adapters.Select(a => new NetworkAdapterDto(a.Id, a.Name, a.Description, a.Ipv4, a.Up)).ToList());
    }

    public NetworkDto Choose(string? id)
    {
        var adapter = id is null ? null : NetworkAdapters.Read().FirstOrDefault(a => a.Id == id);
        _saved = adapter is null ? new Saved(null, null) : new Saved(adapter.Id, adapter.Name);
        File.WriteAllText(_file, JsonSerializer.Serialize(_saved));
        Changed?.Invoke();
        return Status();
    }
}
