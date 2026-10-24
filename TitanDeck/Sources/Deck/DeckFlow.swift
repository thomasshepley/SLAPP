// Deck/DeckFlow.swift
import Foundation

/// The deck's moment-to-moment logic that isn't tied to the hardware: what
/// the keypad has typed, the pages the deck shows in place of a profile page
/// (the main menu, the intensity keys after a selection), and how keys read
/// on the page they're on. Pure, so it's tested without a Stream Deck.
enum DeckFlow {
    /// A page shown in place of the profile page for a moment.
    enum Overlay: Equatable {
        /// The main menu of layouts (Menu key held for 2 s).
        case menu
        /// Fixtures were selected on the keypad ("102 Enter"): the intensity
        /// keys, with a way back to `returnTo`.
        case selection(returnTo: Int)
    }

    // MARK: Keypad

    /// What's been typed on the deck's keypad since the last Enter, Clear or Exit.
    struct KeypadBuffer: Equatable {
        private(set) var text = ""

        /// Feeds in a key's action. Returns true when it was an Enter that
        /// selected fixtures: a plain number, no @ ("102 Enter").
        mutating func apply(_ action: TitanAction) -> Bool {
            switch action {
            case .keypadDigit(let digit):
                text += "\(min(max(digit, 0), 9))"
            case .keypadAt:
                text += "@"
            case .keypadClear, .keypadExit:
                text = ""
            case .keypadEnter:
                let selected = !text.isEmpty && text.allSatisfy(\.isNumber)
                text = ""
                return selected
            default:
                break
            }
            return false
        }
    }

    // MARK: Pages

    /// Shown after a selection: the profile's Intensity page (or, failing
    /// that, the standard nudges) with Return to Keypad on its Menu key.
    static func selectionPage(profile: DeckProfile, returnTo: Int) -> DeckPage {
        let source = profile.pages.first { $0.name.caseInsensitiveCompare("Intensity") == .orderedSame }
            ?? profile.pages.first { page in page.keys.contains { $0.action.map(isIntensity) ?? false } }
        var keys = source?.keys ?? defaultIntensityKeys(keyCount: profile.keyCount)
        let returnIndex = keys.first { $0.action == .mainMenu }?.index ?? max(profile.keyCount - 1, 0)
        keys.removeAll { $0.index == returnIndex }
        keys.append(KeyDefinition(index: returnIndex, label: "Return to Keypad", colorHex: DeckProfile.pageColor,
                                  sfSymbol: "circle.grid.3x3.fill", action: .switchPage(returnTo)))
        return DeckPage(name: "Selection", keys: keys.sorted { $0.index < $1.index })
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

    /// The page to come to from the Menu key: the next one, wrapping round.
    static func nextPage(after index: Int, pageCount: Int) -> Int {
        (index + 1) % max(pageCount, 1)
    }

    /// A key as it reads on a page: the Menu key shows the page's name.
    static func displayed(_ key: KeyDefinition?, onPage pageName: String?) -> KeyDefinition? {
        guard var key, key.action == .mainMenu, let pageName, !pageName.isEmpty else { return key }
        key.label = pageName
        return key
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

    private static func defaultIntensityKeys(keyCount: Int) -> [KeyDefinition] {
        [1.0, 5, 10, -1, -5, -10].prefix(max(keyCount - 1, 0)).enumerated().map { index, percent in
            KeyDefinition(index: index, label: "\(percent > 0 ? "+" : "")\(Int(percent))%",
                          colorHex: percent > 0 ? DeckProfile.goColor : DeckProfile.releaseColor,
                          action: .adjustIntensity(percent: percent))
        }
    }
}
