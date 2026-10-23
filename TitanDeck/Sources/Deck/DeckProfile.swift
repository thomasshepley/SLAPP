// Deck/DeckProfile.swift
import Foundation

struct DeckPage: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var keys: [KeyDefinition]

    func key(at index: Int) -> KeyDefinition? {
        keys.first { $0.index == index }
    }
}

struct DeckProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// Number of keys the profile was laid out for (32 = Stream Deck XL / Module 32).
    var keyCount: Int
    var pages: [DeckPage]
    /// True until someone edits it - lets the app re-flow the default to fit a
    /// smaller deck without trampling a hand-built profile.
    var isBuiltInDefault: Bool = false
    /// How the deck is mounted. Keys are laid out as you see the deck.
    var orientation: DeckOrientation = .landscape

    var geometry: DeckGeometry {
        DeckGeometry(keyCount: keyCount, orientation: orientation)
    }
}

extension DeckProfile {
    /// Decodes profiles saved before `orientation` existed (they're landscape).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        keyCount = try container.decode(Int.self, forKey: .keyCount)
        pages = try container.decode([DeckPage].self, forKey: .pages)
        isBuiltInDefault = try container.decodeIfPresent(Bool.self, forKey: .isBuiltInDefault) ?? false
        orientation = try container.decodeIfPresent(DeckOrientation.self, forKey: .orientation) ?? .landscape
    }
}

extension DeckProfile {
    static let goColor = "#1E7D32"
    static let releaseColor = "#B23B1E"
    static let pageColor = "#2D4FA3"

    static let digitColor = "#3A3A3C"
    static let menuColor = "#6A3FA0"
    static let menuSymbol = "square.grid.2x2.fill"

    /// The shipped profile, laid out for a 15-key Stream Deck in portrait:
    ///
    ///     Keypad              Intensity           Playbacks
    ///     1     2     3       +1%  +5%  +10%      GO 1  GO 2  GO 3
    ///     4     5     6       -1%  -5%  -10%      GO 4  GO 5  GO 6
    ///     7     8     9       .    .    .         REL 1 REL 2 REL 3
    ///     Exit  0     Enter   .    .    .         REL 4 REL 5 REL 6
    ///     Clear Menu  @       Clear Menu .        .     Menu  .
    ///
    /// Menu (hold 2 s) opens the main menu of layouts. On any other deck size
    /// the same keys are placed in order with Menu on the last key.
    static func makeDefault(keyCount: Int = 15, orientation: DeckOrientation = .portraitClockwise) -> DeckProfile {
        let count = max(keyCount, 2)
        let exact = count == 15 && DeckGeometry(keyCount: count, orientation: orientation).logicalColumns == 3

        func key(_ label: String, _ color: String, _ action: TitanAction, symbol: String? = nil) -> KeyDefinition {
            KeyDefinition(index: 0, label: label, colorHex: color, sfSymbol: symbol, action: action)
        }
        let menu = key("Menu", menuColor, .mainMenu, symbol: menuSymbol)
        let clear = key("CLEAR", releaseColor, .keypadClear)

        /// `rows` is the 3-wide portrait layout; nil = empty key.
        func page(_ name: String, _ rows: [[KeyDefinition?]]) -> DeckPage {
            var keys: [KeyDefinition] = []
            if exact {
                for (r, row) in rows.enumerated() {
                    for (c, template) in row.enumerated() {
                        guard var k = template else { continue }
                        k.index = r * 3 + c
                        keys.append(k)
                    }
                }
            } else {
                let body = rows.flatMap { $0 }.compactMap { $0 }.filter { $0.action != .mainMenu }
                for (i, template) in body.prefix(count - 1).enumerated() {
                    var k = template
                    k.index = i
                    keys.append(k)
                }
                var m = menu
                m.index = count - 1
                keys.append(m)
            }
            return DeckPage(name: name, keys: keys)
        }

        func digit(_ d: Int) -> KeyDefinition { key("\(d)", digitColor, .keypadDigit(d)) }
        func nudge(_ p: Double) -> KeyDefinition {
            key("\(p > 0 ? "+" : "")\(Int(p))%", p > 0 ? goColor : releaseColor, .adjustIntensity(percent: p))
        }

        let keypad = page("Keypad", [
            [digit(1), digit(2), digit(3)],
            [digit(4), digit(5), digit(6)],
            [digit(7), digit(8), digit(9)],
            [key("EXIT", "#8A5A00", .keypadExit), digit(0), key("ENTER", goColor, .keypadEnter)],
            [clear, menu, key("@", pageColor, .keypadAt)],
        ])
        let intensity = page("Intensity", [
            [nudge(1), nudge(5), nudge(10)],
            [nudge(-1), nudge(-5), nudge(-10)],
            [nil, nil, nil],
            [nil, nil, nil],
            [clear, menu, nil],
        ])
        let playbacks = page("Playbacks", [
            (1...3).map { key("GO\n\($0)", goColor, .playbackGo(userNumber: $0)) },
            (4...6).map { key("GO\n\($0)", goColor, .playbackGo(userNumber: $0)) },
            (1...3).map { key("REL\n\($0)", releaseColor, .playbackRelease(userNumber: $0)) },
            (4...6).map { key("REL\n\($0)", releaseColor, .playbackRelease(userNumber: $0)) },
            [nil, menu, nil],
        ])

        return DeckProfile(name: "Default", keyCount: count, pages: [keypad, intensity, playbacks],
                           isBuiltInDefault: true, orientation: orientation)
    }

    /// The original playback-only layout (GO 1-16 / REL 1-16, last key pages),
    /// kept for tests and anyone who wants a big playback wall.
    static func makePlaybackWall(keyCount: Int = 32) -> DeckProfile {
        let count = max(keyCount, 2)
        let pageKey = count - 1
        let playbackCount = min(16, pageKey)

        func page(name: String, labelPrefix: String, color: String, next: Int,
                  action: (Int) -> TitanAction) -> DeckPage {
            var keys = (0..<playbackCount).map { i in
                KeyDefinition(index: i, label: "\(labelPrefix)\n\(i + 1)", colorHex: color, action: action(i + 1))
            }
            keys.append(KeyDefinition(index: pageKey, label: "Page\n\(next + 1)", colorHex: pageColor,
                                      sfSymbol: "arrow.right.square", action: .switchPage(next)))
            return DeckPage(name: name, keys: keys)
        }

        return DeckProfile(
            name: "Default",
            keyCount: count,
            pages: [
                page(name: "Go", labelPrefix: "GO", color: goColor, next: 1) { .playbackGo(userNumber: $0) },
                page(name: "Release", labelPrefix: "REL", color: releaseColor, next: 0) { .playbackRelease(userNumber: $0) },
            ],
            isBuiltInDefault: true
        )
    }
}
