// Remote/FloatingDeckLayout.swift
import Foundation

/// Where the floating deck sits over the remote desktop, and how big (0.44).
/// Its width is the one thing you size: the keys keep the deck's own layout,
/// so its height follows. The size and place are kept as fractions of the
/// space it floats in, so they survive turning the iPad and the next launch,
/// and it's always kept wholly on screen. Pure, so it's tested.
enum FloatingDeckLayout {
    /// Round the keys, inside the glass.
    static let padding = 10.0
    static let spacing = 6.0
    /// The top strip: drag it to move, page menu, hide.
    static let barHeight = 40.0
    /// Kept clear of the screen's edges.
    static let margin = 8.0
    static let smallestWidth = 180.0

    static let defaultWidthFraction = 0.26
    static let defaultCentreX = 0.84
    static let defaultCentreY = 0.6

    struct Frame: Equatable {
        var centreX: Double
        var centreY: Double
        var width: Double
        var height: Double
        /// Each key's width and height.
        var side: Double
    }

    static func rows(keyCount: Int, columns: Int) -> Int {
        let columns = max(columns, 1)
        return max(1, (max(keyCount, 1) + columns - 1) / columns)
    }

    static func side(width: Double, columns: Int) -> Double {
        let columns = max(columns, 1)
        return max(0, (width - 2 * padding - Double(columns - 1) * spacing) / Double(columns))
    }

    static func height(width: Double, columns: Int, rows: Int) -> Double {
        barHeight + Double(rows) * side(width: width, columns: columns) + Double(rows - 1) * spacing + padding
    }

    /// From the smallest that's still usable to the biggest that fits on screen.
    static func widthRange(columns: Int, rows: Int, containerWidth: Double, containerHeight: Double) -> ClosedRange<Double> {
        let columns = max(columns, 1)
        let byWidth = containerWidth - 2 * margin
        let tallestKey = (containerHeight - 2 * margin - barHeight - padding - Double(rows - 1) * spacing) / Double(rows)
        let byHeight = Double(columns) * tallestKey + Double(columns - 1) * spacing + 2 * padding
        let upper = max(0, min(byWidth, byHeight))
        return min(smallestWidth, upper) ... upper
    }

    /// The deck's frame from its kept fractions, while being moved by `move`
    /// and resized by `resize` points of width (its top-left corner stays put
    /// while it's resized from the bottom-right).
    static func frame(keyCount: Int, columns: Int, containerWidth: Double, containerHeight: Double,
                      widthFraction: Double, centreX: Double, centreY: Double,
                      move: (x: Double, y: Double) = (0, 0), resize: Double = 0) -> Frame {
        let rows = rows(keyCount: keyCount, columns: columns)
        let range = widthRange(columns: columns, rows: rows, containerWidth: containerWidth, containerHeight: containerHeight)
        let kept = clamp(widthFraction * containerWidth, range)
        let width = clamp(kept + resize, range)
        let keptHeight = height(width: kept, columns: columns, rows: rows)
        let height = height(width: width, columns: columns, rows: rows)
        let x = centreX * containerWidth + move.x + (width - kept) / 2
        let y = centreY * containerHeight + move.y + (height - keptHeight) / 2
        // Never a ClosedRange here: with no room it would be upside down, and trap.
        return Frame(centreX: clamp(x, width / 2 + margin, containerWidth - width / 2 - margin),
                     centreY: clamp(y, height / 2 + margin, containerHeight - height / 2 - margin),
                     width: width, height: height, side: side(width: width, columns: columns))
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// With no room at all (high below low) it sits in the middle.
    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        high < low ? (low + high) / 2 : min(max(value, low), high)
    }
}
