// Watch/WatchModel.swift
import Foundation
import WatchConnectivity

/// Fires cues and playbacks from the Watch: through the iPhone when it's
/// reachable (WatchConnectivity), otherwise straight to Titan over Wi-Fi if
/// the iPhone has shared the host. Reports which route was used and how
/// long it took. The cue list comes from the iPhone (the deck's GO keys and
/// Titan's named playbacks) and is kept, so it's there next time.
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
    /// The cue being fired, for its row's spinner.
    @Published private(set) var firingCue: Int?
    @Published private(set) var outcome: Outcome?
    @Published private(set) var cues: [WatchCue] {
        didSet { UserDefaults.standard.set(cues.map(\.dictionary), forKey: WatchCue.contextKey) }
    }
    @Published private(set) var host: String {
        didSet { UserDefaults.standard.set(host, forKey: WatchReply.hostContextKey) }
    }

    override init() {
        let saved = UserDefaults.standard.integer(forKey: "watchPlayback")
        playback = saved > 0 ? saved : 1
        host = UserDefaults.standard.string(forKey: WatchReply.hostContextKey) ?? ""
        cues = WatchCue.list(from: UserDefaults.standard.array(forKey: WatchCue.contextKey))
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// GO or Release for the playback picked with the Digital Crown.
    func fire() {
        send(WatchCommand(kind: kind, playback: playback), name: "\(kind == .go ? "GO" : "Release") \(playback)")
    }

    /// GO or Release for a cue from the list.
    func fire(_ cue: WatchCue, release: Bool) {
        send(WatchCommand(kind: release ? .release : .go, playback: 0, titanId: cue.titanId),
             name: "\(release ? "Released" : "GO") \(cue.title)", cue: cue.titanId)
    }

    private func send(_ command: WatchCommand, name: String, cue: Int? = nil) {
        guard !isFiring else { return }
        isFiring = true
        firingCue = cue
        let started = Date()
        let session = WCSession.default
        if WCSession.isSupported(), session.activationState == .activated, session.isReachable {
            session.sendMessage(command.message, replyHandler: { reply in
                let result = WatchReply(message: reply)
                Task { @MainActor in self.finish(name, ok: result.ok, ms: result.milliseconds, route: .phone, error: result.error) }
            }, errorHandler: { _ in
                // Phone went away mid-send: try going direct.
                Task { @MainActor in await self.fireDirect(command, name: name, started: started) }
            })
        } else {
            Task { await fireDirect(command, name: name, started: started) }
        }
    }

    private func fireDirect(_ command: WatchCommand, name: String, started: Date) async {
        guard !host.isEmpty else {
            finish(name, ok: false, ms: 0, route: .direct, error: "Open TitanDeck on your iPhone once to share the Titan address")
            return
        }
        let result = await TitanClient(host: host, timeout: 1.5).perform(command.action)
        // Titan's own error isn't much use on a Watch (and is cut short): say what to do.
        finish(name, ok: result.ok, ms: Int(Date().timeIntervalSince(started) * 1000), route: .direct,
               error: "No answer from the iPhone, and the Watch can't reach Titan itself. Open TitanDeck on the iPhone.")
    }

    private func finish(_ name: String, ok: Bool, ms: Int, route: Route, error: String?) {
        isFiring = false
        firingCue = nil
        outcome = ok
            ? Outcome(ok: true, text: "\(name) - \(ms) ms \(route.rawValue)")
            : Outcome(ok: false, text: error ?? "Titan didn't answer")
    }

    /// What the iPhone shares: the Titan address and the cue list.
    fileprivate func received(host newHost: String?, cues newCues: [WatchCue]?) {
        if let newHost, newHost != host { host = newHost }
        if let newCues, newCues != cues { cues = newCues }
    }
}

extension WatchModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        take(session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        take(applicationContext)
    }

    nonisolated private func take(_ context: [String: Any]) {
        let host = context[WatchReply.hostContextKey] as? String
        // No list in it at all (an older iPhone app): keep the one there is.
        let cues = context[WatchCue.contextKey] == nil ? nil : WatchCue.list(from: context[WatchCue.contextKey])
        Task { @MainActor in self.received(host: host, cues: cues) }
    }
}
