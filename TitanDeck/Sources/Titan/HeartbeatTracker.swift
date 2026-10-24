// Titan/HeartbeatTracker.swift
import Foundation

/// How Titan's WebAPI is doing, judged from a regular heartbeat request.
enum TitanHealth: Equatable {
    /// No heartbeat yet, or no Titan host set.
    case unknown
    /// Answering normally.
    case ok(milliseconds: Int)
    /// Answering, but slower than the 500 ms key timeout is comfortable with.
    case slow(milliseconds: Int)
    /// Missed heartbeats in a row.
    case down

    var isReachable: Bool {
        switch self {
        case .ok, .slow: return true
        case .unknown, .down: return false
        }
    }
}

/// Turns heartbeat results into a TitanHealth. One missed beat isn't enough
/// to call it down - a single dropped packet shouldn't turn the pill red.
struct HeartbeatTracker: Equatable {
    var slowThresholdMilliseconds = 150
    var missesBeforeDown = 2
    private(set) var consecutiveMisses = 0
    private(set) var health: TitanHealth = .unknown

    mutating func record(milliseconds: Int?) {
        guard let milliseconds else {
            consecutiveMisses += 1
            if consecutiveMisses >= missesBeforeDown {
                health = .down
            }
            return
        }
        consecutiveMisses = 0
        health = milliseconds > slowThresholdMilliseconds ? .slow(milliseconds: milliseconds) : .ok(milliseconds: milliseconds)
    }

    mutating func reset() {
        consecutiveMisses = 0
        health = .unknown
    }
}

/// Reply times over the last few heartbeats, for the connection details panel.
/// iOS doesn't let apps read Wi-Fi signal strength, so steady, low reply times
/// to the Titan PC are the next best measure of link quality.
struct LatencySummary: Equatable {
    /// Heartbeats that got a reply, and ones that didn't.
    let replies: Int
    let misses: Int
    let fastest: Int?
    let slowest: Int?
    let average: Int?
    /// Average change between consecutive replies, in ms. High jitter with a
    /// fine average usually means a busy or patchy Wi-Fi link.
    let jitter: Int?

    /// `samples` oldest first, nil for a missed heartbeat.
    init(samples: [Int?]) {
        let times = samples.compactMap { $0 }
        replies = times.count
        misses = samples.count - times.count
        fastest = times.min()
        slowest = times.max()
        average = times.isEmpty ? nil : Int((Double(times.reduce(0, +)) / Double(times.count)).rounded())
        if times.count >= 2 {
            let steps = zip(times, times.dropFirst()).map { abs($1 - $0) }
            jitter = Int((Double(steps.reduce(0, +)) / Double(steps.count)).rounded())
        } else {
            jitter = nil
        }
    }

    /// Missed heartbeats as a whole percentage of all heartbeats.
    var lossPercent: Int {
        let total = replies + misses
        return total == 0 ? 0 : Int((Double(misses) * 100 / Double(total)).rounded())
    }
}
