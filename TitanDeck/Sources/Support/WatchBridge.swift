// Support/WatchBridge.swift
import Foundation
import WatchConnectivity

/// iPhone side of the Watch (M10). Receives commands from the Watch, fires
/// them at Titan, and replies with the result. Also keeps the Watch told
/// about the Titan host and the cues it can fire. Does nothing on iPad (no
/// paired Watch).
///
/// It listens from the moment the app launches (`activate`, from the app
/// delegate), not from when TitanDeck first appears on screen (0.46.1).
/// The Watch wakes this app in the background to fire something; before,
/// nothing was listening then, so the Watch gave up on the iPhone and tried
/// Titan directly, which failed on the user's Watch ("The resource could
/// not be loaded...").
@MainActor
final class WatchBridge: NSObject, ObservableObject {
    static let shared = WatchBridge()

    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var lastCommand: String?

    private var titan: TitanClient?
    /// Used when the Watch woke the app and TitanDeck's own client isn't up yet.
    private var standIn: TitanClient?
    /// Latest host and cues, re-sent once the session finishes activating.
    private var host: String?
    private var cues: [WatchCue] = []
    private var onFired: ((WatchCommand, TitanResult) -> Void)?
    private var activated = false

    /// Starts listening for the Watch. Safe to call more than once.
    func activate() {
        guard WCSession.isSupported(), !activated else { return }
        activated = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func start(titan: TitanClient, onFired: @escaping (WatchCommand, TitanResult) -> Void) {
        self.titan = titan
        self.onFired = onFired
        activate()
    }

    /// Shares the Titan host with the Watch (delivered even if it's asleep).
    func shareHost(_ host: String) {
        self.host = host
        push()
    }

    /// Shares the cues the Watch can fire: the deck's GO keys and Titan's named playbacks.
    func shareCues(_ cues: [WatchCue]) {
        guard cues != self.cues else { return }
        self.cues = cues
        push()
    }

    /// The whole context each time: a new one replaces the last.
    private func push() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        var context: [String: Any] = [WatchCue.contextKey: cues.prefix(WatchCue.most).map(\.dictionary)]
        if let host { context[WatchReply.hostContextKey] = host }
        try? WCSession.default.updateApplicationContext(context)
    }

    fileprivate func handle(_ command: WatchCommand, reply: @escaping ([String: Any]) -> Void) {
        guard let client = titan ?? savedClient() else {
            reply(WatchReply(ok: false, milliseconds: 0, error: "Open TitanDeck on the iPhone and set the Titan address").message)
            return
        }
        Task {
            let result = await client.perform(command.action)
            lastCommand = "\(command.action.summary) - \(result.ok ? "\(result.milliseconds) ms" : "failed")"
            onFired?(command, result)
            reply(WatchReply(ok: result.ok, milliseconds: result.milliseconds, error: result.error).message)
        }
    }

    /// A client for the Titan address TitanDeck last used, for a launch in
    /// the background where the app itself hasn't started up.
    private func savedClient() -> TitanClient? {
        if let standIn { return standIn }
        guard let saved = UserDefaults.standard.string(forKey: SettingsKeys.titanHost), !saved.isEmpty else { return nil }
        standIn = TitanClient(host: saved, timeout: 1.5)
        return standIn
    }

    fileprivate func updateState(paired: Bool, installed: Bool) {
        isPaired = paired
        isWatchAppInstalled = installed
        push()
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
            replyHandler(WatchReply(ok: false, milliseconds: 0, error: "Update TitanDeck on the iPhone: it doesn't know that Watch command").message)
            return
        }
        Task { @MainActor in self.handle(command, reply: replyHandler) }
    }
}
