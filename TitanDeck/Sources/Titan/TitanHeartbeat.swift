// Titan/TitanHeartbeat.swift
import Foundation

/// Asks Titan for its software version every couple of seconds so the
/// connection pill can show whether the WebAPI is answering, and how fast.
@MainActor
final class TitanHeartbeat: ObservableObject {
    @Published private(set) var health: TitanHealth = .unknown
    @Published private(set) var version: String?
    /// The last minute of reply times, oldest first (nil = no reply).
    @Published private(set) var recentSamples: [Int?] = []

    private var tracker = HeartbeatTracker()
    private var task: Task<Void, Never>?
    private let interval: UInt64 = 2_000_000_000
    private let sampleCount = 30

    func start(client: TitanClient, isHostSet: @escaping @MainActor () -> Bool) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if isHostSet() {
                    let started = Date()
                    let version = await client.softwareVersion()
                    let ms = Int((Date().timeIntervalSince(started) * 1000).rounded())
                    self.tracker.record(milliseconds: version == nil ? nil : ms)
                    self.recentSamples = Array((self.recentSamples + [version == nil ? nil : ms]).suffix(self.sampleCount))
                    if let version { self.version = version }
                } else {
                    self.tracker.reset()
                    self.recentSamples = []
                }
                self.health = self.tracker.health
                try? await Task.sleep(nanoseconds: self.interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
