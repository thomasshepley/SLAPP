// Support/WatchBridge.swift
import Foundation
import WatchConnectivity

/// iPhone side of the Watch GO button (M10). Receives commands from the
/// Watch, fires them at Titan, and replies with the result. Also keeps the
/// Watch told about the Titan host so it can go direct over Wi-Fi when the
/// phone isn't in reach. Does nothing on iPad (no paired Watch).
@MainActor
final class WatchBridge: NSObject, ObservableObject {
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var lastCommand: String?

    private var titan: TitanClient?
    /// Latest host, re-sent once the session finishes activating.
    private var pendingHost: String?
    private var onFired: ((WatchCommand, TitanResult) -> Void)?

    func start(titan: TitanClient, onFired: @escaping (WatchCommand, TitanResult) -> Void) {
        guard WCSession.isSupported() else { return }
        self.titan = titan
        self.onFired = onFired
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Shares the Titan host with the Watch (delivered even if it's asleep).
    func shareHost(_ host: String) {
        pendingHost = host
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([WatchReply.hostContextKey: host])
    }

    fileprivate func handle(_ command: WatchCommand, reply: @escaping ([String: Any]) -> Void) {
        guard let titan else {
            reply(WatchReply(ok: false, milliseconds: 0, error: "TitanDeck isn't ready").message)
            return
        }
        Task {
            let result = await titan.perform(command.action)
            lastCommand = "\(command.action.summary) - \(result.ok ? "\(result.milliseconds) ms" : "failed")"
            onFired?(command, result)
            reply(WatchReply(ok: result.ok, milliseconds: result.milliseconds, error: result.error).message)
        }
    }

    fileprivate func updateState(paired: Bool, installed: Bool) {
        isPaired = paired
        isWatchAppInstalled = installed
        if let pendingHost {
            shareHost(pendingHost)
        }
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let paired = session.isPaired, installed = session.isWatchAppInstalled
        Task { @MainActor in self.updateState(paired: paired, installed: installed) }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired, installed = session.isWatchAppInstalled
        Task { @MainActor in self.updateState(paired: paired, installed: installed) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another Watch: start talking to the new one.
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = WatchCommand(message: message) else {
            replyHandler(WatchReply(ok: false, milliseconds: 0, error: "Unknown command").message)
            return
        }
        Task { @MainActor in self.handle(command, reply: replyHandler) }
    }
}
