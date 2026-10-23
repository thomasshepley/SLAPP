// Deck/OnScreenDeckLayout.swift
import Foundation

/// Column count for the on-screen deck. Follows the physical deck's layout
/// when there's room (regular width: iPad, iPhone Duo open), and reflows to
/// fit a phone held upright (compact width). Decided by size class, never
/// by device type - see Apple's iPhone Duo guidance.
enum OnScreenDeckLayout {
    static func columns(keyCount: Int, deckColumns: Int, isCompactWidth: Bool, isCompactHeight: Bool) -> Int {
        guard keyCount > 0 else { return 1 }
        if isCompactWidth && !isCompactHeight {
            return min(4, deckColumns)          // phone portrait: big, thumbable keys
        }
        if isCompactHeight {
            return min(max(deckColumns, 6), keyCount)   // phone landscape: wide and short
        }
        return deckColumns
    }
}
