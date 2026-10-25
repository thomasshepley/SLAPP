using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace TitanDeckHost.Core.Titan;

/// <summary>Which Titan user a request reached: the WebAPI's own (port 4430)
/// or the operator's, through Titan's UI WebAPI (the desk link, 4433).</summary>
public enum FakeUser { Api, Desk }

public sealed record FakeTitanOptions(int Fixtures = 12, int Playbacks = 20, bool UserNumbers = true);

/// <summary>Fake Titan's answer: status, JSON body (or none) and what it did.
/// Flagged marks something TitanDeck must never do (Patch on the desk).</summary>
public sealed record FakeReply(int Status, JsonNode? Body, string? Note, bool Flagged = false);

/// <summary>
/// Pretends to be the Avolites Titan WebAPI, so TitanDeck can be tested
/// without Titan or an AvoKey. It knows the calls TitanDeck makes and answers
/// with best guesses at what real Titan does: it checks the app's side, it
/// doesn't settle how Titan behaves. Like Titan it has two users - the
/// WebAPI's own and the desk's - each with its own command line and
/// selection; levels are shared, like one show. Thread-safe.
/// (Ported from TitanDeck/Tools/fake_titan.py, which still runs on a Mac.)
/// </summary>
public sealed class FakeTitan
{
    public const string Version = "19.2.0 (Fake Titan)";
    /// <summary>Named the way TitanDeck's CCT keys look for them.</summary>
    public static readonly string[] ColourPalettes = ["2700K", "3200K", "4000K", "4500K", "5600K", "6000K", "6500K", "7500K", "10000K"];
    public static readonly string[] Workspaces = ["Programming", "Patch", "Playbacks", "Pixel map", "Shapes", "Output"];
    private const string Script = "/titan/script/2/";
    private static readonly Regex Command = new(@"^(\d+)?(?:@(\d{1,3}))?$", RegexOptions.Compiled);
    private static readonly Regex SelectionRead = new(@"^Selection/Context/(Global|Programmer)/Get(All)?SelectedFixtureIds$", RegexOptions.Compiled);

    private sealed class User
    {
        public string Line = "";
        public List<int> Selected = [];
    }

    private readonly object gate = new();
    private readonly Dictionary<FakeUser, User> users = new() { [FakeUser.Api] = new(), [FakeUser.Desk] = new() };
    private readonly SortedDictionary<int, double> levels = [];     // fixture -> percent
    private readonly SortedDictionary<int, double> playbacks = [];  // user number -> 0-1
    private readonly Dictionary<int, double> flashed = [];          // level saved by FlashOut
    private readonly Dictionary<int, double> held = [];             // level saved by a flash, for the release
    private readonly Dictionary<int, Dictionary<string, double>> cueTimes = [];
    private (int Universe, int Address)? patchCurrent;
    private int? editing;
    private readonly bool userNumbers;

    public FakeTitan(FakeTitanOptions? options = null)
    {
        var o = options ?? new FakeTitanOptions();
        for (int n = 1; n <= Math.Clamp(o.Fixtures, 1, 512); n++) levels[n] = 0;
        for (int n = 1; n <= Math.Clamp(o.Playbacks, 1, 600); n++) playbacks[n] = 0;
        userNumbers = o.UserNumbers;
    }

    /// <summary>Fake patch: 4 channels each (Red, Green, Blue, Dimmer) on universe 1.</summary>
    public static (int Universe, int Address) Address(int fixture) => (1, (fixture - 1) * 4 + 1);

    public int FixtureCount { get { lock (gate) return levels.Count; } }

    /// <summary>The fake fixtures' personality: Red, Green, Blue, Dimmer (dimmer on the 4th channel).</summary>
    public const string PersonalityXml = """
        <?xml version="1.0" encoding="utf-8"?>
        <Fixture Name="Fake RGBD" ShortName="Fake RGBD" Company="Fake Titan" Version="1">
          <Control>
            <Attribute ID="Dimmer" Name="Dimmer" Group="I" />
          </Control>
          <Mode Name="RGBD" Channels="4">
            <Include>
              <Attribute ID="Red" ChannelOffset="1" />
              <Attribute ID="Green" ChannelOffset="2" />
              <Attribute ID="Blue" ChannelOffset="3" />
              <Attribute ID="Dimmer" ChannelOffset="4" />
            </Include>
          </Mode>
        </Fixture>
        """;

    /// <summary>The patch report (Disk &gt; Reports, CSV) Titan would write for the fake fixtures.</summary>
    public string PatchReportCsv()
    {
        var csv = new System.Text.StringBuilder("Patch View\r\nUser No.,Fixture,Mode,Address,Legend\r\n");
        lock (gate)
        {
            foreach (var n in levels.Keys)
            {
                var (universe, address) = Address(n);
                csv.Append($"{n},Fake RGBD,\"RGBD, 4 DMX\",{universe}.{address},Fake {n}\r\n");
            }
        }
        return csv.ToString();
    }

    public int PlaybackCount { get { lock (gate) return playbacks.Count; } }

    /// <summary>Universe 1 as Fake Titan would send it over sACN.</summary>
    public byte[] Universe1()
    {
        var dmx = new byte[512];
        lock (gate)
        {
            foreach (var (n, level) in levels)
            {
                var start = Address(n).Address - 1;
                if (start + 4 > 512) continue;
                dmx[start] = 255;
                dmx[start + 1] = 180;
                dmx[start + 2] = 120;
                dmx[start + 3] = (byte)Math.Round(level * 2.55);
            }
        }
        return dmx;
    }

    /// <summary>As if the operator selected fixtures in Layouts (empty clears).</summary>
    public string DeskSelect(IEnumerable<int> fixtures)
    {
        lock (gate) return DeskSelectLocked(fixtures);
    }

    private string DeskSelectLocked(IEnumerable<int> fixtures)
    {
        users[FakeUser.Desk].Selected = fixtures.Where(levels.ContainsKey).Distinct().ToList();
        var now = users[FakeUser.Desk].Selected;
        return $"desk selection now {(now.Count == 0 ? "empty" : List(now))} (as if from Layouts)";
    }

    /// <summary>One line of state for the log: command lines, selections, lit fixtures, live playbacks.</summary>
    public string StatusLine()
    {
        lock (gate)
        {
            var lit = levels.Where(l => l.Value > 0).Select(l => $"{l.Key}:{Num(l.Value)}%");
            var live = playbacks.Where(p => p.Value > 0).Select(p => p.Key.ToString(CultureInfo.InvariantCulture));
            var api = users[FakeUser.Api];
            var desk = users[FakeUser.Desk];
            return $"line '{api.Line}' | selected {List(api.Selected, "-")} | desk line '{desk.Line}' desk selected " +
                   $"{List(desk.Selected, "-")} | levels {Join(lit)} | live playbacks {Join(live)}";
        }
    }

    // --- Requests ---------------------------------------------------------

    public FakeReply Handle(string path, string query, FakeUser user)
    {
        var q = ParseQuery(query);
        lock (gate)
        {
            var me = users[user];
            // Kept for the Mac version's curl habit: same as the Host window's "Select on desk".
            if (path == "/fake/desk-select") return new(200, null, DeskSelectLocked(Numbers(Get(q, "fixtures"))));
            switch (path)
            {
                case "/titan/handles/Fixtures":
                    return new(200, new JsonArray(levels.Keys.Select(n => (JsonNode)new JsonObject
                    {
                        ["handleLocation"] = new JsonObject { ["group"] = "Fixtures", ["index"] = n - 1, ["page"] = 0 },
                        ["properties"] = new JsonArray(new JsonObject { ["Key"] = "userNumber", ["Value"] = n }),
                        ["titanId"] = 5000 + n,
                        ["type"] = "fixtureHandle",
                        ["Active"] = false,
                        ["Legend"] = $"Fixture {n}",
                    }).ToArray()), null);
                case "/titan/get/2/Patch/CurrentDmxAssignment":
                    return patchCurrent is { } p
                        ? new(200, JsonValue.Create($"{p.Universe}.{p.Address}"), null)
                        : new(200, JsonValue.Create(""), "nothing copied into the patch editor");
                case "/titan/get/System/SoftwareVersion":
                    return new(200, JsonValue.Create(Version), null);
                case "/titan/get/2/Command/CommandLineText":
                    return new(200, JsonValue.Create(me.Line), null);
                case "/titan/handles/Playbacks":
                    return new(200, PlaybackHandles(), null);
                case "/titan/handles/Colours":
                    return new(200, SimpleHandles("Colours", ColourPalettes, 2000), null);
                case "/titan/handles/Workspaces":
                    return new(200, SimpleHandles("Workspaces", Workspaces, 3000), null);
            }
            if (!path.StartsWith(Script, StringComparison.Ordinal)) return new(404, null, "unknown path");
            var function = path[Script.Length..];

            switch (function)
            {
                case "Command/AppendStringAndPreview":
                    me.Line += Get(q, "text");
                    return new(200, null, $"command line now '{me.Line}'");
                case "Command/RunCommand":
                    return new(200, null, $"ran '{Get(q, "command")}': {RunCommand(me, Get(q, "command"))}");
                case "Command/StartNewCommand":
                    me.Line = "";
                    return new(200, null, "command line cleared");
                case "Reports/GenerateReport":
                    return new(200, null, "report written (Fake Titan's patch is read straight away)");
                case "Menu/ExitRootOrLatched":
                    return new(200, null, "exited menu");
                case "Playbacks/Editor/ClearAll":
                    me.Selected = [];
                    foreach (var n in levels.Keys.ToList()) levels[n] = 0;
                    return new(200, null, "programmer cleared");
                case "Programmer/Editor/Fixtures/IncrementDimmer":
                    return IncrementDimmer(me, q);
                case "Programmer/Editor/Fixtures/SetDimmerLevel":
                    return SetDimmer(me, q);
                case "Programmer/Editor/Fixtures/ClearSelectedControls":
                    if (me.Selected.Count == 0) return new(200, null, "release but nothing is selected");
                    foreach (var n in me.Selected)
                    {
                        if (held.Remove(n, out var before)) levels[n] = before;
                    }
                    return new(200, null, $"released fixture(s) {List(me.Selected)} over {Get(q, "releaseTime", "0")}s");
                case "Playbacks/Editor/CueSelection/SelectCueByNumber":
                    if (FromTitanId(Get(q, "handle_titanId")) is not { } cuePlayback)
                        return new(404, null, $"no playback with titanId {Get(q, "handle_titanId")}");
                    editing = cuePlayback;
                    return new(200, null, $"editing playback {cuePlayback}, cue {Get(q, "cueNumber", "1")}");
                case "Selection/Context/Global/SelectFixturesFromHandles":
                    me.Selected = Numbers(Get(q, "handleList_userNumberList")).Where(levels.ContainsKey).ToList();
                    return new(200, null, $"selected {List(me.Selected)} ({Who(user)} user)");
                case "Programmer/Editor/Fixtures/FlashOut":
                    foreach (var n in me.Selected)
                    {
                        flashed.TryAdd(n, levels[n]);
                        levels[n] = 0;
                    }
                    return new(200, null, $"flashed {List(me.Selected)} to zero");
                case "Programmer/Editor/Fixtures/ClearFlash":
                    foreach (var n in me.Selected)
                    {
                        if (flashed.Remove(n, out var before)) levels[n] = before;
                    }
                    return new(200, null, $"flash cleared on {List(me.Selected)}");
                case "Patch/Repatch/SetDmxAddressesFromSelectedFixture":
                    // TitanDeck must never drive Patch on the operator's own UI.
                    if (user == FakeUser.Desk)
                        return new(200, null, "PATCH CALLED ON THE DESK'S UI - TitanDeck shouldn't do this", Flagged: true);
                    if (me.Selected.Count == 0) return new(200, null, "patch: nothing selected");
                    patchCurrent = Address(me.Selected[0]);
                    return new(200, null, $"patch editor now holds fixture {me.Selected[0]}'s address " +
                                          $"{patchCurrent.Value.Universe}.{patchCurrent.Value.Address}");
                case "Playbacks/FirePlaybackAtLevel" or "Playbacks/ReleasePlayback" or "Playbacks/SetPlaybackLevel":
                    return Playback(function, q);
                case "Macros/Run":
                    return new(200, null, $"ran macro '{Get(q, "macroId")}'");
                case "Palette/ApplyPalette":
                    return ApplyPalette(me, q);
                case "Workspace/Apply":
                {
                    var raw = Get(q, "handle_userNumber");
                    if (!int.TryParse(raw, out var w) || w < 1 || w > Workspaces.Length)
                        return new(404, null, $"no workspace {raw} (1-{Workspaces.Length} exist)");
                    return new(200, null, $"workspace {w} '{Workspaces[w - 1]}' on screen");
                }
            }
            if (SelectionRead.IsMatch(function))
                return new(200, new JsonArray(me.Selected.Select(n => (JsonNode)JsonValue.Create(5000 + n)).ToArray()), null);
            return new(404, null, "Fake Titan doesn't know this function");
        }
    }

    /// <summary>POST /titan/set/2/...: only the cue fade times. Real Titan's
    /// body format isn't documented; this takes a bare number, or JSON with one.</summary>
    public FakeReply Set(string path, string body)
    {
        var name = path[(path.LastIndexOf('/') + 1)..];
        if (!path.StartsWith("/titan/set/2/Playbacks/Editor/Times/", StringComparison.Ordinal)
            || name is not ("CueFadeInTime" or "CueFadeOutTime"))
            return new(404, null, "Fake Titan can't set this property");
        lock (gate)
        {
            if (editing is not { } playback) return new(409, null, $"{name} with no cue selected (SelectCueByNumber first)");
            var text = body.Trim();
            double seconds;
            try
            {
                var node = JsonNode.Parse(text);
                var value = node is JsonObject o && o["value"] is { } v ? v : node;
                seconds = value!.GetValueKind() == JsonValueKind.String
                    ? double.Parse(value.GetValue<string>(), CultureInfo.InvariantCulture)
                    : value.GetValue<double>();
            }
            catch (Exception error) when (error is JsonException or FormatException or InvalidOperationException or NullReferenceException)
            {
                return new(400, null, $"body '{text}' isn't a number of seconds");
            }
            if (!cueTimes.TryGetValue(playback, out var times)) cueTimes[playback] = times = [];
            times[name] = seconds;
            return new(200, null, $"playback {playback} {name} = {Num(seconds)}s");
        }
    }

    public double Level(int fixture) { lock (gate) return levels.GetValueOrDefault(fixture); }
    public double PlaybackLevel(int playback) { lock (gate) return playbacks.GetValueOrDefault(playback); }
    public IReadOnlyList<int> Selected(FakeUser user) { lock (gate) return users[user].Selected.ToList(); }
    public double? CueTime(int playback, string name)
    {
        lock (gate) return cueTimes.TryGetValue(playback, out var t) && t.TryGetValue(name, out var s) ? s : null;
    }

    // --- Command line -----------------------------------------------------

    /// <summary>What the TitanDeck keypad can type: "1", "1@5", "1 @ 50".</summary>
    private string RunCommand(User me, string command)
    {
        var text = command.Replace(" ", "").ToUpperInvariant();
        var match = Command.Match(text);
        if (!match.Success || text.Length == 0) return $"didn't understand '{command}' (real Titan might)";
        var notes = new List<string>();
        if (match.Groups[1].Success)
        {
            var n = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
            if (!levels.ContainsKey(n)) return $"fixture {n} isn't patched (1-{levels.Count} are)";
            me.Selected = [n];
            notes.Add($"selected fixture {n}");
        }
        if (match.Groups[2].Success)
        {
            if (me.Selected.Count == 0) return "@ with nothing selected";
            var digits = match.Groups[2].Value;
            // Titan style: one digit is tens (@5 = 50%), two or three are literal.
            var percent = Math.Clamp(int.Parse(digits, CultureInfo.InvariantCulture) * (digits.Length == 1 ? 10 : 1), 0, 100);
            foreach (var n in me.Selected) levels[n] = percent;
            notes.Add($"set to {percent}%");
        }
        return string.Join(", ", notes);
    }

    private FakeReply IncrementDimmer(User me, Dictionary<string, string> q)
    {
        if (!TryNumber(Get(q, "value"), out var value)) return new(400, null, $"value '{Get(q, "value")}' isn't a number");
        if (me.Selected.Count == 0) return new(200, null, $"{Signed(value)} but nothing is selected");
        foreach (var n in me.Selected)
        {
            if (value < 0) held.TryAdd(n, levels[n]);
            levels[n] = Math.Clamp(levels[n] + value, 0, 100);
        }
        // The app assumes percent. If real Titan wants 0-1, the same request
        // would be 100x bigger, which is what the test plan asks you to watch for.
        return new(200, null, $"{Signed(value)}% on fixture(s) {List(me.Selected)} (assuming percent)");
    }

    private FakeReply SetDimmer(User me, Dictionary<string, string> q)
    {
        if (!TryNumber(Get(q, "level"), out var level)) return new(400, null, $"level '{Get(q, "level")}' isn't a number");
        if (me.Selected.Count == 0) return new(200, null, $"dimmer {Num(level)}% but nothing is selected");
        foreach (var n in me.Selected)
        {
            held.TryAdd(n, levels[n]);
            levels[n] = Math.Clamp(level, 0, 100);
        }
        return new(200, null, $"fixture(s) {List(me.Selected)} dimmer at {Num(level)}%");
    }

    private FakeReply Playback(string function, Dictionary<string, string> q)
    {
        var key = function.EndsWith("SetPlaybackLevel", StringComparison.Ordinal) ? "srcHandle_userNumber" : "handle_userNumber";
        int? n = q.ContainsKey("handle_titanId") ? FromTitanId(q["handle_titanId"])
            : int.TryParse(Get(q, key), out var number) ? number : null;
        if (n is not { } playback) return new(400, null, $"missing {key} or handle_titanId");
        if (!playbacks.ContainsKey(playback)) return new(404, null, $"no playback {playback} (1-{playbacks.Count} exist)");
        if (function.EndsWith("FirePlaybackAtLevel", StringComparison.Ordinal))
        {
            playbacks[playback] = TryNumber(Get(q, "level_level", "1"), out var fire) && fire != 0 ? fire : 1;
            return new(200, null, $"playback {playback} GO");
        }
        if (function.EndsWith("ReleasePlayback", StringComparison.Ordinal))
        {
            playbacks[playback] = 0;
            return new(200, null, $"playback {playback} released");
        }
        if (!TryNumber(Get(q, "level_level"), out var level)) return new(400, null, "missing level_level");
        playbacks[playback] = Math.Clamp(level, 0, 1);
        return new(200, null, $"playback {playback} fader at {Math.Round(playbacks[playback] * 100)}%");
    }

    private FakeReply ApplyPalette(User me, Dictionary<string, string> q)
    {
        if (!int.TryParse(Get(q, "handle_titanId"), out var id)) return new(400, null, "missing handle_titanId");
        var index = id - 2000;
        if (index < 0 || index >= ColourPalettes.Length) return new(404, null, $"no palette with titanId {id}");
        return me.Selected.Count == 0
            ? new(200, null, $"palette '{ColourPalettes[index]}' but nothing is selected")
            : new(200, null, $"palette '{ColourPalettes[index]}' on fixture(s) {List(me.Selected)}");
    }

    private JsonArray PlaybackHandles()
    {
        var handles = new JsonArray();
        int index = 0;
        foreach (var (n, level) in playbacks)
        {
            var properties = new JsonArray(new JsonObject { ["Key"] = "lockState", ["Value"] = "Unlocked" });
            if (userNumbers) properties.Add(new JsonObject { ["Key"] = "userNumber", ["Value"] = n });
            handles.Add(new JsonObject
            {
                ["handleLocation"] = new JsonObject { ["group"] = "Playbacks", ["index"] = index % 10, ["page"] = index / 10 },
                ["properties"] = properties,
                ["titanId"] = 1000 + n,
                ["type"] = "playbackHandle",
                ["Active"] = level > 0,
                ["Legend"] = $"Playback {n}",
            });
            index++;
        }
        return handles;
    }

    private static JsonArray SimpleHandles(string group, string[] legends, int firstId) =>
        new(legends.Select((legend, i) => (JsonNode)new JsonObject
        {
            ["handleLocation"] = new JsonObject { ["group"] = group, ["index"] = i, ["page"] = 0 },
            ["properties"] = new JsonArray(new JsonObject { ["Key"] = "userNumber", ["Value"] = i + 1 }),
            ["titanId"] = firstId + i,
            ["type"] = group == "Colours" ? "paletteHandle" : "workspaceHandle",
            ["Active"] = false,
            ["Legend"] = legend,
        }).ToArray());

    private int? FromTitanId(string raw) =>
        int.TryParse(raw, out var id) && playbacks.ContainsKey(id - 1000) ? id - 1000 : null;

    // --- Helpers ----------------------------------------------------------

    /// <summary>"a=1&amp;b=x%20y" -> {a: 1, b: x y}; the first of a repeated key wins.</summary>
    public static Dictionary<string, string> ParseQuery(string query)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var part in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var eq = part.IndexOf('=');
            var key = Decode(eq < 0 ? part : part[..eq]);
            var value = eq < 0 ? "" : Decode(part[(eq + 1)..]);
            result.TryAdd(key, value);
        }
        return result;

        static string Decode(string text) => Uri.UnescapeDataString(text.Replace('+', ' '));
    }

    private static string Get(Dictionary<string, string> q, string key, string fallback = "") =>
        q.TryGetValue(key, out var value) ? value : fallback;

    private static List<int> Numbers(string text) =>
        text.Replace(" ", "").Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(x => int.TryParse(x, out var n) ? n : (int?)null).OfType<int>().ToList();

    private static bool TryNumber(string text, out double value) =>
        double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value);

    private static string Num(double value) => value.ToString("0.###", CultureInfo.InvariantCulture);
    private static string Signed(double value) => (value >= 0 ? "+" : "") + Num(value);
    private static string List(IEnumerable<int> numbers, string empty = "[]") =>
        numbers.Any() ? "[" + string.Join(", ", numbers) + "]" : empty;
    private static string Join(IEnumerable<string> items) => items.Any() ? string.Join(" ", items) : "-";
    private static string Who(FakeUser user) => user == FakeUser.Desk ? "desk" : "api";
}
