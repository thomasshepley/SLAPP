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
    /// Next deck page, wrapping round - handled locally.
    case nextPage
    /// Previous deck page, wrapping round - handled locally.
    case previousPage
    /// Avolites keypad digit 0-9, typed onto Titan's command line.
    case keypadDigit(Int)
    /// Keypad @.
    case keypadAt
    /// Keypad Enter: runs the command line.
    case keypadEnter
    /// Keypad Exit: leaves the current menu.
    case keypadExit
    /// Keypad Clear: clears the command line, or the programmer if it's empty.
    case keypadClear
    /// Nudges the selected fixtures' intensity up or down by a percentage.
    case adjustIntensity(percent: Double)
    /// Opens the main menu of deck layouts - only after a 2 s hold. Local.
    case mainMenu
    /// Sets the selected fixtures' colour temperature by recalling Titan's
    /// colour palette named for it ("3200K"), so each fixture type uses its
    /// own CCT channel.
    case colourTemperature(kelvin: Int)
    /// Shows the colour temperature presets on the deck. Local.
    case colourPresets
    /// Recalls a Titan workspace (a saved window layout / view) by user number.
    case recallWorkspace(userNumber: Int)

    /// True for actions that go over the network to Titan.
    var isRemote: Bool {
        switch self {
        case .switchPage, .openSettings, .nextPage, .previousPage, .mainMenu, .colourPresets: return false
        default: return true
        }
    }

    /// The playback this action controls, if any - used to light active keys.
    var playbackUserNumber: Int? {
        switch self {
        case .playbackGo(let n), .playbackRelease(let n), .setFaderLevel(let n, _): return n
        default: return nil
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
        case .nextPage: return "Next deck page"
        case .keypadDigit(let d): return "Keypad \(d)"
        case .keypadAt: return "Keypad @"
        case .keypadEnter: return "Keypad Enter"
        case .keypadExit: return "Keypad Exit"
        case .keypadClear: return "Keypad Clear"
        case .adjustIntensity(let p): return "Intensity \(p >= 0 ? "+" : "")\(TitanEndpoints.format(number: p))%"
        case .mainMenu: return "Main menu"
        case .previousPage: return "Previous deck page"
        case .colourTemperature(let k): return "Colour temp \(k)K"
        case .colourPresets: return "Colour temperature presets"
        case .recallWorkspace(let n): return "Workspace \(n)"
        }
    }
}
