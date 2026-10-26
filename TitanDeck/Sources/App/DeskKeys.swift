// App/DeskKeys.swift
import Foundation

/// The deck's keypad typed on the Titan PC as if on its own keyboard, so it
/// lands on the desk's command line and the selection shows on the desk
/// (Titan 19's WebAPI is a separate user with its own selection). Titan
/// captures the PC keyboard while it runs; its shortcuts: number keys,
/// number-pad * = @, / = Thro, + = And, - = Not, Enter, Esc = Exit. Never
/// Alt shortcuts: typing Alt+C for Clear left the desk's own Clear and wheels
/// not working, so Clear goes through the WebAPI (every programmer) after an
/// Exit to back out what's typed. TitanDeck Host types them (Host 0.10+), or the remote
/// desktop does when it's connected. Keep the names and keys in step with
/// TitanDeckHost/src/Core/Titan/DeskKeys.cs. Pure, so it's tested.
enum DeskKeys {
    /// The Host's names for the keys an action types, or nil for one that isn't a keypad key.
    static func names(for action: TitanAction) -> [String]? {
        switch action {
        case .keypadDigit(let digit): ["\(min(max(digit, 0), 9))"]
        case .keypadAt: ["@"]
        case .keypadThro: ["thro"]
        case .keypadEnter: ["enter"]
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
        guard let scancode = table[name] else { return [] }
        return RDPTyping.tap(scancode, holding: [])
    }

    static let table: [String: UInt32] = [
        "1": 0x02, "2": 0x03, "3": 0x04, "4": 0x05, "5": 0x06,
        "6": 0x07, "7": 0x08, "8": 0x09, "9": 0x0A, "0": 0x0B,
        ".": 0x34,
        "@": 0x37,       // * on the number pad
        "thro": 0x135,   // / on the number pad
        "and": 0x4E,     // + on the number pad
        "not": 0x4A,     // - on the number pad
        "enter": 0x1C,
        "exit": 0x01,    // Esc
        "backspace": 0x0E,
    ]

    /// The fixtures a keypad line names before its "@": "101@50" is [101],
    /// "1 THRU 3@50" is [1, 2, 3]. Nil when it names none ("@50").
    static func typedFixtures(_ line: String) -> [Int]? {
        let text = line.replacingOccurrences(of: " THRU ", with: ">").replacingOccurrences(of: " ", with: "")
        let before = String(text.prefix { $0 != "@" })
        return before.isEmpty ? nil : DeckFlow.KeypadBuffer.fixtures(in: before)
    }

    /// A nudge on top of the current level, both in percent: 40 + 10 is 50,
    /// kept to 0...100 and whole numbers.
    static func nudged(_ current: Double, by percent: Double) -> Double {
        min(max(current + percent, 0), 100).rounded()
    }

    /// The level a keypad line sets, in percent: "101@50" is 50, "@@" full.
    /// Nil for no level, or a single digit (5% or 50% by Titan's user setting).
    static func typedLevel(_ line: String) -> Double? {
        let text = line.replacingOccurrences(of: " ", with: "")
        if text.hasSuffix("@@") { return 100 }
        guard let at = text.lastIndex(of: "@") else { return nil }
        let digits = text[text.index(after: at)...]
        guard digits.count >= 2, digits.allSatisfy(\.isNumber), let value = Double(digits) else { return nil }
        return min(value, 100)
    }
}
