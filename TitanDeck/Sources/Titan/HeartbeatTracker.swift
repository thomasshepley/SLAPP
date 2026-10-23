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
