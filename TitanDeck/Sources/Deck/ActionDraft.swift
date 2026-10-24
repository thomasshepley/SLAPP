// Deck/ActionDraft.swift
import Foundation

/// Flat, form-friendly version of a key's action for the key inspector. The
/// picker changes `kind`; the fields keep their values when switching between
/// kinds, so flicking Go -> Release keeps the playback number.
struct ActionDraft: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case none
        case go
        case release
        case fader
        case macro
        case nextPage
        case previousPage
        case goToPage
        case openSettings
        case raw
        case keypadDigit
        case keypadAt
        case keypadEnter
        case keypadExit
        case keypadClear
        case intensity
        case mainMenu
        case colourTemperature
        case colourPresets

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: return "Nothing"
            case .go: return "Playback Go"
            case .release: return "Playback Release"
            case .fader: return "Set fader level"
            case .macro: return "Run macro"
            case .nextPage: return "Next deck page"
            case .previousPage: return "Previous deck page"
            case .goToPage: return "Go to deck page"
            case .openSettings: return "Open settings"
            case .raw: return "Custom WebAPI path"
            case .keypadDigit: return "Keypad digit"
            case .keypadAt: return "Keypad @"
            case .keypadEnter: return "Keypad Enter"
            case .keypadExit: return "Keypad Exit"
            case .keypadClear: return "Keypad Clear"
            case .intensity: return "Intensity +/- %"
            case .mainMenu: return "Page name: tap for next page"
            case .colourTemperature: return "Colour temperature"
            case .colourPresets: return "Show colour temperature presets"
            }
        }
    }

    var kind: Kind = .none
    var playback = 1
    var level = 1.0
    var macroId = ""
    var page = 0
    var rawPath = ""
    var digit = 0
    var percent = 5.0
    var kelvin = 3200

    init(action: TitanAction?) {
        switch action {
        case nil: kind = .none
        case .playbackGo(let n): kind = .go; playback = n
        case .playbackRelease(let n): kind = .release; playback = n
        case .setFaderLevel(let n, let l): kind = .fader; playback = n; level = l
        case .runMacro(let id): kind = .macro; macroId = id
        case .switchPage(let p): kind = .goToPage; page = p
        case .nextPage: kind = .nextPage
        case .previousPage: kind = .previousPage
        case .openSettings: kind = .openSettings
        case .raw(let p): kind = .raw; rawPath = p
        case .keypadDigit(let d): kind = .keypadDigit; digit = d
        case .keypadAt: kind = .keypadAt
        case .keypadEnter: kind = .keypadEnter
        case .keypadExit: kind = .keypadExit
        case .keypadClear: kind = .keypadClear
        case .adjustIntensity(let p): kind = .intensity; percent = p
        case .mainMenu: kind = .mainMenu
        case .colourTemperature(let k): kind = .colourTemperature; kelvin = k
        case .colourPresets: kind = .colourPresets
        }
    }

    /// The action this draft describes, or nil if it's empty or incomplete
    /// (e.g. a macro with no id).
    var action: TitanAction? {
        let number = max(playback, 1)
        switch kind {
        case .none: return nil
        case .go: return .playbackGo(userNumber: number)
        case .release: return .playbackRelease(userNumber: number)
        case .fader: return .setFaderLevel(userNumber: number, level: min(max(level, 0), 1))
        case .macro:
            let id = macroId.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : .runMacro(id: id)
        case .nextPage: return .nextPage
        case .previousPage: return .previousPage
        case .goToPage: return .switchPage(max(page, 0))
        case .openSettings: return .openSettings
        case .raw:
            let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : .raw(path: path)
        case .keypadDigit: return .keypadDigit(min(max(digit, 0), 9))
        case .keypadAt: return .keypadAt
        case .keypadEnter: return .keypadEnter
        case .keypadExit: return .keypadExit
        case .keypadClear: return .keypadClear
        case .intensity: return percent == 0 ? nil : .adjustIntensity(percent: min(max(percent, -100), 100))
        case .mainMenu: return .mainMenu
        case .colourTemperature: return .colourTemperature(kelvin: min(max(kelvin, 1000), 20000))
        case .colourPresets: return .colourPresets
        }
    }
}
