using System.Text.Json;

namespace TitanDeckHost.Service;

/// <summary>
/// Test or Show. In Show mode the Host is the production tool only:
/// experimental calls to Titan (asking it to write a patch report) are off.
/// Following the selection over CITP works in both. Kept in Data\mode.json so it
/// survives restarts. Test is the default.
/// </summary>
public sealed class HostModeStore
{
    private readonly string _file;
    private bool _show;

    public HostModeStore(HostPaths paths)
    {
        _file = Path.Combine(paths.Data, "mode.json");
        try
        {
            if (File.Exists(_file))
                _show = JsonDocument.Parse(File.ReadAllText(_file)).RootElement.GetProperty("mode").GetString() == "show";
        }
        catch (Exception)
        {
            _show = false;   // unreadable: Test, the safe default for trying things
        }
    }

    public bool IsShow => _show;
    public string Mode => _show ? "show" : "test";

    public void Set(bool show)
    {
        _show = show;
        File.WriteAllText(_file, JsonSerializer.Serialize(new { mode = Mode }));
    }
}
