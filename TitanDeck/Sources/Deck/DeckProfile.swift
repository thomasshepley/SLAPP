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
}

extension DeckProfile {
    static let goColor = "#1E7D32"
    static let releaseColor = "#B23B1E"
    static let pageColor = "#2D4FA3"

    /// The shipped profile: page 1 fires playbacks 1-16, page 2 releases them,
    /// and the last key on every page flips to the next page.
    static func makeDefault(keyCount: Int = 32) -> DeckProfile {
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
