// Remote/KeypadReadout.swift
import Foundation

/// What's been typed on the deck's Avolites keypad, for the readout under the
/// remote desktop: the line being typed ("102@30"), and the last few lines
/// sent with Enter. Built from the key presses themselves, so it shows
/// instantly and doesn't depend on reading Titan's command line back.
struct KeypadReadout: Equatable {
    struct Entry: Identifiable, Equatable {
        enum Delivery: Equatable {
            /// Keys sent, answers not all back yet.
            case sending
            case sent
            /// At least one key didn't reach Titan, so its command line may differ.
            case failed
        }

        let id: UUID
        var text: String
        var delivery: Delivery = .sending
        /// Keys sent for this line that Titan hasn't answered yet.
        fileprivate var outstanding = 0
        fileprivate var anyFailed = false
    }

    static let historyLimit = 3
    /// Longer than any real command; stops a stuck key filling the screen.
    static let maxLength = 32

    /// The line being typed, nil when nothing has been typed since the last
    /// Enter, Clear or Exit.
    private(set) var current: Entry?
    /// Lines sent with Enter, oldest first, newest last.
    private(set) var history: [Entry] = []

    /// True for the keys that build or end a command line.
    static func isKeypad(_ action: TitanAction) -> Bool {
        switch action {
        case .keypadDigit, .keypadAt, .keypadEnter, .keypadClear, .keypadExit: return true
        default: return false
        }
    }

    /// Applies a key press. Returns the id of the line it belongs to (to report
    /// Titan's answer with `markAnswered`), or nil if it wasn't a keypad key or
    /// changed nothing.
    @discardableResult
    mutating func press(_ action: TitanAction, makeID: () -> UUID = UUID.init) -> UUID? {
        switch action {
        case .keypadDigit(let digit):
            return type(String(digit), makeID: makeID)
        case .keypadAt:
            return type("@", makeID: makeID)
        case .keypadEnter:
            guard var line = current else { return nil }   // Enter on an empty line: nothing to show
            line.outstanding += 1
            line.delivery = .sending
            current = nil
            history.append(line)
            if history.count > Self.historyLimit { history.removeFirst(history.count - Self.historyLimit) }
            return line.id
        case .keypadClear, .keypadExit:
            current = nil
            return nil
        default:
            return nil
        }
    }

    /// Titan answered one of a line's key presses.
    mutating func markAnswered(_ id: UUID, ok: Bool) {
        if current?.id == id {
            Self.answer(&current!, ok: ok)
        } else if let index = history.firstIndex(where: { $0.id == id }) {
            Self.answer(&history[index], ok: ok)
        }
    }

    /// The most recent command sent with Enter.
    var lastCommand: Entry? { history.last }

    private mutating func type(_ text: String, makeID: () -> UUID) -> UUID? {
        var line = current ?? Entry(id: makeID(), text: "")
        guard line.text.count + text.count <= Self.maxLength else { return nil }
        line.text += text
        line.outstanding += 1
        line.delivery = .sending
        current = line
        return line.id
    }

    private static func answer(_ entry: inout Entry, ok: Bool) {
        entry.outstanding = max(0, entry.outstanding - 1)
        if !ok { entry.anyFailed = true }
        if entry.anyFailed {
            entry.delivery = .failed
        } else if entry.outstanding == 0 {
            entry.delivery = .sent
        }
    }
}
