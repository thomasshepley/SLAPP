// Deck/DeckFlow.swift
import Foundation

/// The deck's moment-to-moment logic that isn't tied to the hardware: what
/// the keypad has typed, the pages the deck shows in place of a profile page
/// (the main menu, Quick Keys after a selection), and how keys read
/// on the page they're on. Pure, so it's tested without a Stream Deck.
enum DeckFlow {
    /// A page shown in place of the profile page for a moment.
    enum Overlay: Equatable {
        /// The main menu of layouts (Menu key held for a second).
        case menu
        /// Quick Keys: fixtures were selected ("102 Enter", or on the desk),
        /// or Menu was tapped on the keypad. The intensity nudges, flash and
        /// CCT, with a way back to the keypad.
        case selection(returnTo: Int)
        /// The colour temperature presets, from a selection or a CCT key.
        case colour(returnTo: Int)
        /// Connect Cue: pick a GO slot to fill or empty.
        case connectCue(returnTo: Int)
        /// Titan's playback pages, for filling `slot`.
        case titanPages(slot: Int, first: Int, fromConnect: Bool, returnTo: Int)
        /// The cues on one Titan page, for filling `slot`.
        case titanCues(slot: Int, page: Int, fromConnect: Bool, returnTo: Int)
        /// Fade times for a slot's cue.
        case fadePicker(slot: Int, fadeOut: Bool, returnTo: Int)

        /// The profile page to go back to.
        var returnTo: Int {
            switch self {
            case .menu: return 0
            case .selection(let page), .colour(let page), .connectCue(let page): return page
            case .titanPages(_, _, _, let page), .titanCues(_, _, _, let page), .fadePicker(_, _, let page): return page
            }
        }
    }

    // MARK: Keypad

    /// What's been typed on the deck's keypad since the last Enter, Clear or
    /// Exit, and the fixture that leaves selected in Titan.
    struct KeypadBuffer: Equatable {
        private(set) var text = ""
        /// The fixture in the programmer, as far as the deck knows: "102 Enter"
        /// and "102 @ 50 Enter" both leave 102 selected, "@ 50 Enter" keeps
        /// whatever was, and a Clear with nothing typed drops it.
        private(set) var selection: Int?

        enum Event: Equatable {
            case none
            /// A plain number then Enter ("102 Enter"): fixtures selected.
            case selected
            /// Clear with nothing typed: Titan cleared the programmer.
            case clearedProgrammer
        }

        /// Feeds in a key's action and says what it did.
        mutating func apply(_ action: TitanAction) -> Event {
            switch action {
            case .keypadDigit(let digit):
                text += "\(min(max(digit, 0), 9))"
            case .keypadAt:
                text += "@"
            case .keypadClear:
                // Like Titan: the first Clear empties the line, the next the programmer.
                guard text.isEmpty else { text = ""; return .none }
                selection = nil
                return .clearedProgrammer
            case .keypadExit:
                text = ""
            case .keypadEnter:
                defer { text = "" }
                let fixture = text.prefix { $0 != "@" }
                if !fixture.isEmpty, fixture.allSatisfy(\.isNumber), let number = Int(fixture) {
                    selection = number
                }
                return !text.isEmpty && text.allSatisfy(\.isNumber) ? .selected : .none
            default:
                break
            }
            return .none
        }
    }

    // MARK: Following the desk's selection

    /// Decides when the desk's selection (desk link) should bring the
    /// intensity keys up, or put them away: up when something new is
    /// selected, away when the selection is emptied.
    struct SelectionFollower: Equatable {
        private(set) var last: [Int] = []

        enum Change: Equatable { case none, show, hide }

        mutating func update(_ selection: [Int]) -> Change {
            defer { last = selection }
            if selection.isEmpty { return last.isEmpty ? .none : .hide }
            return selection == last ? .none : .show
        }
    }

    /// Short text for a selection, for "Currently Selected": "101",
    /// "101-110", "101, 105, 107", or the first two runs and how many more.
    static func selectionLabel(_ fixtures: [Int]) -> String? {
        guard !fixtures.isEmpty else { return nil }
        var runs: [ClosedRange<Int>] = []
        for number in fixtures {
            if let last = runs.last, number == last.upperBound + 1 {
                runs[runs.count - 1] = last.lowerBound ... number
            } else {
                runs.append(number ... number)
            }
        }
        let text = { (run: ClosedRange<Int>) in
            run.count == 1 ? "\(run.lowerBound)" : "\(run.lowerBound)-\(run.upperBound)"
        }
        guard runs.count > 3 else { return runs.map(text).joined(separator: ", ") }
        let shown = runs.prefix(2)
        let more = fixtures.count - shown.reduce(0) { $0 + $1.count }
        return shown.map(text).joined(separator: ", ") + " +\(more)"
    }

    /// The flash key's label: the fixture's live level when it's known.
    static func flashLabel(level: Double?) -> String {
        guard let level else { return "HOLD\nFOR 0%" }
        return "\(Int((min(max(level, 0), 1) * 100).rounded()))%\nHOLD 0%"
    }

    // MARK: Pages

    /// What the intensity page is called. Profiles from before 0.17 call it
    /// "Intensity", which still counts.
    static let quickKeysName = "Quick Keys"

    /// The profile's Quick Keys page (or one still called Intensity).
    static func quickKeysPageIndex(in profile: DeckProfile) -> Int? {
        profile.pages.firstIndex { page in
            [quickKeysName, "Intensity"].contains { page.name.caseInsensitiveCompare($0) == .orderedSame }
        }
    }

    /// Quick Keys: the profile's Quick Keys page (or, failing that, the
    /// standard nudges) with Return to Keypad where Menu is on the keypad
    /// (bottom middle on the 15-key deck), CCT bottom right (where the colour
    /// keys have INTENSITY, so that key swaps between the two) and the
    /// hold-for-0% flash in the middle. On other decks, or if those spots are
    /// taken, they go in the first free spots. Shown after a selection, from
    /// Menu on the keypad, and whenever the Quick Keys page itself is picked.
    static func selectionPage(profile: DeckProfile, returnTo: Int) -> DeckPage {
        let source = quickKeysPageIndex(in: profile).map { profile.pages[$0] }
            ?? profile.pages.first { page in page.keys.contains { $0.action.map(isIntensity) ?? false } }
        let threeWide = isThreeWide(profile)
        var keys = withReturnKey(source?.keys ?? defaultIntensityKeys(keyCount: profile.keyCount),
                                 keyCount: profile.keyCount, threeWide: threeWide)
        let extras: [(key: KeyDefinition, spot: Int?)] = [
            (KeyDefinition(index: 0, label: "CCT", colorHex: colourHex(kelvin: 4500),
                           sfSymbol: "thermometer.sun.fill", action: .colourPresets), threeWide ? 14 : nil),
            (KeyDefinition(index: 0, label: "HOLD\nFOR 0%", colorHex: "#000000",
                           sfSymbol: "lightbulb.slash.fill", action: .flashSelection), threeWide ? 7 : nil),
        ]
        for (template, spot) in extras where !keys.contains(where: { $0.action == template.action }) {
            let used = Set(keys.map(\.index))
            let free = spot.flatMap { used.contains($0) ? nil : $0 }
                ?? (0 ..< profile.keyCount).first { !used.contains($0) }
            guard let free else { break }
            var extra = template
            extra.index = free
            keys.append(extra)
        }
        return DeckPage(name: quickKeysName, keys: keys.sorted { $0.index < $1.index })
    }

    /// The colour temperature presets: the profile's Colour page, or the
    /// standard presets, with Return to Keypad where Menu is.
    static func colourPage(profile: DeckProfile, returnTo: Int) -> DeckPage {
        let source = page(named: "Colour", in: profile)
            ?? profile.pages.first { page in page.keys.contains { $0.action.map(isColourTemperature) ?? false } }
        let threeWide = isThreeWide(profile)
        var keys = withReturnKey(source?.keys ?? cctKeys(keyCount: profile.keyCount),
                                 keyCount: profile.keyCount, threeWide: threeWide)
        // Straight back to Quick Keys: bottom right on the 15-key deck, where
        // Quick Keys has CCT, or the first free key.
        if !keys.contains(where: { $0.action == .deckChoice(.intensity) }) {
            let used = Set(keys.map(\.index))
            let preferred = threeWide ? 14 : nil
            let spot = preferred.flatMap { used.contains($0) ? nil : $0 }
                ?? (0 ..< profile.keyCount).first { !used.contains($0) }
            if let spot {
                keys.append(KeyDefinition(index: spot, label: "INTENSITY", colorHex: DeckProfile.goColor,
                                          sfSymbol: "slider.vertical.3", action: .deckChoice(.intensity)))
            }
        }
        return DeckPage(name: "Colour", keys: keys.sorted { $0.index < $1.index })
    }

    /// Colour temperatures offered to begin with.
    static let cctPresets = [2700, 3200, 4000, 4500, 5600, 6000, 6500, 7500, 10000]

    /// One key per preset, in its own colour.
    static func cctKeys(keyCount: Int) -> [KeyDefinition] {
        cctPresets.prefix(max(keyCount - 1, 0)).enumerated().map { index, kelvin in
            KeyDefinition(index: index, label: "\(kelvin)K", colorHex: colourHex(kelvin: kelvin),
                          action: .colourTemperature(kelvin: kelvin))
        }
    }

    /// Roughly how a light of that colour temperature looks, as "#RRGGBB"
    /// (Tanner Helland's fit to the blackbody curve, good from 1000-40000 K).
    static func colourHex(kelvin: Int) -> String {
        let t = Double(min(max(kelvin, 1000), 40000)) / 100
        func clamp(_ v: Double) -> Int { Int(min(max(v, 0), 255).rounded()) }
        let red = t <= 66 ? 255 : clamp(329.698727446 * pow(t - 60, -0.1332047592))
        let green = t <= 66 ? clamp(99.4708025861 * log(t) - 161.1195681661)
                            : clamp(288.1221695283 * pow(t - 60, -0.0755148492))
        let blue = t >= 66 ? 255 : t <= 19 ? 0 : clamp(138.5177312231 * log(t - 10) - 305.0447927307)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// Pale keys (a 3200K preset, a yellow swatch) get black text so it stays
    /// readable; everything else keeps white.
    static func wantsDarkText(on hex: String) -> Bool {
        guard let colour = HexColor(hex) else { return false }
        let luminance = 0.2126 * colour.red + 0.7152 * colour.green + 0.0722 * colour.blue
        return luminance > 0.6
    }

    private static func page(named name: String, in profile: DeckProfile) -> DeckPage? {
        profile.pages.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The shipped 15-key layout: 3 wide, 5 high (the deck in portrait).
    private static func isThreeWide(_ profile: DeckProfile) -> Bool {
        profile.keyCount == 15 && DeckGeometry(keyCount: 15, orientation: profile.orientation).logicalColumns == 3
    }

    /// Swaps the Menu key for Return to Keypad, in Menu's spot on the 15-key
    /// deck (bottom middle) so the same key always goes keypad <-> Quick Keys,
    /// else on the last key. It's still a Menu key underneath: a tap goes to
    /// the keypad, a hold opens the menu of pages.
    private static func withReturnKey(_ source: [KeyDefinition], keyCount: Int, threeWide: Bool) -> [KeyDefinition] {
        let returnIndex = threeWide ? 13 : max(keyCount - 1, 0)
        var keys = source.filter { $0.action != .mainMenu && $0.index != returnIndex }
        keys.append(KeyDefinition(index: returnIndex, label: returnLabel, colorHex: DeckProfile.pageColor,
                                  sfSymbol: returnSymbol, action: .mainMenu))
        return keys
    }

    static let returnLabel = "Return to Keypad"

    /// Where a tap on the Menu key goes: from the keypad to Quick Keys (with
    /// nothing selected, nowhere: only a hold does anything), from anywhere
    /// else back to the keypad. A profile with no keypad page just steps
    /// through its pages.
    enum MenuTap: Equatable {
        case quickKeys(returnTo: Int)
        case page(Int)
        case nothing
    }

    static func menuTap(onPage index: Int, overlay: Overlay?, profile: DeckProfile, hasSelection: Bool) -> MenuTap {
        guard let keypad = keypadPageIndex(in: profile) else {
            return .page(nextPage(after: index, pageCount: profile.pages.count))
        }
        guard overlay == nil, index == keypad else { return .page(keypad) }
        return hasSelection ? .quickKeys(returnTo: keypad) : .nothing
    }

    static let nothingSelected = "Nothing Selected"

    /// What the Menu key reads: on the keypad, "Quick Keys" (where a tap
    /// goes) or "Nothing Selected"; the page's name elsewhere; nil (its own
    /// Return to Keypad label) on Quick Keys and the colour keys.
    static func menuLabel(onPage index: Int, overlay: Overlay?, profile: DeckProfile, pageName: String?,
                          hasSelection: Bool) -> String? {
        switch overlay {
        case .selection?, .colour?:
            return nil
        case nil:
            if index == quickKeysPageIndex(in: profile) { return nil }
            if index == keypadPageIndex(in: profile) { return hasSelection ? quickKeysName : nothingSelected }
            return pageName
        default:
            return pageName
        }
    }

    /// A return-key arrow, for the way back to the keypad.
    static let returnSymbol = "arrow.turn.down.left"

    /// The page with the keypad's digits on it, for going back after a Clear.
    static func keypadPageIndex(in profile: DeckProfile) -> Int? {
        profile.pages.firstIndex { page in
            page.keys.contains { if case .keypadDigit? = $0.action { true } else { false } }
        }
    }

    /// The main menu: one key per page, so new pages appear by themselves.
    static func menuPage(profile: DeckProfile) -> DeckPage {
        let palette = ["#2D4FA3", "#1E7D32", "#8A5A00", "#6A3FA0", "#0E7C86", "#B23B1E"]
        let keys = profile.pages.prefix(profile.keyCount).enumerated().map { index, page in
            KeyDefinition(index: index, label: page.name, colorHex: palette[index % palette.count],
                          action: .switchPage(index))
        }
        return DeckPage(name: "Main Menu", keys: Array(keys))
    }

    /// The next page, wrapping round (Menu on a profile with no keypad).
    static func nextPage(after index: Int, pageCount: Int) -> Int {
        (index + 1) % max(pageCount, 1)
    }

    /// A key as it reads on a page: the Menu key shows the page's name, and a
    /// workspace key with no label shows the workspace's name from Titan.
    static func displayed(_ key: KeyDefinition?, onPage pageName: String?,
                          workspaceNames: [Int: String] = [:]) -> KeyDefinition? {
        guard var key else { return nil }
        switch key.action {
        case .mainMenu?:
            if let pageName, !pageName.isEmpty { key.label = pageName }
        case .recallWorkspace(let number)?:
            if key.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let name = workspaceNames[number]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                key.label = name.isEmpty ? "VIEW\n\(number)" : name
            }
        default:
            break
        }
        return key
    }

    // MARK: Loading

    /// The TitanDeck icon's keys, row by row (4 x 4).
    static let iconColours: [[String]] = [
        ["#207C33", "#207C33", "#207C33", "#2C50A2"],
        ["#B03A1E", "#B03A1E", "#B03A1E", "#2C50A2"],
        ["#207C33", "#B03A1E", "#2C50A2", "#207C33"],
        ["#2A2A2A", "#2A2A2A", "#2A2A2A", "#2C50A2"],
    ]
    /// Frames per shine across the deck (at 10 a second: one every 2.8 s).
    static let splashPeriod = 28

    /// The deck while the loading screen is up: the TitanDeck icon spread
    /// over the keys, with a shine sweeping across it corner to corner.
    static func splashPage(columns: Int, keyCount: Int, frame: Int) -> DeckPage {
        let columns = max(columns, 1)
        let rows = max((keyCount + columns - 1) / columns, 1)
        let width = 0.3
        let phase = Double(((frame % splashPeriod) + splashPeriod) % splashPeriod) / Double(splashPeriod) * (1 + 3 * width) - width
        let keys = (0 ..< keyCount).map { index -> KeyDefinition in
            let row = index / columns, column = index % columns
            let base = iconColours[min(row * 4 / rows, 3)][min(column * 4 / columns, 3)]
            let along = Double(row + column) / Double(max(rows + columns - 2, 1))
            let shine = max(0, 1 - abs(along - phase) / width)
            return KeyDefinition(index: index, label: "", colorHex: blend(base, toward: "#FFFFFF", by: shine * 0.6))
        }
        return DeckPage(name: "TitanDeck", keys: keys)
    }

    /// `amount` (0...1) of the way from one colour to another.
    static func blend(_ from: String, toward to: String, by amount: Double) -> String {
        guard let a = HexColor(from), let b = HexColor(to) else { return from }
        let t = min(max(amount, 0), 1)
        return HexColor(red: a.red + (b.red - a.red) * t, green: a.green + (b.green - a.green) * t,
                        blue: a.blue + (b.blue - a.blue) * t).hexString
    }

    // MARK: Drawing

    /// How tall a label may be, as a share of the key: a lone digit or "@"
    /// fills most of the key so it reads from across the desk, short words
    /// get big type, longer labels stay at the usual size.
    static func labelScale(_ label: String, hasIcon: Bool) -> CGFloat {
        guard !hasIcon else { return 0.24 }
        switch longestLine(label) {
        case ...2: return 0.66
        case ...4: return 0.40
        case ...6: return 0.30
        default: return 0.24
        }
    }

    /// Characters on the label's longest line ("GO\n12" counts as 2).
    static func longestLine(_ label: String) -> Int {
        label.split(separator: "\n").map(\.count).max() ?? 0
    }

    private static func isIntensity(_ action: TitanAction) -> Bool {
        if case .adjustIntensity = action { return true }
        return false
    }

    private static func isColourTemperature(_ action: TitanAction) -> Bool {
        if case .colourTemperature = action { return true }
        return false
    }

    private static func defaultIntensityKeys(keyCount: Int) -> [KeyDefinition] {
        [1.0, 5, 10, -1, -5, -10].prefix(max(keyCount - 1, 0)).enumerated().map { index, percent in
            KeyDefinition(index: index, label: "\(percent > 0 ? "+" : "")\(Int(percent))%",
                          colorHex: percent > 0 ? DeckProfile.goColor : DeckProfile.releaseColor,
                          action: .adjustIntensity(percent: percent))
        }
    }
}
