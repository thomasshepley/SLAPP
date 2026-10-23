// Support/WatchCommand.swift
import Foundation

/// What the Watch asks the iPhone to do, as a WatchConnectivity message.
/// Shared by both apps so the dictionary keys can't drift apart.
struct WatchCommand: Equatable {
    enum Kind: String, CaseIterable {
        case go
        case release
    }

    var kind: Kind
    var playback: Int

    var action: TitanAction {
        switch kind {
        case .go: return .playbackGo(userNumber: playback)
        case .release: return .playbackRelease(userNumber: playback)
        }
    }

    var message: [String: Any] {
        ["command": kind.rawValue, "playback": playback]
    }

    init(kind: Kind, playback: Int) {
        self.kind = kind
        self.playback = playback
    }

    init?(message: [String: Any]) {
        guard let raw = message["command"] as? String, let kind = Kind(rawValue: raw),
              let playback = message["playback"] as? Int, (1...9999).contains(playback) else { return nil }
        self.init(kind: kind, playback: playback)
    }
}

/// The iPhone's answer.
struct WatchReply: Equatable {
    var ok: Bool
    var milliseconds: Int
    var error: String?

    var message: [String: Any] {
        var result: [String: Any] = ["ok": ok, "ms": milliseconds]
        if let error { result["error"] = error }
        return result
    }

    init(ok: Bool, milliseconds: Int, error: String?) {
        self.ok = ok
        self.milliseconds = milliseconds
        self.error = error
    }

    init(message: [String: Any]) {
        ok = message["ok"] as? Bool ?? false
        milliseconds = message["ms"] as? Int ?? 0
        error = message["error"] as? String
    }

    /// Key the iPhone uses to share its Titan host with the Watch.
    static let hostContextKey = "titanHost"
}
