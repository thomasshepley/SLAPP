// App/DeskKeys.swift
import Foundation

/// The deck's keypad typed on the Titan PC as if on its own keyboard, so it
/// lands on the desk's command line and the selection shows on the desk
/// (Titan 19's WebAPI is a separate user with its own selection). Titan
/// captures the PC keyboard while it runs; its shortcuts: number keys,
/// number-pad * = @, / = Thro, + = And, - = Not, Enter, Esc = Exit,
/// Alt+C = Clear. TitanDeck Host types them (Host 0.10+), or the remote
/// desktop does when it's connected. Keep the names and keys in step with
/// TitanDeckHost/src/Core/Titan/DeskKeys.cs. Pure, so it's tested.
enum DeskKeys {
    /// The Host's names for the keys an action types, or nil for one that isn't a keypad key.
    static func names(for action: TitanAction) -> [String]? {
        switch action {
        case .keypadDigit(let digit): ["\(min(max(digit, 0), 9))"]
        case .keypadAt: ["@"]
        case .keypadEnter: ["enter"]
        case .keypadClear: ["clear"]
        case .keypadExit: ["exit"]
        default: nil
        }
    }

    /// "@ <level> Enter", for a level in percent (0-100, whole numbers):
    /// the selection to that level on the desk's own command line.
    static func level(_ percent: Double) -> [String] {
        let whole = Int(min(max(percent, 0), 100).rounded())
        return ["@"] + String(whole).map(String.init) + ["enter"]
    }

    /// The same key as remote desktop keystrokes (set-1 scan codes, 0x100 = extended).
    static func strokes(for name: String) -> [RDPKeyStroke] {
        guard let key = table[name] else { return [] }
        return RDPTyping.tap(key.scancode, holding: key.alt ? [RDPTyping.alt] : [])
    }

    static let table: [String: (scancode: UInt32, alt: Bool)] = [
        "1": (0x02, false), "2": (0x03, false), "3": (0x04, false), "4": (0x05, false), "5": (0x06, false),
        "6": (0x07, false), "7": (0x08, false), "8": (0x09, false), "9": (0x0A, false), "0": (0x0B, false),
        ".": (0x34, false),
        "@": (0x37, false),       // * on the number pad
        "thro": (0x135, false),   // / on the number pad
        "and": (0x4E, false),     // + on the number pad
        "not": (0x4A, false),     // - on the number pad
        "enter": (0x1C, false),
        "exit": (0x01, false),    // Esc
        "clear": (0x2E, true),    // Alt+C
        "backspace": (0x0E, false),
    ]
}
