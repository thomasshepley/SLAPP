// Remote/ReconnectPolicy.swift
import Foundation

/// Exponential backoff for RDP reconnects: 1 s, 2 s, 4 s, 8 s, then every
/// 10 s for as long as it takes (a Titan PC reboot, an AirWire dropout).
struct ReconnectPolicy: Equatable {
    var initialDelay: TimeInterval = 1
    var maximumDelay: TimeInterval = 10

    /// Delay before reconnect attempt `attempt` (1-based).
    func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 1 else { return initialDelay }
        let doubled = initialDelay * pow(2, Double(min(attempt - 1, 16)))
        return min(doubled, maximumDelay)
    }
}
