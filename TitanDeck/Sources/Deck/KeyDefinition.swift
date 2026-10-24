// Deck/KeyDefinition.swift
import Foundation

/// One key on one deck page. Everything the editor saves lands here and
/// everything drawn on the deck is rendered from it.
struct KeyDefinition: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Key position on the deck, 0-based, left to right then top to bottom.
    var index: Int
    var label: String
    var colorHex: String = "#2A2A2A"
    var sfSymbol: String? = nil
    /// An emoji drawn in place of the SF Symbol ("🔥"). Takes priority if both are set.
    var emoji: String? = nil
    var action: TitanAction?
    /// A second look for the key: shown while it's held, until it's pressed
    /// again, or while its playback is live (see `PressedStyle.Mode`).
    var pressedStyle: PressedStyle? = nil

    /// What changes when the key is pressed. Anything left nil stays as normal.
    struct PressedStyle: Codable, Hashable {
        enum Mode: String, Codable, CaseIterable, Identifiable {
            /// Only while the key is held down.
            case held
            /// Press once to switch to this look, press again to switch back.
            case latch
            /// While the key's playback is live on Titan.
            case live

            var id: Self { self }

            var title: String {
                switch self {
                case .held: "While held"
                case .latch: "Until pressed again"
                case .live: "While the playback is live"
                }
            }
        }

        var mode: Mode? = nil
        var colorHex: String? = nil
        var label: String? = nil
        var sfSymbol: String? = nil
        var emoji: String? = nil

        var resolvedMode: Mode { mode ?? .held }
    }

    /// The key as it should be drawn: the pressed look laid over the normal
    /// one when `pressed`, otherwise unchanged.
    func appearance(pressed: Bool) -> KeyDefinition {
        guard pressed, let style = pressedStyle else { return self }
        var shown = self
        if let colour = style.colorHex { shown.colorHex = colour }
        if let label = style.label { shown.label = label }
        if let emoji = style.emoji, !emoji.isEmpty {
            shown.emoji = emoji
            shown.sfSymbol = nil
        } else if let symbol = style.sfSymbol, !symbol.isEmpty {
            shown.sfSymbol = symbol
            shown.emoji = nil
        }
        return shown
    }

    /// Whether to draw the pressed look, given what the deck knows: the key is
    /// held, it's latched on, or its playback is live.
    func showsPressedLook(held: Bool, latched: Bool, live: Bool) -> Bool {
        guard let style = pressedStyle else { return false }
        switch style.resolvedMode {
        case .held: return held
        case .latch: return latched
        case .live: return live || held
        }
    }

    /// Keeps an emoji field to a couple of characters ("🔴" or "🔴🎬"): the key
    /// has room for little more, and flags and skin tones are one character each.
    static func cleanEmoji(_ text: String) -> String? {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2))
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// The colours offered for keys: the built-in swatches plus the custom
/// colours you've added. Stored as a list of "#RRGGBB" strings.
enum DeckPalette {
    static let builtIn = ["#1E7D32", "#B23B1E", "#2D4FA3", "#C78A00", "#6A3FA0", "#0E7C86", "#2A2A2A", "#000000"]
    /// UserDefaults key for the saved custom colours.
    static let storageKey = "deck.customColours"
    static let maxCustom = 24

    /// Adds a colour (newest first) unless it's already offered. Oldest drop off past the limit.
    static func adding(_ hex: String, to custom: [String]) -> [String] {
        let colour = hex.uppercased()
        guard !builtIn.contains(colour), !custom.contains(colour) else { return custom }
        return Array(([colour] + custom).prefix(maxCustom))
    }

    static func removing(_ hex: String, from custom: [String]) -> [String] {
        custom.filter { $0 != hex.uppercased() }
    }

    static func decode(_ stored: String) -> [String] {
        stored.split(separator: ",").map { String($0).uppercased() }.filter { $0.hasPrefix("#") && $0.count == 7 }
    }

    static func encode(_ custom: [String]) -> String { custom.joined(separator: ",") }
}
