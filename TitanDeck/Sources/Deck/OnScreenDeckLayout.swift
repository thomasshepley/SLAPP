// Deck/OnScreenDeckLayout.swift
import Foundation

/// How the on-screen deck uses the space it's given (0.43). Keys keep the
/// physical deck's layout (the keypad's digits stay where your hands expect
/// them) and grow to fill the space, so nothing scrolls. Only when the
/// layout can't fit thumb-sized keys across (an 8-wide wall on a phone held
/// upright) does it reflow: to half as wide if that fits, scrolling if it must.
///
/// Wider than tall with room to spare (iPhone Duo open and held like a book,
/// iPad, iPhone sideways) the screen splits in two down the middle: what's
/// selected and the pages on the leading side, the keys on the trailing
/// side, with a gap down the middle so no key sits on the Duo's fold.
/// Decided by size class and shape, never by device type - see Apple's
/// iPhone Duo guidance. Pure, so it's tested.
enum OnScreenDeckLayout {
    static let spacing = 10.0
    /// Smallest key worth pressing (Apple's touch target is 44 pt).
    static let smallestKey = 48.0
    /// Past this a key stops looking like a key.
    static let largestKey = 180.0
    /// The gap down the middle in the two-sided layout, clear of the fold.
    static let foldGap = 40.0
    /// Narrowest the selection side can be in the two-sided layout.
    static let smallestSidePanel = 240.0

    struct Grid: Equatable {
        var columns: Int
        var rows: Int
        /// Each key's width and height, in points.
        var side: Double
        /// True when the keys don't all fit and the grid scrolls.
        var scrolls: Bool
    }

    static func grid(keyCount: Int, deckColumns: Int, width: Double, height: Double) -> Grid {
        let count = max(keyCount, 1)
        let columns = min(max(deckColumns, 1), count)
        let rows = rowCount(count, columns)
        let across = fit(width, columns)
        let side = min(across, fit(height, rows), largestKey)
        if side >= smallestKey {
            return Grid(columns: columns, rows: rows, side: side, scrolls: false)
        }
        if across >= smallestKey {
            // Wide enough, just too many rows: same layout, scrolling.
            return Grid(columns: columns, rows: rows, side: min(across, largestKey), scrolls: true)
        }
        // Too narrow: fewer columns, a whole fraction of the deck's width if one fits.
        let fraction = (1 ..< columns).reversed().first { columns % $0 == 0 && fit(width, $0) >= smallestKey }
        let reflowed = fraction ?? min(columns, max(1, Int((width + spacing) / (smallestKey + spacing))))
        let reflowedRows = rowCount(count, reflowed)
        let reflowedSide = max(0, min(fit(width, reflowed), largestKey))
        return Grid(columns: reflowed, rows: reflowedRows, side: reflowedSide,
                    scrolls: fit(height, reflowedRows) < reflowedSide)
    }

    enum Arrangement: Equatable {
        /// One column: the header above, the keys below.
        case stacked
        /// Selection and pages on the leading side, keys on the trailing side.
        case sideBySide
    }

    /// Side by side when the space is wider than tall, the selection side
    /// has room, and every key still fits in its half without scrolling.
    static func arrangement(keyCount: Int, deckColumns: Int, width: Double, height: Double) -> Arrangement {
        guard width > height else { return .stacked }
        let half = halfWidth(width)
        guard half >= smallestSidePanel else { return .stacked }
        let split = grid(keyCount: keyCount, deckColumns: deckColumns, width: half, height: height)
        return split.scrolls ? .stacked : .sideBySide
    }

    /// Each side's width in the two-sided layout.
    static func halfWidth(_ width: Double) -> Double {
        max(0, (width - foldGap) / 2)
    }

    private static func fit(_ length: Double, _ count: Int) -> Double {
        (length - Double(count - 1) * spacing) / Double(count)
    }

    private static func rowCount(_ keys: Int, _ columns: Int) -> Int {
        (keys + columns - 1) / columns
    }
}
