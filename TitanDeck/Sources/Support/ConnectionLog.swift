// Support/ConnectionLog.swift
import Foundation

/// One thing that happened to a link: it went up, went down, or just changed.
struct ConnectionEvent: Codable, Equatable, Identifiable {
    enum Source: String, Codable, CaseIterable {
        case titan = "Titan WebAPI"
        case rdp = "Remote desktop"
        case network = "Network"
        case deck = "Stream Deck"
        case app = "App"
        case key = "Key"
    }

    enum Status: String, Codable {
        case up
        case down
        case info
    }

    var id = UUID()
    var date: Date
    var source: Source
    var status: Status
    var detail: String
}

/// Drop-out totals for one link over the log.
struct OutageSummary: Equatable {
    var source: ConnectionEvent.Source
    var dropouts: Int
    var totalDowntime: TimeInterval
    var longestOutage: TimeInterval
    /// True if the link is still down at the end of the log.
    var stillDown: Bool
}

/// The soak-test log: what dropped, when, and for how long.
struct ConnectionLog: Equatable {
    static let capacity = 5000

    private(set) var events: [ConnectionEvent] = []

    init(events: [ConnectionEvent] = []) {
        self.events = Array(events.suffix(Self.capacity))
    }

    /// Adds an event. Repeats of the current up/down state for a source are
    /// skipped, so a steady heartbeat doesn't fill the log.
    @discardableResult
    mutating func record(_ event: ConnectionEvent) -> Bool {
        if event.status != .info,
           let last = events.last(where: { $0.source == event.source && $0.status != .info }),
           last.status == event.status {
            return false
        }
        events.append(event)
        if events.count > Self.capacity {
            events.removeFirst(events.count - Self.capacity)
        }
        return true
    }

    mutating func clear() {
        events.removeAll()
    }

    /// Outage totals per source that has any up/down history, up to `now`.
    func summaries(now: Date = Date()) -> [OutageSummary] {
        ConnectionEvent.Source.allCases.compactMap { source in
            let transitions = events.filter { $0.source == source && $0.status != .info }
            guard !transitions.isEmpty else { return nil }
            var dropouts = 0
            var total: TimeInterval = 0
            var longest: TimeInterval = 0
            var downSince: Date?
            for event in transitions {
                switch event.status {
                case .down where downSince == nil:
                    dropouts += 1
                    downSince = event.date
                case .up:
                    if let start = downSince {
                        let length = event.date.timeIntervalSince(start)
                        total += length
                        longest = max(longest, length)
                        downSince = nil
                    }
                default:
                    break
                }
            }
            if let start = downSince {
                let length = now.timeIntervalSince(start)
                total += length
                longest = max(longest, length)
            }
            return OutageSummary(source: source, dropouts: dropouts, totalDowntime: total,
                                 longestOutage: longest, stillDown: downSince != nil)
        }
    }

    /// CSV for a spreadsheet: time (ISO 8601, local offset), source, status, detail.
    func csv(timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        var lines = ["time,source,status,detail"]
        for event in events {
            lines.append([formatter.string(from: event.date), event.source.rawValue, event.status.rawValue, event.detail]
                .map(Self.csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func csvField(_ value: String) -> String {
        // Quote anything with separators, and neutralise leading = + - @ so a
        // spreadsheet never treats a detail as a formula.
        var text = value
        if let first = text.first, "=+-@".contains(first) {
            text = "'" + text
        }
        guard text.contains(where: { ",\"\n\r".contains($0) }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
