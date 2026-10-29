// Deck/DeckGroups.swift
import Foundation

/// The Groups page (0.38): pressing Nothing Selected on the keypad shows the
/// groups of one set, a press selects that group on the desk and goes to
/// Quick Keys. A set is one page of Titan's Groups window (Groups page 2 for
/// the first, then on); the set picked is remembered, and SET changes it.
/// Pure, so it's tested.
enum DeckGroups {
    /// Settings > Deck > Groups page: the sets (their names, so their
    /// number), the Titan Groups page of the first, and the set in use.
    struct Settings: Codable, Equatable {
        var names = ["Set 1", "Set 2", "Set 3"]
        /// Titan's Groups page (from 1) that set 1 is on; the next sets follow.
        var firstPage = 2
        /// The set picked on the deck (0-based), kept for next time.
        var chosen: Int?

        static let key = "deck.groupSets"

        static func load(_ defaults: UserDefaults = .standard) -> Settings {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
        }

        func save(_ defaults: UserDefaults = .standard) {
            if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
        }

        /// The set to show: the one picked, if there still is one.
        var current: Int? {
            guard let chosen, names.indices.contains(chosen) else { return nil }
            return chosen
        }

        func name(_ set: Int) -> String {
            let name = names.indices.contains(set) ? names[set].trimmingCharacters(in: .whitespaces) : ""
            return name.isEmpty ? "Set \(set + 1)" : name
        }

        /// Titan's Groups page for a set, 0-based (as `/titan/handles/Groups/<page>` takes it).
        func titanPage(_ set: Int) -> Int { max(firstPage, 1) - 1 + set }
    }

    /// One of Titan's groups on the set's page.
    struct Group: Equatable {
        var titanId: Int
        var name: String
    }

    static let colour = "#1E5E3A"

    /// The sets, the one in use lit, with BACK.
    static func setsPage(settings: Settings, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        var keys = settings.names.indices.prefix(back).map { set in
            KeyDefinition(index: set, label: settings.name(set),
                          colorHex: set == settings.current ? DeckProfile.goColor : colour,
                          action: .deckChoice(.pickGroupSet(set)))
        }
        keys.append(backKey(back))
        return DeckPage(name: "Group Sets", keys: keys)
    }

    /// A set's groups (nil while Titan's being asked), SET to change set, BACK.
    static func groupsPage(set: Int, settings: Settings, groups: [Group]?, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        let setKey = max(back - 1, 0)
        var keys: [KeyDefinition]
        if let groups {
            keys = groups.prefix(setKey).enumerated().map { slot, group in
                KeyDefinition(index: slot, label: DeckFX.short(group.name, 24), colorHex: colour,
                              action: .deckChoice(.pickGroup(titanId: group.titanId)))
            }
            if keys.isEmpty && setKey > 0 {
                keys = [KeyDefinition(index: 0, label: "No groups on\nGroups page \(settings.titanPage(set) + 1)",
                                      colorHex: "#3A3A3C")]
            }
        } else {
            keys = setKey > 0 ? [KeyDefinition(index: 0, label: "Loading...", colorHex: "#3A3A3C")] : []
        }
        if back > 0 {
            keys.append(KeyDefinition(index: setKey, label: "SET\n" + DeckFX.short(settings.name(set)),
                                      colorHex: DeckProfile.pageColor, sfSymbol: "square.stack.3d.up",
                                      action: .deckChoice(.changeGroupSet)))
        }
        keys.append(backKey(back))
        return DeckPage(name: settings.name(set), keys: keys)
    }

    /// Titan's group handles on a set's page as the deck's groups, in Titan's
    /// order; a group without a legend is "Group" and its position.
    static func groups(_ handles: [(titanId: Int?, legend: String, index: Int?)]) -> [Group] {
        handles.compactMap { handle in
            guard let id = handle.titanId else { return nil }
            let name = handle.legend.trimmingCharacters(in: .whitespacesAndNewlines)
            return Group(titanId: id, name: name.isEmpty ? "Group \((handle.index ?? 0) + 1)" : name)
        }
    }

    private static func backKey(_ index: Int) -> KeyDefinition {
        KeyDefinition(index: index, label: "BACK", colorHex: DeckCues.backColour, sfSymbol: "arrow.uturn.backward",
                      action: .deckChoice(.back))
    }
}
