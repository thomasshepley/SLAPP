// App/DeskKeys.swift
import Foundation

/// The deck's keypad typed on the Titan PC as if on its own keyboard, so it
/// lands on the desk's command line and the selection shows on the desk
/// (Titan 19's WebAPI is a separate user with its own selection). Titan
/// captures the PC keyboard while it runs; its shortcuts: number keys,
/// number-pad * = @, / = Thro, + = And, - = Not, Enter, Esc = Exit. Never
/// Alt shortcuts: Alt+C for Clear left the desk's own Clear and wheels not
/// working, and Titan 19 ignored Alt+C and RIG's Alt+arrows (0.35) anyway, so
/// CLEAR goes through the Host (CITP) and RIG types fixture numbers.
/// TitanDeck Host types them (Host 0.10+), or the remote desktop does when
/// it's connected.
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

    /// The keys with every level command ("@ 64 Enter" on its own) dropped
    /// when another comes straight after it, so only the newest level is
    /// typed: fewer keys in a row for Titan to miss (a missed "@" or Enter
    /// turned a level into a fixture number). Keep in step with the Host's
    /// `DeskKeys.Coalesce`.
    static func coalesced(_ keys: [String]) -> [String] {
        var commands: [[String]] = []
        var current: [String] = []
        for key in keys {
            current.append(key)
            if key == "enter" {
                commands.append(current)
                current = []
            }
        }
        if !current.isEmpty { commands.append(current) }
        func isLevel(_ command: [String]) -> Bool {
            command.count >= 3 && command.first == "@" && command.last == "enter"
                && command.dropFirst().dropLast().allSatisfy { $0.count == 1 && $0.first?.isASCII == true && $0.first?.isNumber == true }
        }
        var kept: [String] = []
        for (index, command) in commands.enumerated() {
            if isLevel(command), index + 1 < commands.count, isLevel(commands[index + 1]) { continue }
            kept += command
        }
        return kept
    }

    /// Fixtures selected on the desk's command line: "1 THRU 10 AND 15
    /// Enter" (runs of three or more as THRU). Empty for no fixtures.
    static func selecting(_ fixtures: [Int]) -> [String] {
        let numbers = Array(Set(fixtures.filter { $0 > 0 })).sorted()
        guard !numbers.isEmpty else { return [] }
        var runs: [ClosedRange<Int>] = []
        for number in numbers {
            if let last = runs.last, last.upperBound + 1 == number {
                runs[runs.count - 1] = last.lowerBound ... number
            } else {
                runs.append(number ... number)
            }
        }
        var keys: [String] = []
        for run in runs {
            if !keys.isEmpty { keys.append("and") }
            let digits = { (n: Int) in String(n).map(String.init) }
            switch run.count {
            case 1: keys += digits(run.lowerBound)
            case 2: keys += digits(run.lowerBound) + ["and"] + digits(run.upperBound)
            default: keys += digits(run.lowerBound) + ["thro"] + digits(run.upperBound)
            }
        }
        return keys + ["enter"]
    }

    /// One level of a faded flash typed on the desk: `percent` at `at` seconds
    /// after the press.
    struct RampStep: Equatable {
        let at: Double
        let percent: Double
    }

    /// A flash fade typed on the desk as levels in steps (Titan's keyboard has
    /// no fade time): about three a second, which is how fast the PC types
    /// "@ 50 Enter" steadily (0.35-0.37 typed five a second and Titan missed
    /// the odd key), at most 12, whole percents, ending exactly on `to`. The
    /// first step goes straight away.
    static func rampSteps(from: Double, to: Double, seconds: Double) -> [RampStep] {
        let count = max(1, min(Int(seconds / 0.35), 12))
        var steps: [RampStep] = []
        for index in 1 ... count {
            let percent = min(max((from + (to - from) * Double(index) / Double(count)).rounded(), 0), 100)
            guard percent != (steps.last?.percent ?? from.rounded()) else { continue }   // never the same level twice
            steps.append(RampStep(at: seconds * Double(index - 1) / Double(count), percent: percent))
        }
        return steps
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
