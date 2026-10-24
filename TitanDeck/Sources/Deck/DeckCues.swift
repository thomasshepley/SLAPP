// Deck/DeckCues.swift
import Foundation

/// A Titan playback picked onto a deck GO slot with Connect Cue. Titan's
/// handles carry no reliable user number (see CLAUDE.md), so it's fired by
/// titanId; page and position are kept so the label still makes sense.
struct CueRef: Codable, Hashable {
    var titanId: Int
    var userNumber: Int?
    /// Titan playback page and position on it, both 0-based.
    var page: Int
    var index: Int
    var legend: String
    /// Fade times last set from the deck, in seconds, for the key labels.
    var fadeIn: Double?
    var fadeOut: Double?

    /// "Fire" or, with no legend, "P3 / 5".
    var title: String {
        let name = legend.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "P\(page + 1) / \(index + 1)" : name
    }
}

/// Which cue sits on which GO slot (slot 0 is GO 1).
struct CueSlot: Codable, Hashable {
    var slot: Int
    var cue: CueRef
}

/// A playback Titan reported, as the deck needs it for picking.
struct CueChoice: Hashable {
    var titanId: Int
    var userNumber: Int?
    var page: Int
    var index: Int
    var legend: String
    var isActive: Bool

    var ref: CueRef {
        CueRef(titanId: titanId, userNumber: userNumber, page: page, index: index, legend: legend)
    }
}

/// The fixture-number ranges whose flash fades instead of snapping.
struct FlashFadeRule: Codable, Hashable, Identifiable {
    var id = UUID()
    var from: Int
    var to: Int
    var seconds: Double

    func covers(_ fixture: Int) -> Bool { (min(from, to) ... max(from, to)).contains(fixture) }
}

enum DeckCues {
    /// Fade times offered for a cue's fade in or out, in seconds.
    static let fadeTimes: [Double] = [0, 0.5, 1, 2, 3, 5, 8, 10, 15, 20, 30, 60]

    static let assignColour = "#B23B1E"
    static let backColour = "#3A3A3C"

    // MARK: Flash fades

    /// UserDefaults key for the flash fade rules.
    static let fadeRulesKey = "deck.flashFadeRules"

    /// The fade for a fixture: the first rule that covers it, or nil (snap).
    static func flashFade(forFixture fixture: Int?, rules: [FlashFadeRule]) -> Double? {
        guard let fixture else { return nil }
        return rules.first { $0.covers(fixture) && $0.seconds > 0 }?.seconds
    }

    static func decodeRules(_ data: Data?) -> [FlashFadeRule] {
        data.flatMap { try? JSONDecoder().decode([FlashFadeRule].self, from: $0) } ?? []
    }

    // MARK: Labels

    /// Seconds without trailing zeros: "0.5s", "5s".
    static func secondsText(_ seconds: Double) -> String {
        "\(TitanEndpoints.format(number: seconds))s"
    }

    /// How a cue key reads, given what's on the slots.
    static func displayed(_ key: KeyDefinition, slots: [CueSlot]) -> KeyDefinition {
        var key = key
        let blank = key.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch key.action {
        case .cueGo(let slot)?:
            if blank {
                key.label = cue(slot, in: slots).map { "GO\n\($0.title)" } ?? "GO \(slot + 1)\n-"
            }
        case .cueFade(let slot, let fadeOut)?:
            let cue = cue(slot, in: slots)
            let time = fadeOut ? cue?.fadeOut : cue?.fadeIn
            if blank {
                key.label = "\(fadeOut ? "FADE OUT" : "FADE IN")\n\(cue == nil ? "-" : time.map(secondsText) ?? "?")"
            }
        default:
            break
        }
        return key
    }

    static func cue(_ slot: Int, in slots: [CueSlot]) -> CueRef? {
        slots.first { $0.slot == slot }?.cue
    }

    // MARK: Picker pages

    /// Connect Cue: each GO turns red to pick a cue for it, the key under an
    /// assigned GO offers Unassign, and Connect Cue itself becomes Done.
    static func connectPage(from page: DeckPage, slots: [CueSlot]) -> DeckPage {
        var keys: [KeyDefinition] = []
        for key in page.keys {
            switch key.action {
            case .cueGo(let slot)?:
                let current = cue(slot, in: slots)
                keys.append(KeyDefinition(index: key.index,
                                          label: current.map { "PICK\n\($0.title)" } ?? "PICK\nGO \(slot + 1)",
                                          colorHex: assignColour, action: .deckChoice(.assignSlot(slot))))
            case .cueFade(let slot, false)?:
                guard cue(slot, in: slots) != nil else { continue }
                keys.append(KeyDefinition(index: key.index, label: "UNASSIGN\n\(slot + 1)", colorHex: backColour,
                                          action: .deckChoice(.unassignSlot(slot))))
            case .connectCue?:
                keys.append(KeyDefinition(index: key.index, label: "DONE", colorHex: DeckProfile.goColor,
                                          action: .deckChoice(.done)))
            default:
                continue
            }
        }
        if !keys.contains(where: { $0.action == .deckChoice(.done) }) {
            keys.append(KeyDefinition(index: doneIndex(page), label: "DONE", colorHex: DeckProfile.goColor,
                                      action: .deckChoice(.done)))
        }
        return DeckPage(name: "Connect Cue", keys: keys)
    }

    /// Titan's playback pages that have something on them, a screenful at a
    /// time starting at `first`, with More when they don't all fit and Back.
    static func pagesPage(cues: [CueChoice], keyCount: Int, first: Int) -> DeckPage {
        let pages = Array(Set(cues.map(\.page))).sorted()
        let back = max(keyCount - 1, 0)
        let room = pages.count > back ? max(back - 1, 0) : back
        let start = pages.indices.contains(first) ? first : 0
        let shown = Array(pages.dropFirst(start).prefix(room))
        var keys = shown.enumerated().map { slot, page in
            let count = cues.filter { $0.page == page }.count
            return KeyDefinition(index: slot, label: "PAGE \(page + 1)\n\(count) cue\(count == 1 ? "" : "s")",
                                 colorHex: DeckProfile.pageColor, action: .deckChoice(.titanPage(page)))
        }
        if pages.count > room, back > 0 {
            let next = start + room < pages.count ? start + room : 0
            keys.append(KeyDefinition(index: back - 1, label: "MORE", colorHex: backColour,
                                      sfSymbol: "arrow.right", action: .deckChoice(.morePages(from: next))))
        }
        keys.append(backKey(back))
        return DeckPage(name: pages.isEmpty ? "No cues from Titan" : "Titan pages", keys: keys)
    }

    /// The cues on one Titan page, in position order, live ones green.
    static func cuesPage(cues: [CueChoice], page: Int, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        let onPage = cues.filter { $0.page == page }.sorted { $0.index < $1.index }.prefix(back)
        var keys = onPage.enumerated().map { slot, cue in
            KeyDefinition(index: slot, label: cue.ref.title,
                          colorHex: cue.isActive ? DeckProfile.goColor : "#2A2A2A",
                          action: .deckChoice(.pickCue(titanId: cue.titanId)))
        }
        keys.append(backKey(back))
        return DeckPage(name: "Page \(page + 1)", keys: keys)
    }

    /// Fade times to choose from, the current one highlighted.
    static func fadePage(current: Double?, fadeOut: Bool, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        var keys = fadeTimes.prefix(back).enumerated().map { slot, seconds in
            KeyDefinition(index: slot, label: secondsText(seconds),
                          colorHex: seconds == current ? DeckProfile.goColor : (fadeOut ? "#5A2A1E" : "#1E3A5A"),
                          action: .deckChoice(.fadeTime(seconds)))
        }
        keys.append(backKey(back))
        return DeckPage(name: fadeOut ? "Fade out" : "Fade in", keys: keys)
    }

    private static func backKey(_ index: Int) -> KeyDefinition {
        KeyDefinition(index: index, label: "BACK", colorHex: backColour, sfSymbol: "arrow.uturn.backward",
                      action: .deckChoice(.back))
    }

    /// Where Done goes when the page has no Connect Cue key: the Menu key's spot.
    private static func doneIndex(_ page: DeckPage) -> Int {
        page.keys.first { $0.action == .mainMenu }?.index ?? (page.keys.map(\.index).max() ?? 0)
    }
}
