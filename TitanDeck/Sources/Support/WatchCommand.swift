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
    /// The playback's number in Titan (the Digital Crown page).
    var playback: Int
    /// A cue from the list (0.46.1): Titan's own id for the playback. Set,
    /// it's fired by that and `playback` isn't used: Titan's handles carry no
    /// reliable number, which is why the deck's GO keys go by id too.
    var titanId: Int?

    var action: TitanAction {
        if let titanId {
            return kind == .go ? .fireHandle(titanId: titanId) : .releaseHandle(titanId: titanId)
        }
        switch kind {
        case .go: return .playbackGo(userNumber: playback)
        case .release: return .playbackRelease(userNumber: playback)
        }
    }

    /// A cue never carries a playback number: an iPhone app too old to know
    /// cues must refuse it, not fire some other playback.
    var message: [String: Any] {
        if let titanId { return ["command": kind.rawValue, "titanId": titanId] }
        return ["command": kind.rawValue, "playback": playback]
    }

    init(kind: Kind, playback: Int, titanId: Int? = nil) {
        self.kind = kind
        self.playback = playback
        self.titanId = titanId
    }

    init?(message: [String: Any]) {
        guard let raw = message["command"] as? String, let kind = Kind(rawValue: raw) else { return nil }
        if let titanId = message["titanId"] as? Int {
            guard titanId > 0 else { return nil }
            self.init(kind: kind, playback: 0, titanId: titanId)
            return
        }
        guard let playback = message["playback"] as? Int, (1...9999).contains(playback) else { return nil }
        self.init(kind: kind, playback: playback)
    }
}

/// A cue the Watch can fire (0.46.1): one of Titan's playbacks by its id,
/// with the name to show. The iPhone sends the list (the deck's GO keys
/// first, then Titan's other named playbacks) in the application context,
/// so the Watch has it even when the iPhone app isn't running.
struct WatchCue: Equatable, Identifiable {
    var titanId: Int
    var title: String
    /// On one of the deck's GO keys: listed first.
    var onDeck: Bool

    var id: Int { titanId }

    /// Key for the list in the application context, and the most it holds.
    static let contextKey = "cues"
    static let most = 60

    var dictionary: [String: Any] {
        ["id": titanId, "title": title, "deck": onDeck]
    }

    init(titanId: Int, title: String, onDeck: Bool) {
        self.titanId = titanId
        self.title = title
        self.onDeck = onDeck
    }

    init?(dictionary: [String: Any]) {
        guard let titanId = dictionary["id"] as? Int, titanId > 0, let title = dictionary["title"] as? String else { return nil }
        self.init(titanId: titanId, title: title, onDeck: dictionary["deck"] as? Bool ?? false)
    }

    /// The list out of an application context (or what was saved of one).
    static func list(from value: Any?) -> [WatchCue] {
        (value as? [[String: Any]] ?? []).compactMap(WatchCue.init(dictionary:))
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
