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
    var action: TitanAction?
}
