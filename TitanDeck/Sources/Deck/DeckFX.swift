// Deck/DeckFX.swift
import Foundation

/// The FX page (Test mode, TitanDeck 0.37; built round the user's own faders
/// in 0.40). An FX in Titan is three faders per Prism layer ("Layer 1",
/// "Layer 2"), recorded by the user: the pixel map FX (over a group), the
/// Prism layer fixture's settings (clip, play mode, speed, 100%) and the
/// fixtures' level. The deck runs them, it doesn't replace them:
///
/// FX > a category (FIRE, CANDLE...) > a version from the FX tab (its Prism
/// Folder / File) > LAYER 1 or LAYER 2 puts that clip on the layer (over the
/// Prism fader's, in the WebAPI user's programmer, until RESET CLIP). A
/// layer's page: CLIP (swap), RUN / STOP (all three faders), LEVEL (the level
/// fader, so the fixtures' intensity stays a fader), ZONE (an FXZone group
/// becomes the pixel map's group) and RESET CLIP. Clip and zone go through
/// the Host (`/api/v1/fx`); the faders straight to Titan. Pure, so it's tested.
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

    /// What the deck knows of a layer: the clip it set, whether it ran the
    /// faders, and the level fader's level (0...1); Titan isn't asked.
    struct LayerState: Equatable {
        var clip: String?
        var levels: [Control: Double] = [:]
        var running = false
        var level: Double?
    }

    /// A layer's three faders in Titan, in the order RUN brings them up.
    enum Fader: CaseIterable, Equatable {
        case prism, pixelMap, level

        var label: String {
            switch self {
            case .prism: "Prism layer fader"
            case .pixelMap: "pixel map fader"
            case .level: "level fader"
            }
        }
    }

    /// What a press on the FX pages asks Titan for (AppState sends the clip
    /// and zone to the Host, the faders straight to Titan).
    enum Command: Equatable {
        /// The clip on the layer fixture (over the Prism fader's).
        case setVideo(layer: Int, item: Item)
        /// RUN: the layer's faders up, the level fader to `level`.
        case go(layer: Int, level: Double)
        /// STOP: the layer's faders released.
        case stop(layer: Int)
        case stopAll
        /// The level fader's level, while the layer runs.
        case level(layer: Int, level: Double)
        /// RESET CLIP: back to the Prism fader's clip.
        case release(layer: Int)
        case releaseAll
        case zone(layer: Int, zone: Zone)
    }

    /// TitanDeck's side of the set-up (FX tab > Prism setup): each layer's
    /// Prism fixture, its pixel map's group and playback, and the names of
    /// the Prism personality's controls.
    struct Settings: Codable, Equatable {
        struct Layer: Codable, Equatable {
            /// The Prism layer fixture's number in Titan, for CLIP (0: not set).
            var fixture = 0
            /// The group the pixel map runs over, for ZONE (0: not set).
            var group = 0
            /// The pixel map fader: page and fader, both from 1 (0: not set).
            var playbackPage = 0
            var playbackFader = 0
            /// The Prism layer fixture's fader (0.40).
            var prismPage = 0
            var prismFader = 0
            /// The fixtures' level fader (0.40).
            var levelPage = 0
            var levelFader = 0

            init() {}

            // Settings saved before 0.40 haven't the new faders.
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                func int(_ key: CodingKeys) throws -> Int { try c.decodeIfPresent(Int.self, forKey: key) ?? 0 }
                fixture = try int(.fixture)
                group = try int(.group)
                playbackPage = try int(.playbackPage)
                playbackFader = try int(.playbackFader)
                prismPage = try int(.prismPage)
                prismFader = try int(.prismFader)
                levelPage = try int(.levelPage)
                levelFader = try int(.levelFader)
            }

            /// Where one of the layer's faders is (page and fader from 1), if set.
            func spot(_ fader: Fader) -> (page: Int, fader: Int)? {
                let (page, number) = switch fader {
                case .prism: (prismPage, prismFader)
                case .pixelMap: (playbackPage, playbackFader)
                case .level: (levelPage, levelFader)
                }
                return page > 0 && number > 0 ? (page, number) : nil
            }

            /// The faders set, in RUN's order.
            var faders: [Fader] { Fader.allCases.filter { spot($0) != nil } }
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
        /// Only the clip's now (0.40): the rest stays on the Prism layer fader.
        var controlNames: [String] { [folder, file] }
    }

    /// Whether a layer runs, from Titan's playbacks: any of its faders
    /// active (brought up on the desk counts too). Nil when none is set or
    /// Titan didn't list them.
    static func running(_ layer: Settings.Layer, cues: [CueChoice]) -> Bool? {
        let found = layer.faders.compactMap { fader in
            layer.spot(fader).flatMap { spot in cues.first { $0.page == spot.page - 1 && $0.index == spot.fader - 1 } }
        }
        return found.isEmpty ? nil : found.contains(where: \.isActive)
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

    /// The FX page: the six categories, each layer (with its clip, green
    /// while it runs), STOP ALL and RESET CLIPS.
    static func fxPage(profile: DeckProfile, layers: [Int: LayerState], returnTo: Int) -> DeckPage {
        var keys = Category.allCases.enumerated().map { slot, category in
            KeyDefinition(index: slot, label: category.label, colorHex: category.colour, sfSymbol: category.symbol,
                          action: .deckChoice(.fxCategory(category.rawValue)))
        }
        for layer in Self.layers {
            keys.append(layerKey(layer, layers[layer], index: keys.count))
        }
        keys.append(KeyDefinition(index: keys.count, label: "STOP\nALL", colorHex: stopColour, sfSymbol: "stop.fill",
                                  action: .deckChoice(.fxStopAll)))
        keys.append(KeyDefinition(index: keys.count, label: "RESET\nCLIPS", colorHex: releaseColour,
                                  sfSymbol: "arrow.uturn.down", action: .deckChoice(.fxReleaseAll)))
        let threeWide = DeckFlow.isThreeWide(profile)
        let room = threeWide ? 12 : max(profile.keyCount - 1, 0)
        let shown = DeckFlow.withReturnKey(Array(keys.prefix(room)), keyCount: profile.keyCount, threeWide: threeWide)
        return DeckPage(name: "FX", keys: shown.sorted { $0.index < $1.index })
    }

    static let stopColour = "#5A1A1A"

    /// A layer's key: its clip, green while its faders run.
    private static func layerKey(_ layer: Int, _ state: LayerState?, index: Int) -> KeyDefinition {
        KeyDefinition(index: index, label: "LAYER \(layer)\n" + clipText(state),
                      colorHex: state?.running == true ? DeckProfile.goColor : fxColour,
                      sfSymbol: state?.running == true ? "play.fill" : nil, action: .deckChoice(.fxLayer(layer)))
    }

    /// The clip the deck put on, or the fader's own.
    private static func clipText(_ state: LayerState?) -> String {
        short(state?.clip ?? "fader clip")
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
            layerKey(layer, layers[layer], index: slot)
        }
        keys.append(backKey(back))
        return DeckPage(name: item.map { short($0.title, 24) } ?? "FX", keys: keys)
    }

    /// A layer's page: CLIP (a press picks another), RUN / STOP (the
    /// layer's faders), LEVEL (the level fader), ZONE and RESET CLIP, with BACK.
    static func layerPage(layer: Int, state: LayerState, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        let templates = [
            KeyDefinition(index: 0, label: "CLIP\n" + clipText(state), colorHex: fxColour, sfSymbol: "film",
                          action: .deckChoice(.fxPickVideo)),
            state.running
                ? KeyDefinition(index: 1, label: "STOP", colorHex: stopColour, sfSymbol: "stop.fill", action: .deckChoice(.fxRun))
                : KeyDefinition(index: 1, label: "RUN", colorHex: DeckProfile.goColor, sfSymbol: "play.fill", action: .deckChoice(.fxRun)),
            KeyDefinition(index: 2, label: "LEVEL\n\(DeckFlow.percentText(state.level ?? 1))", colorHex: "#2D4FA3",
                          sfSymbol: "slider.vertical.3", action: .deckChoice(.fxFaderLevel)),
            KeyDefinition(index: 3, label: "ZONE", colorHex: "#3D2E6B", sfSymbol: "square.grid.3x3",
                          action: .deckChoice(.fxFixtures)),
            KeyDefinition(index: 4, label: "RESET\nCLIP", colorHex: releaseColour, sfSymbol: "arrow.uturn.down",
                          action: .deckChoice(.fxRelease)),
        ]
        var keys = Array(templates.prefix(back))
        keys.append(backKey(back))
        return DeckPage(name: "Layer \(layer)", keys: keys)
    }

    /// The level fader's level, 0% to 100% in tens, the current one lit, with BACK.
    static func faderLevelPage(layer: Int, current: Double?, keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        let lit = ((current ?? 1) * 10).rounded() / 10
        var keys = DeckFlow.masterLevels.prefix(back).enumerated().map { slot, level in
            KeyDefinition(index: slot, label: DeckFlow.percentText(level),
                          colorHex: level == lit ? DeckProfile.goColor : "#2D4FA3",
                          action: .deckChoice(.fxLevel(level)))
        }
        keys.append(backKey(back))
        return DeckPage(name: "L\(layer) LEVEL", keys: keys)
    }

    /// Where a layer's pixel map runs: the FXZone groups (each becomes the
    /// pixel map's group), with BACK.
    static func zonesPage(layer: Int, zones: [Zone], keyCount: Int) -> DeckPage {
        let back = max(keyCount - 1, 0)
        var keys = zones.prefix(back).enumerated().map { slot, zone in
            KeyDefinition(index: slot, label: short(zone.name, 24), colorHex: "#3D2E6B",
                          action: .deckChoice(.fxZone(titanId: zone.titanId)))
        }
        if keys.isEmpty && back > 0 {
            keys = [KeyDefinition(index: 0, label: "No \(zonePrefix)\ngroups", colorHex: "#3A3A3C")]
        }
        keys.append(backKey(back))
        return DeckPage(name: "L\(layer) Zone", keys: keys)
    }

    private static func backKey(_ index: Int) -> KeyDefinition {
        KeyDefinition(index: index, label: "BACK", colorHex: DeckCues.backColour, sfSymbol: "arrow.uturn.backward",
                      action: .deckChoice(.back))
    }
}
