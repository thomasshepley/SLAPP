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
    /// GO for whichever cue Connect Cue put on this deck slot (0 = GO 1). Local:
    /// the deck turns it into fireHandle for the assigned playback.
    case cueGo(slot: Int)
    /// Opens the fade-time picker for a slot's cue. Local.
    case cueFade(slot: Int, fadeOut: Bool)
    /// Connect Cue: pick which Titan cues the GO slots fire. Local.
    case connectCue
    /// A choice on one of the deck's own pickers. Local, never in the editor.
    case deckChoice(DeckChoice)
    /// Fire a playback to full by its titanId (FirePlaybackAtLevel).
    case fireHandle(titanId: Int)
    /// Set a playback's first cue fade in or out, in seconds. Experimental:
    /// selects the cue, then writes Playbacks/Editor/Times/CueFadeIn/OutTime.
    case setCueFade(titanId: Int, fadeOut: Bool, seconds: Double)
    /// Hold to take the selected fixtures to 0%, let go to put them back. Local:
    /// the deck sends dimmerFlash down on press and up on release.
    case flashSelection
    /// The flash itself: down to 0% (stepping over `seconds` if given), or
    /// back up by releasing the dimmer from the programmer over `seconds`.
    case dimmerFlash(down: Bool, seconds: Double?)
    /// Release a playback by its titanId (ReleasePlayback, its master release
    /// time): the second press of a latching GO.
    case releaseHandle(titanId: Int)
    /// Keypad Thro ("1 THRU 10"). On the default keypad it takes Clear's
    /// place while nothing is selected.
    case keypadThro
    /// Rig check: Titan's Highlight on or off for the selected fixtures.
    case toggleHighlight
    /// Rig check: the next fixture of the selection on its own (Titan's Next).
    case nextFixture
    /// Rig check: the previous fixture of the selection on its own (Titan's Prev).
    case previousFixture
    /// A group master (a playback fader with a group on it) to a level, 0...1.
    case setGroupMaster(titanId: Int, level: Double)
    /// Rig check: back to the whole selection after stepping (Titan's All).
    case allFixtures

    /// True for actions that go over the network to Titan.
    var isRemote: Bool {
        switch self {
        case .switchPage, .openSettings, .nextPage, .previousPage, .mainMenu, .colourPresets,
             .cueGo, .cueFade, .connectCue, .deckChoice, .flashSelection: return false
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
        case .keypadThro: return "Keypad Thru"
        case .adjustIntensity(let p): return "Intensity \(p >= 0 ? "+" : "")\(TitanEndpoints.format(number: p))%"
        case .mainMenu: return "Main menu"
        case .previousPage: return "Previous deck page"
        case .colourTemperature(let k): return "Colour temp \(k)K"
        case .colourPresets: return "Colour temperature presets"
        case .recallWorkspace(let n): return "Workspace \(n)"
        case .cueGo(let slot): return "Cue GO \(slot + 1)"
        case .cueFade(let slot, let out): return "Cue \(slot + 1) fade \(out ? "out" : "in")"
        case .connectCue: return "Connect Cue"
        case .deckChoice: return "Deck choice"
        case .fireHandle(let id): return "Go handle \(id)"
        case .releaseHandle(let id): return "Release handle \(id)"
        case .setCueFade(let id, let out, let s): return "Handle \(id) fade \(out ? "out" : "in") \(TitanEndpoints.format(number: s))s"
        case .flashSelection: return "Flash selection to 0%"
        case .toggleHighlight: return "Highlight"
        case .nextFixture: return "Next fixture"
        case .previousFixture: return "Previous fixture"
        case .allFixtures: return "All fixtures again"
        case .setGroupMaster(let id, let level): return "Group master \(id) @ \(Int((level * 100).rounded()))%"
        case .dimmerFlash(let down, let s): return "Flash \(down ? "down" : "back")\(s.map { " over \(TitanEndpoints.format(number: $0))s" } ?? "")"
        }
    }
}

/// Choices made on the deck's own pickers. They're never saved in a profile
/// the editor can see; they only exist on the pages DeckCues builds.
enum DeckChoice: Codable, Hashable {
    case assignSlot(Int)
    case unassignSlot(Int)
    case titanPage(Int)
    case morePages(from: Int)
    case pickCue(titanId: Int)
    case fadeTime(Double)
    /// From the colour temperatures straight back to the intensity keys.
    case intensity
    /// One key of the selection strip on Quick Keys (0 = the first): shows
    /// selected fixture numbers; a tap shows the next ones.
    case selectionStrip(Int)
    case back
    case done
    /// The main menu's way to the Slate page.
    case openSlates
    /// Slate page: the slate (0) or take (1) showing; a tap does nothing.
    case slateShow(Int)
    /// Slate page: the next take, logging the look.
    case slateTake
    /// Slate page: the next slate, take 1, logging the look.
    case slateNew
    /// Slate page: the same setup's next letter ("112A"), take 1.
    case slateLetter
    /// Slate page: day or night.
    case slateNight
    /// Slate page: FX shot or not.
    case slateFx
    /// The main menu's way to the Rig page (Highlight, Next and Previous fixture).
    case openRig
    /// The main menu's way to the Masters page (the group masters on Titan's page 60).
    case openMasters
    /// Masters page: a group master, to pick its level.
    case pickMaster(titanId: Int)
    /// A group master's level picker: 0...1.
    case masterLevel(Double)
    /// The main menu's way to the FX page (Prism layers, Test mode).
    case openFX
    /// FX page: an effect kind (DeckFX.Category's raw value).
    case fxCategory(String)
    /// FX versions: one of the FX tab's effects, by id.
    case fxItem(String)
    /// FX page or layer pick: Prism layer 1 or 2.
    case fxLayer(Int)
    /// FX layer page: pick another video for this layer.
    case fxPickVideo
    /// FX layer page: a level to set (DeckFX.Control's raw value).
    case fxControl(String)
    /// FX level picker: 0...1.
    case fxLevel(Double)
    /// FX layer page: the pixel map's playback on / off.
    case fxGo
    case fxStop
    /// FX layer page: let go of the layer in the WebAPI user's programmer.
    case fxRelease
    /// FX page: let go of both layers.
    case fxReleaseAll
    /// FX layer page: its fixtures.
    case fxFixtures
    /// FX fixtures: the layer's group becomes the desk's selection, gains it, or loses it.
    case fxUseSelection
    case fxAdd
    case fxRemove
    /// FX fixtures: the layer's group becomes an FXZone group's fixtures.
    case fxZone(titanId: Int)
}
