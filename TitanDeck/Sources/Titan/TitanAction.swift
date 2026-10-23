// Titan/TitanAction.swift
import Foundation

/// Everything a deck key can do. Saved inside profiles, so changing a case
/// name breaks existing profile JSON - add new cases rather than renaming.
enum TitanAction: Codable, Hashable {
    /// Fire a playback to full (FirePlaybackAtLevel, level 1).
    case playbackGo(userNumber: Int)
    /// Release a playback using its master release time (ReleasePlayback).
    case playbackRelease(userNumber: Int)
    /// Set a playback fader to a level, 0.0 - 1.0 (SetPlaybackLevel).
    case setFaderLevel(userNumber: Int, level: Double)
    /// Run a macro by its macro id string (Macros/Run).
    case runMacro(id: String)
    /// Switch deck page - handled locally, never sent to Titan.
    case switchPage(Int)
    /// Open the settings screen - handled locally, never sent to Titan.
    case openSettings
    /// Anything else: a path appended to /titan/script/2/, query string included.
    case raw(path: String)

    /// True for actions that go over the network to Titan.
    var isRemote: Bool {
        switch self {
        case .switchPage, .openSettings: return false
        default: return true
        }
    }

    /// Short human-readable description for logs and the settings screen.
    var summary: String {
        switch self {
        case .playbackGo(let n): return "Go PB \(n)"
        case .playbackRelease(let n): return "Release PB \(n)"
        case .setFaderLevel(let n, let l): return "PB \(n) @ \(Int((l * 100).rounded()))%"
        case .runMacro(let id): return "Macro \(id)"
        case .switchPage(let p): return "Deck page \(p + 1)"
        case .openSettings: return "Open settings"
        case .raw(let p): return "Raw \(p)"
        }
    }
}
