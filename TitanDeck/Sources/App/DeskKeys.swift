// App/DeskKeys.swift
import Foundation

/// The deck's keypad typed on the Titan PC as if on its own keyboard, so it
/// lands on the desk's command line and the selection shows on the desk
/// (Titan 19's WebAPI is a separate user with its own selection). Titan
/// captures the PC keyboard while it runs; its shortcuts: number keys,
/// number-pad * = @, / = Thro, + = And, - = Not, Enter, Esc = Exit. No other
/// Alt shortcuts than RIG's (`shortcuts`, the user's call in 0.35): typing
/// Alt+C for Clear left the desk's own Clear and wheels not working, so CLEAR
/// goes through the Host (CITP). TitanDeck Host types them (Host 0.10+; the
/// RIG shortcuts 0.15.1+), or the remote desktop does when it's connected.
/// Keep the names and keys in step with
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

    /// RIG's keys as Titan's own Alt shortcuts (Alt+Right next fixture,
    /// Alt+Left previous, Alt+Down Highlight), so they step the desk's own
    /// selection. Nil for any other action.
    static func shortcut(for action: TitanAction) -> [String]? {
        switch action {
        case .nextFixture: ["next"]
        case .previousFixture: ["prev"]
        case .toggleHighlight: ["highlight"]
        default: nil
        }
    }

    /// One level of a faded flash typed on the desk: `percent` at `at` seconds
    /// after the press.
    struct RampStep: Equatable {
        let at: Double
        let percent: Double
    }

    /// A flash fade typed on the desk as levels in steps (Titan's keyboard has
    /// no fade time): about five a second, as fast as "@ 50 Enter" is typed,
    /// whole percents, ending exactly on `to`. The first step goes straight away.
    static func rampSteps(from: Double, to: Double, seconds: Double) -> [RampStep] {
        let count = max(1, min(Int(seconds / 0.2), 20))
        var steps: [RampStep] = []
        for index in 1 ... count {
            let percent = min(max((from + (to - from) * Double(index) / Double(count)).rounded(), 0), 100)
            guard percent != (steps.last?.percent ?? from.rounded()) else { continue }   // never the same level twice
            steps.append(RampStep(at: seconds * Double(index - 1) / Double(count), percent: percent))
        }
        return steps
    }

    /// The arrow key of each shortcut (set-1 scan codes, 0x100 = extended); Alt is held for it.
    static let shortcuts: [String: UInt32] = [
        "next": 0x14D,        // Right
        "prev": 0x14B,        // Left
        "highlight": 0x150,   // Down
    ]

    /// Left Alt.
    static let alt: UInt32 = 0x38

    /// "@ <level> Enter", for a level in percent (0-100, whole numbers):
    /// the selection to that level on the desk's own command line.
    static func level(_ percent: Double) -> [String] {
        let whole = Int(min(max(percent, 0), 100).rounded())
        return ["@"] + String(whole).map(String.init) + ["enter"]
    }

    /// The same key as remote desktop keystrokes (set-1 scan codes, 0x100 = extended).
    static func strokes(for name: String) -> [RDPKeyStroke] {
        if let arrow = shortcuts[name] { return RDPTyping.tap(arrow, holding: [alt]) }
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
