using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace TitanDeckHost.Core.Titan;

/// <summary>One request to Titan's WebAPI on this PC: a path with its query, and a JSON body for a set.</summary>
public sealed record TitanCall(string Method, string PathAndQuery, string? Body = null)
{
    public static TitanCall Script(string function, params (string Name, string Value)[] query) =>
        new("GET", "/titan/script/2/" + function + (query.Length == 0 ? ""
            : "?" + string.Join("&", query.Select(q => Uri.EscapeDataString(q.Name) + "=" + Uri.EscapeDataString(q.Value)))));
}

/// <summary>One way of doing something on Titan: its calls, in order.</summary>
public sealed record TitanAttempt(string Name, IReadOnlyList<TitanCall> Calls);

/// <summary>
/// The Titan 19 calls behind TitanDeck's cue fade and Clear keys, run by the
/// Host (so a better way only needs a Host update, not a new TitanDeck).
/// Titan 19's WebAPI (4430) is a separate user with its own editor and
/// selection; cue times are the show's, so any user's editor can change them.
/// Pure (no I/O), so it's tested.
/// </summary>
public static class TitanRecipes
{
    public static string FadeProperty(bool fadeOut) => fadeOut ? "CueFadeOutTime" : "CueFadeInTime";

    /// <summary>Reads a cue time of the cue in the editor.</summary>
    public static TitanCall ReadFade(bool fadeOut) => new("GET", "/titan/get/2/Playbacks/Editor/Times/" + FadeProperty(fadeOut));

    /// <summary>
    /// Opens cue 1 of a playback for its times, as the desk's Edit Times and
    /// Titan's own cue-time macros do: the playback into the editor, the times
    /// menu filled for it, then the cue selected.
    /// </summary>
    public static IReadOnlyList<TitanCall> OpenCue(int titanId) =>
    [
        TitanCall.Script("ActionScript/SetProperty", ("id", "Playbacks.Editor.SelectedPlayback"), ("value_titanId", Id(titanId))),
        TitanCall.Script("Playbacks/TimesEdit/FillTimes", ("handle_titanId", Id(titanId))),
        TitanCall.Script("Playbacks/Editor/CueSelection/SelectCueByNumber", ("handle_titanId", Id(titanId)), ("cueNumber", "1")),
    ];

    /// <summary>
    /// The ways to set a cue's fade, safest first: the property setters,
    /// then Titan's command line on the connected playback ("CUE 1 TIME 2"),
    /// then the JSON set in the shape Titan reads the time in (last: a body
    /// Titan takes but can't read may leave the time at zero).
    /// </summary>
    /// <param name="otherSeconds">The cue's other time (fade in when setting
    /// the fade out), for the command line's "TIME in AND out".</param>
    public static IReadOnlyList<TitanAttempt> CueFadeAttempts(int titanId, bool fadeOut, double seconds, double? otherSeconds, string? current)
    {
        var id = "Playbacks.Editor.Times." + FadeProperty(fadeOut);
        var value = Number(seconds);
        var attempts = new List<TitanAttempt>
        {
            new("SetProperty value_time", [TitanCall.Script("ActionScript/SetProperty", ("id", id), ("value_time", value))]),
            new("SetProperty.Float", [TitanCall.Script("ActionScript/SetProperty/Float", ("id", id), ("value", value))]),
            new("SetProperty.Double", [TitanCall.Script("ActionScript/SetProperty/Double", ("id", id), ("value", value))]),
        };
        // Never CueSelection.SelectAll: on a cue list it would retime every cue.
        if (!fadeOut || otherSeconds is not null)
        {
            var times = fadeOut ? $"{Number(otherSeconds!.Value)} AND {value}" : value;
            attempts.Add(new("command line CUE 1 TIME " + times,
            [
                TitanCall.Script("ConnectedPlayback/Connect", ("handle_titanId", Id(titanId))),
                TitanCall.Script("Command/StartNewCommand"),
                TitanCall.Script("Command/RunCommand", ("command", "CUE 1 TIME " + times)),
                TitanCall.Script("Command/StartNewCommand"),
            ]));
        }
        if (current is not null && Shaped(seconds, current) is { } body)
            attempts.Add(new("JSON " + body, [new TitanCall("POST", "/titan/set/2/Playbacks/Editor/Times/" + FadeProperty(fadeOut), body)]));
        return attempts;
    }

    /// <summary>How the Host goes about TitanDeck's CLEAR.</summary>
    public enum ClearPlan
    {
        /// The desk has nothing selected (CITP): nothing to do.
        AlreadyClear,
        /// Tell Titan over CITP that nothing is selected, as Capture would.
        CitpClear,
        /// No CITP link: only the WebAPI's clears.
        WebApiOnly,
    }

    /// <summary>
    /// The CITP clear when CITP is linked and shows the desk has a selection
    /// (it's also how the result is checked). Host 0.14.1-0.14.3 typed Alt+C
    /// on the desk instead; on Titan 19 it didn't clear the selection.
    /// </summary>
    public static ClearPlan PlanClear(bool citpLinked, int deskSelected) =>
        !citpLinked ? ClearPlan.WebApiOnly
        : deskSelected == 0 ? ClearPlan.AlreadyClear
        : ClearPlan.CitpClear;

    /// <summary>Clears the selection for every user, the desk's included, and never a programmer.</summary>
    public static IReadOnlyList<TitanAttempt> ClearSelectionAttempts() =>
    [
        new("ClearSelection, every user",
            [TitanCall.Script("Programmer/Editor/ClearSelection", ("disable", "false"), ("clearAllProgrammers", "true"))]),
        new("Playbacks.Editor.ClearSelection, every user",
            [TitanCall.Script("Playbacks/Editor/ClearSelection", ("disable", "false"), ("clearAllProgrammers", "true"))]),
    ];

    /// <summary>
    /// A cue time in seconds from how Titan reads it: Titan 19's
    /// {"TimeType":0,"TimeValue":"00:00:02.5","TotalSeconds":2.5,...}, a bare
    /// number, or a TimeSpan string. Null when it can't tell.
    /// </summary>
    public static double? Seconds(string json)
    {
        JsonNode? node;
        try { node = JsonNode.Parse(json); }
        catch (JsonException) { return null; }
        return Seconds(node);
    }

    private static double? Seconds(JsonNode? node)
    {
        switch (node)
        {
            case JsonValue value when value.TryGetValue(out double number):
                return number;
            case JsonValue value when value.TryGetValue(out string? text):
                return TimeSpan.TryParse(text, CultureInfo.InvariantCulture, out var span) ? span.TotalSeconds
                    : double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var n) ? n : null;
            case JsonObject obj:
                foreach (var key in new[] { "TotalSeconds", "Seconds" })
                    if (Find(obj, key) is JsonValue v && v.TryGetValue(out double s)) return s;
                foreach (var key in new[] { "TimeValue", "Time", "Value", "TimeOrDefault" })
                    if (Seconds(Find(obj, key)) is { } s) return s;
                if (Find(obj, "Ticks") is JsonValue t && t.TryGetValue(out long ticks)) return ticks / 10_000_000.0;
                return null;
            default:
                return null;
        }
    }

    /// <summary>The time Titan read, with the new seconds in its time fields
    /// (TimeType and the rest left as they were). Null if it isn't an object.</summary>
    public static string? Shaped(double seconds, string current)
    {
        JsonObject? obj;
        try { obj = JsonNode.Parse(current) as JsonObject; }
        catch (JsonException) { return null; }
        if (obj is null) return null;
        var text = TimeText(seconds);
        foreach (var (key, _) in obj.ToList())
        {
            if (key.Equals("TotalSeconds", StringComparison.OrdinalIgnoreCase) || key.Equals("Seconds", StringComparison.OrdinalIgnoreCase))
                obj[key] = seconds;
            else if (key.Equals("TimeValue", StringComparison.OrdinalIgnoreCase) || key.Equals("TimeOrDefault", StringComparison.OrdinalIgnoreCase))
                obj[key] = text;
            else if (key.Equals("HasValue", StringComparison.OrdinalIgnoreCase))
                obj[key] = true;
        }
        return obj.ToJsonString();
    }

    /// <summary>"00:00:02.5", the way Titan writes a time.</summary>
    public static string TimeText(double seconds)
    {
        var span = TimeSpan.FromMilliseconds(Math.Round(Math.Max(seconds, 0) * 1000));
        var text = $"{(int)span.TotalHours:00}:{span.Minutes:00}:{span.Seconds:00}";
        return span.Milliseconds == 0 ? text : text + "." + span.Milliseconds.ToString("000").TrimEnd('0');
    }

    /// <summary>Seconds without trailing zeros, with a dot ("2", "2.5").</summary>
    public static string Number(double value) => Math.Round(value, 3).ToString("0.###", CultureInfo.InvariantCulture);

    private static string Id(int titanId) => titanId.ToString(CultureInfo.InvariantCulture);

    private static JsonNode? Find(JsonObject obj, string key) =>
        obj.FirstOrDefault(p => p.Key.Equals(key, StringComparison.OrdinalIgnoreCase)).Value;
}
