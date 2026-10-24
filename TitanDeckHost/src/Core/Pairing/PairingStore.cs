using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace TitanDeckHost.Core.Pairing;

/// <summary>A TitanDeck app (iPad or iPhone) allowed to use the Host's network API.</summary>
public sealed record PairedDevice(string Id, string Name, string TokenHash, DateTimeOffset PairedAt, DateTimeOffset? LastSeen);

/// <summary>
/// Pairing with a 6-digit code shown on the PC. A correct code gives the app a
/// random token, stored here only as a SHA-256 hash. Codes expire, work once,
/// and stop working after a few wrong guesses, so nothing else on the show
/// network can pair by guessing.
/// </summary>
public sealed class PairingStore
{
    public const int MaxAttemptsPerCode = 5;

    private readonly string? _path;
    private readonly Func<DateTimeOffset> _now;
    private readonly object _lock = new();
    private List<PairedDevice> _devices = new();
    private string? _code;
    private DateTimeOffset _codeExpires;
    private int _failedAttempts;

    /// <param name="path">JSON file the paired devices are kept in, or null to keep them in memory.</param>
    public PairingStore(string? path = null, Func<DateTimeOffset>? now = null)
    {
        _path = path;
        _now = now ?? (() => DateTimeOffset.UtcNow);
        Load();
    }

    public IReadOnlyList<PairedDevice> Devices
    {
        get { lock (_lock) return _devices.ToList(); }
    }

    /// <summary>The code to show on the PC, or null when none is active.</summary>
    public string? CurrentCode
    {
        get { lock (_lock) return _code is not null && _now() < _codeExpires ? _code : null; }
    }

    public DateTimeOffset? CodeExpires
    {
        get { lock (_lock) return CurrentCode is null ? null : _codeExpires; }
    }

    /// <summary>Makes a fresh code, replacing any previous one.</summary>
    public string NewCode(TimeSpan validFor)
    {
        lock (_lock)
        {
            _code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
            _codeExpires = _now() + validFor;
            _failedAttempts = 0;
            return _code;
        }
    }

    public sealed record PairResult(bool Success, string? Token, PairedDevice? Device, string? Error);

    /// <summary>Checks a code typed on the iPad and, if right, returns a new token.</summary>
    public PairResult Pair(string code, string deviceName)
    {
        lock (_lock)
        {
            if (_code is null || _now() >= _codeExpires)
                return new(false, null, null, "No pairing code is active. Open TitanDeck Host on the PC to get one.");
            if (!FixedEquals(code.Trim(), _code))
            {
                _failedAttempts++;
                if (_failedAttempts >= MaxAttemptsPerCode) _code = null;
                return new(false, null, null, _code is null
                    ? "Too many wrong codes. Make a new one on the PC."
                    : "That code isn't right.");
            }

            _code = null;   // one use only
            var token = Base64Url(RandomNumberGenerator.GetBytes(32));
            var name = string.IsNullOrWhiteSpace(deviceName) ? "TitanDeck" : deviceName.Trim();
            if (name.Length > 60) name = name[..60];
            var device = new PairedDevice(Guid.NewGuid().ToString("N"), name, Hash(token), _now(), null);
            _devices.Add(device);
            Save();
            return new(true, token, device, null);
        }
    }

    /// <summary>The device a token belongs to, or null. Records when it was last seen.</summary>
    public PairedDevice? Authenticate(string? token)
    {
        if (string.IsNullOrEmpty(token)) return null;
        var hash = Hash(token);
        lock (_lock)
        {
            var index = _devices.FindIndex(d => FixedEquals(d.TokenHash, hash));
            if (index < 0) return null;
            var seen = _devices[index] with { LastSeen = _now() };
            _devices[index] = seen;
            return seen;
        }
    }

    public bool Revoke(string deviceId)
    {
        lock (_lock)
        {
            var removed = _devices.RemoveAll(d => d.Id == deviceId) > 0;
            if (removed) Save();
            return removed;
        }
    }

    /// <summary>Writes last-seen times; called now and then rather than on every request.</summary>
    public void Flush()
    {
        lock (_lock) Save();
    }

    public static string Hash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private static bool FixedEquals(string a, string b) =>
        CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(a), Encoding.UTF8.GetBytes(b));

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private void Load()
    {
        if (_path is null || !File.Exists(_path)) return;
        try
        {
            _devices = JsonSerializer.Deserialize<List<PairedDevice>>(File.ReadAllText(_path)) ?? new();
        }
        catch (JsonException)
        {
            _devices = new();   // a damaged file just means pairing again
        }
    }

    private void Save()
    {
        if (_path is null) return;
        Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
        var temp = _path + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(_devices, new JsonSerializerOptions { WriteIndented = true }));
        File.Move(temp, _path, overwrite: true);
    }
}
