using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace TitanDeckHost.Core.Titan;

/// <summary>How a layer's pixel map group changes (TitanDeck's FX page).</summary>
public enum FxGroupMode
{
    /// The group becomes exactly the fixtures given (USE SEL).
    Replace,
    /// The fixtures given join the group (ADD).
    Add,
    /// The fixtures given leave the group (REMOVE).
    Remove,
    /// The group becomes another group's fixtures (an FXZone group).
    Zone,
}

/// <summary>
/// The Titan 19 calls behind TitanDeck's FX page (Host 0.16, Test mode):
/// Prism layers are Titan fixtures ("Layer 1", "Layer 2") whose controls
/// (Dimmer, Colour Adjust, Gobo: Folder / File / Playmode / Speed) are set on
/// the WebAPI user's programmer, and each layer's pixel map follows a group,
/// so the layer's fixtures change by replacing that group. All on the 4430
/// user, whose selection is put back to the desk's afterwards. Pure (no
/// I/O), so it's tested.
/// </summary>
public static class FxRecipes
{
    public static TitanCall ClearSelection() => TitanCall.Script("Selection/Context/Global/Clear");

    /// <summary>Fixtures by user number (the numbers on the desk).</summary>
    public static TitanCall SelectFixtures(IEnumerable<int> userNumbers) =>
        TitanCall.Script("Selection/Context/Global/SelectFixturesFromHandles", ("handleList_userNumberList", List(userNumbers)));

    /// <summary>Fixtures by Titan id (as Titan reads a selection back).</summary>
    public static TitanCall SelectTitanIds(IEnumerable<int> titanIds) =>
        TitanCall.Script("Selection/Context/Global/SelectFixturesWithTitanIds", ("titanIds", List(titanIds)));

    /// <summary>The selection as Titan ids (every selected fixture, not just a pattern's).</summary>
    public static TitanCall ReadSelection() => TitanCall.Script("Selection/Context/Global/GetAllSelectedFixtureIds");

    /// <summary>A group, by its number, onto the (cleared) selection.</summary>
    public static TitanCall RecallGroup(int userNumber) =>
        TitanCall.Script("Group/RecallGroupNumeric", ("userId", Id(userNumber)));

    /// <summary>A group by its handle's Titan id (the FXZone groups, found by legend).</summary>
    public static TitanCall RecallGroupHandle(int titanId) =>
        TitanCall.Script("Group/RecallGroup", ("handle_titanId", Id(titanId)));

    /// <summary>The ways to make a group the selection, tried in turn and each checked.</summary>
    public static IReadOnlyList<TitanAttempt> ReplaceGroupAttempts(int userNumber) =>
    [
        new("ReplaceGroupOnHandle", [TitanCall.Script("Group/ReplaceGroupOnHandle", ("handle_userNumber", Id(userNumber)))]),
        new("StoreGroupReplace", [TitanCall.Script("Group/StoreGroupReplace", ("groupId", Id(userNumber)))]),
    ];

    /// <summary>
    /// The ways to set a control on the selected fixtures into the programmer:
    /// by name with the function named like the control (Titan's attribute
    /// editor shows one function for a plain control), then with no function.
    /// </summary>
    public static IReadOnlyList<TitanAttempt> SetControlAttempts(string control, double value)
    {
        TitanCall Set(string function) => TitanCall.Script("Programmer/Editor/Fixtures/SetControlValueByName",
            ("controlName", control), ("functionName", function), ("value", TitanRecipes.Number(value)),
            ("programmer", "true"), ("createRestorePoint", "false"));
        return
        [
            new($"{control} = {TitanRecipes.Number(value)}", [Set(control)]),
            new($"{control} = {TitanRecipes.Number(value)} (no function name)", [Set("")]),
        ];
    }

    /// <summary>Lets go of the selected fixtures' controls in the programmer, straight away.</summary>
    public static TitanCall Release() =>
        TitanCall.Script("Programmer/Editor/Fixtures/ClearSelectedControls", ("release", "true"), ("releaseTime", "0"));

    /// <summary>A control's id on the selected fixture (the probe: which names the layer has).</summary>
    public static TitanCall ControlId(string name) =>
        TitanCall.Script("Programmer/Editor/Fixtures/GetControlIdFromName", ("controlName", name));

    /// <summary>Names the probe asks about, as well as any the iPad is set to use.</summary>
    public static readonly IReadOnlyList<string> ProbeNames =
    [
        "Dimmer", "Intensity", "Folder", "File", "Playmode", "Play Mode", "Speed",
        "Brightness", "Contrast", "Saturation", "Hue", "Hue Offset", "Gamma", "Red", "Green", "Blue",
        "Colour Adjust", "Color Adjust", "X", "Y", "Zoom", "Scale",
    ];

    /// <summary>The group's fixtures after the change (Titan ids, in order, once each).</summary>
    public static IReadOnlyList<int> Plan(FxGroupMode mode, IReadOnlyList<int> current, IReadOnlyList<int> given) => mode switch
    {
        FxGroupMode.Add => current.Concat(given).Distinct().ToList(),
        FxGroupMode.Remove => current.Where(id => !given.Contains(id)).Distinct().ToList(),
        _ => given.Distinct().ToList(),
    };

    public static bool SameFixtures(IEnumerable<int> a, IEnumerable<int> b) => a.ToHashSet().SetEquals(b);

    /// <summary>"replace", "add", "remove" or "zone"; null for anything else.</summary>
    public static FxGroupMode? Mode(string? text) => text?.ToLowerInvariant() switch
    {
        "replace" => FxGroupMode.Replace,
        "add" => FxGroupMode.Add,
        "remove" => FxGroupMode.Remove,
        "zone" => FxGroupMode.Zone,
        _ => null,
    };

    /// <summary>
    /// Titan ids from Titan's answer to a selection read: a JSON list of
    /// numbers, or of objects with an id. Null if it isn't a list.
    /// </summary>
    public static IReadOnlyList<int>? Ids(string json)
    {
        JsonNode? node;
        try { node = JsonNode.Parse(json); }
        catch (JsonException) { return null; }
        if (node is not JsonArray list) return null;
        var ids = new List<int>();
        foreach (var item in list)
        {
            var value = item switch
            {
                JsonValue v when v.TryGetValue(out int n) => n,
                JsonValue v when v.TryGetValue(out double d) && d == Math.Floor(d) => (int)d,
                JsonObject o => (o.FirstOrDefault(p => p.Key.Equals("titanId", StringComparison.OrdinalIgnoreCase)
                                                    || p.Key.Equals("id", StringComparison.OrdinalIgnoreCase)).Value as JsonValue)
                                is { } inner && inner.TryGetValue(out int m) ? m : (int?)null,
                _ => (int?)null,
            };
            if (value is > 0) ids.Add(value.Value);
        }
        return ids;
    }

    /// <summary>A control id from GetControlIdFromName's answer; null when the fixture hasn't got it.</summary>
    public static int? ControlIdFrom(string answer) =>
        int.TryParse(answer.Trim().Trim('"'), NumberStyles.Integer, CultureInfo.InvariantCulture, out var id) && id >= 0 ? id : null;

    private static string List(IEnumerable<int> numbers) =>
        string.Join(",", numbers.Distinct().Select(n => n.ToString(CultureInfo.InvariantCulture)));

    private static string Id(int number) => number.ToString(CultureInfo.InvariantCulture);
}
