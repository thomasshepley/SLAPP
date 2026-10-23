// Deck/DeckGeometry.swift
import Foundation

/// Which way the Stream Deck is mounted. Profiles are laid out as you look at
/// the deck; the hardware still numbers its keys in landscape, so a portrait
/// deck needs its key numbers and images turned round.
enum DeckOrientation: String, Codable, CaseIterable, Identifiable {
    case landscape
    /// Turned a quarter turn clockwise: the deck's top edge is on the right.
    case portraitClockwise
    /// Turned a quarter turn anticlockwise: the deck's top edge is on the left.
    case portraitAnticlockwise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .landscape: return "Landscape"
        case .portraitClockwise: return "Portrait (top edge on the right)"
        case .portraitAnticlockwise: return "Portrait (top edge on the left)"
        }
    }
}

/// Maps between the deck's physical key numbers (landscape, as the hardware
/// reports them) and the profile's logical grid (as you see the deck).
struct DeckGeometry: Equatable {
    let keyCount: Int
    let physicalColumns: Int
    let orientation: DeckOrientation

    init(keyCount: Int, orientation: DeckOrientation) {
        self.keyCount = max(keyCount, 1)
        self.physicalColumns = DeckProfile.gridColumns(forKeyCount: max(keyCount, 1))
        self.orientation = orientation
    }

    var physicalRows: Int { (keyCount + physicalColumns - 1) / physicalColumns }

    var logicalColumns: Int { orientation == .landscape ? physicalColumns : physicalRows }

    var logicalRows: Int { orientation == .landscape ? physicalRows : physicalColumns }

    /// Quarter turns to apply to key images so they read upright
    /// (positive = clockwise).
    var imageQuarterTurns: Int {
        switch orientation {
        case .landscape: return 0
        case .portraitClockwise: return -1
        case .portraitAnticlockwise: return 1
        }
    }

    /// The profile key shown on a hardware key, or nil if none maps there.
    func logicalIndex(forPhysical physical: Int) -> Int? {
        guard physical >= 0, physical < keyCount else { return nil }
        let row = physical / physicalColumns, column = physical % physicalColumns
        let logicalRow: Int, logicalColumn: Int
        switch orientation {
        case .landscape:
            return physical
        case .portraitClockwise:
            logicalRow = column
            logicalColumn = physicalRows - 1 - row
        case .portraitAnticlockwise:
            logicalRow = physicalColumns - 1 - column
            logicalColumn = row
        }
        let index = logicalRow * logicalColumns + logicalColumn
        return index < keyCount ? index : nil
    }

    /// The hardware key that shows a profile key.
    func physicalIndex(forLogical logical: Int) -> Int? {
        guard logical >= 0, logical < keyCount else { return nil }
        if orientation == .landscape { return logical }
        return (0..<keyCount).first { logicalIndex(forPhysical: $0) == logical }
    }
}
