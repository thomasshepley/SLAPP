// Slate/SlateText.swift
import Foundation

/// How the Slate Book reads, on the deck and in the app: slate labels, the
/// day's lines grouped by slate then take, and changes in plain words.
/// Pure, so it's tested.
enum SlateText {
    /// "SL\n112A" for the deck's slate key.
    static func slateKey(_ state: HostSlateState?) -> String { "SL\n\(state?.slate ?? "-")" }

    /// "TK\n3" for the deck's take key.
    static func takeKey(_ state: HostSlateState?) -> String { "TK\n\(state.map { String($0.take) } ?? "-")" }

    /// "DAY" or "NIGHT".
    static func dayNight(_ night: Bool) -> String { night ? "NIGHT" : "DAY" }

    /// "Slate 112A · Take 3 · Night · FX"
    static func summary(_ state: HostSlateState) -> String {
        "Slate \(state.slate) · Take \(state.take) · \(night(state.night))\(state.fx ? " · FX" : "")"
    }

    static func night(_ night: Bool) -> String { night ? "Night" : "Day" }

    /// "101 Dimmer 60 → 45%", "U1.37 12 → 0%".
    static func describe(_ change: HostLookChange) -> String {
        "\(change.fixture.map { "\($0) " } ?? "")\(change.what) \(percent(change.before)) → \(percent(change.after))%"
    }

    static func percent(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// The biggest differences first (for Match), then by fixture.
    static func worstFirst(_ changes: [HostLookChange]) -> [HostLookChange] {
        changes.sorted {
            let a = abs($0.after - $0.before), b = abs($1.after - $1.before)
            return a != b ? a > b : ($0.fixture ?? Int.max, $0.what) < ($1.fixture ?? Int.max, $1.what)
        }
    }

    /// One take of a slate: the line that started it (nil when the day began
    /// mid-slate) and the changes during it, oldest first.
    struct Take: Identifiable, Equatable {
        let take: Int
        let start: HostSlateEntry?
        let changes: [HostSlateEntry]
        var id: Int { start?.id ?? changes.first?.id ?? take }
        var all: [HostSlateEntry] { (start.map { [$0] } ?? []) + changes }
    }

    /// A slate's lines, newest take first.
    struct Slate: Identifiable, Equatable {
        let slate: String
        let takes: [Take]
        let night: Bool
        let fx: Bool
        let started: Date
        var id: String { "\(slate)-\(started.timeIntervalSince1970)" }
    }

    /// The day's lines as slates (newest first), each with its takes (newest
    /// first). A slate shot again later in the day is a new group.
    static func grouped(_ entries: [HostSlateEntry]) -> [Slate] {
        var slates: [(slate: String, entries: [HostSlateEntry])] = []
        for entry in entries.sorted(by: { $0.id < $1.id }) {
            if let last = slates.last, last.slate == entry.slate, entry.kind != "slate" {
                slates[slates.count - 1].entries.append(entry)
            } else {
                slates.append((entry.slate, [entry]))
            }
        }
        return slates.reversed().map { group in
            var takes: [Take] = []
            for entry in group.entries {
                if entry.kind != "change" || takes.last?.take != entry.take {
                    let starts = entry.kind != "change"
                    takes.append(Take(take: entry.take, start: starts ? entry : nil, changes: starts ? [] : [entry]))
                } else {
                    let last = takes.removeLast()
                    takes.append(Take(take: last.take, start: last.start, changes: last.changes + [entry]))
                }
            }
            let first = group.entries[0]
            return Slate(slate: group.slate, takes: takes.reversed(), night: first.night, fx: first.fx, started: first.time)
        }
    }
}
