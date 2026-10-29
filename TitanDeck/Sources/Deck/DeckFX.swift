// Deck/DeckFX.swift
import Foundation

/// The FX page (Test mode, TitanDeck 0.37): Prism video on Titan's Prism
/// layer fixtures ("Layer 1", "Layer 2"), each run through a pixel map that
/// follows a group, so the layer's fixtures change by replacing that group.
///
/// FX > a category (FIRE, CANDLE...) > a version from the FX tab (its Prism
/// Folder / File) > LAYER 1 or LAYER 2 > that layer's page: the clip, BRIGHT /
/// SPEED / CONTRAST / SAT (0-100% pickers), GO / STOP (the pixel map's
/// playback), FIXTURES (USE SEL / ADD / REMOVE, and the FXZone groups) and
/// RELEASE. The Host does the Titan side (Host 0.16, `/api/v1/fx`). Pure, so
/// it's tested.
enum DeckFX {
    /// The two Prism layers the deck drives.
    static let layers = [1, 2]

    /// The effect kinds on the FX page, in order.
    enum Category: String, CaseIterable, Codable, Hashable {
        case fire, candle, lightning, police, fireworks, tv

        var label: String {
            switch self {
            case .fire: "FIRE"
            case .candle: "CANDLE"
            case .lightning: "LIGHTNING"
            case .police: "POLICE"
            case .fireworks: "FIREWORKS"
            case .tv: "TV"
            }
        }

        var colour: String {
            switch self {
            case .fire: "#B23B1E"
            case .candle: "#8A5A00"
            case .lightning: "#3D4F8A"
            case .police: "#1F3FA8"
            case .fireworks: "#6A3FA0"
            case .tv: "#2E6B5E"
            }
        }

        var symbol: String {
            switch self {
            case .fire: "flame.fill"
            case .candle: "flame"
            case .lightning: "cloud.bolt.fill"
            case .police: "light.beacon.max.fill"
            case .fireworks: "sparkles"
            case .tv: "tv.fill"
            }
        }
    }

    /// The controls the layer page adjusts, 0-100%.
    enum Control: String, CaseIterable, Codable, Hashable {
        case brightness, speed, contrast, saturation

        var label: String {
            switch self {
            case .brightness: "BRIGHT"
            case .speed: "SPEED"
            case .contrast: "CONTRAST"
            case .saturation: "SAT"
            }
        }
    }

    /// A version of an effect from the FX tab, with where Prism has it.
    struct Item: Equatable, Identifiable {
        var id: UUID
        var title: String
        var category: Category
        var folder: Int
        var file: Int
    }

    /// A group whose legend starts with "FXZone": a one-press set of fixtures.
    struct Zone: Equatable {
        var titanId: Int
        var name: String
    }

    /// What the deck knows of a layer: the clip it set and the levels it set
    /// (0...1); Titan isn't asked.
    struct LayerState: Equatable {
        var clip: String?
        var levels: [Control: Double] = [:]
    }

    /// How FIXTURES changes a layer's group.
    enum FixturesChange: String, Equatable {
        case replace, add, remove
    }

    /// What a press on the FX pages asks Titan for (AppState sends it to the Host).
    enum Command: Equatable {
        case setVideo(layer: Int, item: Item)
        case setLevel(layer: Int, control: Control, level: Double)
        case go(layer: Int)
        case stop(layer: Int)
        case release(layer: Int)
        case releaseAll
        case fixtures(layer: Int, change: FixturesChange)
        case zone(layer: Int, zone: Zone)
    }

    /// TitanDeck's side of the set-up (FX tab > Prism setup): each layer's
    /// Prism fixture, its pixel map's group and playback, and the names of
    /// the Prism personality's controls.
    struct Settings: Codable, Equatable {
        struct Layer: Codable, Equatable {
            /// The Prism layer fixture's number in Titan (0: not set).
            var fixture = 0
            /// The pixel map's group number (0: not set).
            var group = 0
            /// The pixel map's playback: page and fader, both from 1 (0: not set).
            var playbackPage = 0
            var playbackFader = 0
        }

        var layers = [Layer(), Layer()]
        var dimmer = "Dimmer"
        var folder = "Folder"
        var file = "File"
        var speed = "Speed"
        var contrast = "Contrast"
        var saturation = "Saturation"
        /// Levels go to Titan as 0-100 (else 0-1).
        var levelsAsPercent = true

        static let key = "fx.settings"

        static func load(_ defaults: UserDefaults = .standard) -> Settings {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
        }

        func save(_ defaults: UserDefaults = .standard) {
            if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
        }

        func layer(_ number: Int) -> Layer {
            layers.indices.contains(number - 1) ? layers[number - 1] : Layer()
        }

        func controlName(_ control: Control) -> String {
            switch control {
            case .brightness: dimmer
            case .speed: speed
            case .contrast: contrast
            case .saturation: saturation
            }
        }

        /// A 0...1 level as Titan's attribute editor takes it.
        func value(_ level: Double) -> Double {
            let clamped = min(max(level, 0), 1)
            return levelsAsPercent ? (clamped * 100).rounded() : clamped
        }

        /// The control names the FX tab's probe also asks about.
        var controlNames: [String] { [dimmer, folder, file, speed, contrast, saturation] }
    }

    // MARK: Zones

    static let zonePrefix = "FXZone"

    /// The FXZone groups among Titan's group handles, the prefix taken off
    /// their names ("FXZone Bar" is "Bar"), in Titan's order.
    static func zones(_ groups: [(titanId: Int?, legend: String)]) -> [Zone] {
        groups.compactMap { group in
            guard let id = group.titanId,
                  group.legend.range(of: zonePrefix, options: [.anchored, .caseInsensitive]) != nil else { return nil }
            let name = String(group.legend.dropFirst(zonePrefix.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " -_:").union(.whitespacesAndNewlines))
            return Zone(titanId: id, name: name.isEmpty ? "Zone" : name)
        }
    }

    // MARK: Pages

    static let fxColour = "#5A2E8A"
    static let releaseColour = "#7A1F1F"

    /// Short text for a key: the first `limit` characters.
    static func short(_ text: String, _ limit: Int = 12) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit - 1)) + "."
    }

    /// The FX page: the six categories, each layer (with its clip), RELEASE ALL.
    static func fxPage(profile: DeckProfile, layers: [Int: LayerState], returnTo: Int) -> DeckPage {
        var keys = Category.allCases.enumerated().map { slot, category in
            KeyDefinition(index: slot, label: category.label, colorHex: category.colour, sfSymbol: category.symbol,
                          action: .deckChoice(.fxCategory(category.rawValue)))
        }
        for layer in Self.layers {
            keys.append(KeyDefinition(index: keys.count, label: "LAYER \(layer)\n" + short(layers[layer]?.clip ?? "-"),
                                      colorHex: fxColour, action: .deckChoice(.fxLayer(layer))))
        }
        keys.append(KeyDefinition(index: keys.count, label: "RELEASE\nALL", colorHex: releaseColour,
                                  sfSymbol: "arrow.uturn.down", action: .deckChoice(.fxReleaseAll)))
        let threeWide = DeckFlow.isThreeWide(profile)
        let room = threeWide ? 12 : max(profile.keyCount - 1, 0)
        let shown = DeckFlow.withReturnKey(Array(keys.prefix(room)), keyCount: profile.keyCount, threeWide: threeWide)
        return DeckPage(name: "FX", keys: shown.sorted { $0.index < $1.index })
    }

    /// One category's versions (only those with a Prism Folder and File), with BACK.
    static func versionsPage(category: Category, items: [Item], keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        var keys = items.filter { $0.category == category }.prefix(back).enumerated().map { slot, item in
            KeyDefinition(index: slot, label: short(item.title, 24), colorHex: category.colour,
                          action: .deckChoice(.fxItem(item.id.uuidString)))
        }
        if keys.isEmpty && back > 0 {
            keys = [KeyDefinition(index: 0, label: "No \(category.label)\nin FX tab", colorHex: "#3A3A3C")]
        }
        keys.append(backKey(back))
        return DeckPage(name: category.label, keys: keys)
    }

    /// Which layer the picked version goes on, with what each has now.
    static func layerPickPage(item: Item?, layers: [Int: LayerState], keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        var keys = Self.layers.prefix(back).enumerated().map { slot, layer in
            KeyDefinition(index: slot, label: "LAYER \(layer)\n" + short(layers[layer]?.clip ?? "-"),
                          colorHex: fxColour, action: .deckChoice(.fxLayer(layer)))
        }
        keys.append(backKey(back))
        return DeckPage(name: item.map { short($0.title, 24) } ?? "FX", keys: keys)
    }

    /// A layer's page: its clip (a press picks another), the four levels,
    /// GO / STOP, FIXTURES and RELEASE, with BACK.
    static func layerPage(layer: Int, state: LayerState, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        var templates = [
            KeyDefinition(index: 0, label: "L\(layer)\n" + short(state.clip ?? "-"), colorHex: fxColour,
                          sfSymbol: "film", action: .deckChoice(.fxPickVideo)),
        ]
        for control in Control.allCases {
            templates.append(KeyDefinition(index: templates.count,
                                           label: "\(control.label)\n\(DeckFlow.percentText(state.levels[control]))",
                                           colorHex: "#2D4FA3", action: .deckChoice(.fxControl(control.rawValue))))
        }
        templates += [
            KeyDefinition(index: templates.count, label: "GO", colorHex: DeckProfile.goColor, sfSymbol: "play.fill",
                          action: .deckChoice(.fxGo)),
            KeyDefinition(index: templates.count + 1, label: "STOP", colorHex: "#5A1A1A", sfSymbol: "stop.fill",
                          action: .deckChoice(.fxStop)),
            KeyDefinition(index: templates.count + 2, label: "FIXTURES", colorHex: "#0E7C86", sfSymbol: "lightbulb.2",
                          action: .deckChoice(.fxFixtures)),
            KeyDefinition(index: templates.count + 3, label: "RELEASE", colorHex: releaseColour, sfSymbol: "arrow.uturn.down",
                          action: .deckChoice(.fxRelease)),
        ]
        var keys = Array(templates.prefix(back))
        keys.append(backKey(back))
        return DeckPage(name: "Layer \(layer)", keys: keys)
    }

    /// A level for one control, keypad style: 0% to 100% in tens, the current one lit, with BACK.
    static func levelPage(layer: Int, control: Control, current: Double?, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        let lit = current.map { ($0 * 10).rounded() / 10 }
        var keys = DeckFlow.masterLevels.prefix(back).enumerated().map { slot, level in
            KeyDefinition(index: slot, label: DeckFlow.percentText(level),
                          colorHex: level == lit ? DeckProfile.goColor : "#2D4FA3",
                          action: .deckChoice(.fxLevel(level)))
        }
        keys.append(backKey(back))
        return DeckPage(name: "L\(layer) \(control.label)", keys: keys)
    }

    /// A layer's fixtures: the desk's selection in (USE SEL), added (ADD) or
    /// taken out (REMOVE), then the FXZone groups, with BACK.
    static func fixturesPage(layer: Int, zones: [Zone], keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        var templates = [
            KeyDefinition(index: 0, label: "USE SEL", colorHex: DeckProfile.goColor, sfSymbol: "checkmark.circle",
                          action: .deckChoice(.fxUseSelection)),
            KeyDefinition(index: 1, label: "ADD", colorHex: "#0E7C86", sfSymbol: "plus.circle", action: .deckChoice(.fxAdd)),
            KeyDefinition(index: 2, label: "REMOVE", colorHex: "#7A1F1F", sfSymbol: "minus.circle", action: .deckChoice(.fxRemove)),
        ]
        for zone in zones {
            templates.append(KeyDefinition(index: templates.count, label: short(zone.name, 24), colorHex: "#3D2E6B",
                                           action: .deckChoice(.fxZone(titanId: zone.titanId))))
        }
        var keys = Array(templates.prefix(back))
        keys.append(backKey(back))
        return DeckPage(name: "L\(layer) Fixtures", keys: keys)
    }

    private static func backKey(_ index: Int) -> KeyDefinition {
        KeyDefinition(index: index, label: "BACK", colorHex: DeckCues.backColour, sfSymbol: "arrow.uturn.backward",
                      action: .deckChoice(.back))
    }
}
