namespace TitanDeckHost.Core.Titan;

/// <summary>
/// The deck's keypad typed on the Titan PC as if on its own keyboard, so it
/// lands on the desk's command line and the selection shows on the desk.
/// Titan captures the PC keyboard while it runs; its shortcuts (Avolites
/// manual, Front panel buttons, keyboard shortcuts): number keys, number-pad
/// * = @, / = Thro, + = And, - = Not, Enter, Esc = Exit.
/// Only these keys can be sent: a paired iPad can't type anything else on the PC.
/// Never Alt or any modifier: after Host 0.11 typed Alt+C (Clear) the desk's
/// own Clear and wheels stopped working, and Host 0.14.1-0.14.3's Alt+C didn't
/// clear Titan 19's selection anyway. TitanDeck's CLEAR goes over CITP.
/// Scan codes are PC set 1 (Extended = the E0 prefix). Keep in step with
/// TitanDeck's DeskKeys.swift.
/// </summary>
public static class DeskKeys
{
    public sealed record Key(ushort Scancode, bool Extended = false);

    public const int MaxPerRequest = 32;

    public static readonly IReadOnlyDictionary<string, Key> All = new Dictionary<string, Key>
    {
        ["1"] = new(0x02), ["2"] = new(0x03), ["3"] = new(0x04), ["4"] = new(0x05), ["5"] = new(0x06),
        ["6"] = new(0x07), ["7"] = new(0x08), ["8"] = new(0x09), ["9"] = new(0x0A), ["0"] = new(0x0B),
        ["."] = new(0x34),
        ["@"] = new(0x37),                     // * on the number pad
        ["thro"] = new(0x35, Extended: true),  // / on the number pad
        ["and"] = new(0x4E),                   // + on the number pad
        ["not"] = new(0x4A),                   // - on the number pad
        ["enter"] = new(0x1C),
        ["exit"] = new(0x01),                  // Esc
        ["backspace"] = new(0x0E),
    };

    /// <summary>Why these keys can't be typed, or null when they all can.</summary>
    public static string? Problem(IReadOnlyList<string>? keys)
    {
        if (keys is null || keys.Count == 0) return "No keys.";
        if (keys.Count > MaxPerRequest) return $"At most {MaxPerRequest} keys at a time.";
        var unknown = keys.FirstOrDefault(k => !All.ContainsKey(k));
        return unknown is null ? null : $"\"{unknown}\" isn't a keypad key TitanDeck Host types.";
    }
}
