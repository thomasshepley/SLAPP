// Watch/WatchModel.swift
import Foundation
import WatchConnectivity

/// Fires playbacks from the Watch: through the iPhone when it's reachable
/// (WatchConnectivity), otherwise straight to Titan over Wi-Fi if the iPhone
/// has shared the host. Reports which route was used and how long it took.
@MainActor
final class WatchModel: NSObject, ObservableObject {
    enum Route: String {
        case phone = "via iPhone"
        case direct = "direct"
    }

    struct Outcome: Equatable {
        var ok: Bool
        var text: String
    }

    @Published var playback: Int {
        didSet { UserDefaults.standard.set(playback, forKey: "watchPlayback") }
    }
    @Published var kind: WatchCommand.Kind = .go
    @Published private(set) var isFiring = false
    @Published private(set) var outcome: Outcome?
    @Published private(set) var host: String {
        didSet { UserDefaults.standard.set(host, forKey: WatchReply.hostContextKey) }
    }

    override init() {
        let saved = UserDefaults.standard.integer(forKey: "watchPlayback")
        playback = saved > 0 ? saved : 1
        host = UserDefaults.standard.string(forKey: WatchReply.hostContextKey) ?? ""
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func fire() {
        guard !isFiring else { return }
        isFiring = true
        let command = WatchCommand(kind: kind, playback: playback)
        let started = Date()
        let session = WCSession.default
        if WCSession.isSupported(), session.activationState == .activated, session.isReachable {
            session.sendMessage(command.message, replyHandler: { reply in
                let result = WatchReply(message: reply)
                Task { @MainActor in self.finish(command, ok: result.ok, ms: result.milliseconds, route: .phone, error: result.error) }
            }, errorHandler: { _ in
                // Phone went away mid-send: try going direct.
                Task { @MainActor in await self.fireDirect(command, started: started) }
            })
        } else {
            Task { await fireDirect(command, started: started) }
        }
    }

    private func fireDirect(_ command: WatchCommand, started: Date) async {
        guard !host.isEmpty else {
            finish(command, ok: false, ms: 0, route: .direct, error: "Open TitanDeck on your iPhone once to share the Titan address")
            return
        }
        let result = await TitanClient(host: host, timeout: 1.5).perform(command.action)
        finish(command, ok: result.ok, ms: Int(Date().timeIntervalSince(started) * 1000), route: .direct, error: result.error)
    }

    private func finish(_ command: WatchCommand, ok: Bool, ms: Int, route: Route, error: String?) {
        isFiring = false
        let name = command.kind == .go ? "GO" : "Release"
        outcome = ok
            ? Outcome(ok: true, text: "\(name) \(command.playback) - \(ms) ms \(route.rawValue)")
            : Outcome(ok: false, text: error ?? "Titan didn't answer")
    }

    fileprivate func receivedHost(_ newHost: String) {
        host = newHost
    }
}

extension WatchModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        if let host = session.receivedApplicationContext[WatchReply.hostContextKey] as? String {
            Task { @MainActor in self.receivedHost(host) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let host = applicationContext[WatchReply.hostContextKey] as? String {
            Task { @MainActor in self.receivedHost(host) }
        }
    }
}
