// Companion/Model/PixelLayout.swift
import Foundation

/// Where a fixture's pixels physically sit, and how a pixel mode's cells
/// group them. From the manufacturer's manual (Resources/Companion/
/// pixel-layouts.json, keyed by fixture id), drawn over the fixture's face so
/// you can see which cell lights which part of the light.
struct PixelLayout: Codable, Hashable {
    var source: String?
    var page: String?
    var face: Face
    /// How the drawing is oriented ("Front view, power end on the left").
    var orientation: String?
    var pixels: [Pixel]
    /// Cell group ("" when there's only one) -> cell count -> one list of
    /// pixel ids per cell, in DMX order.
    var groups: [String: [String: [[Int]]]]
    /// The manual doesn't say where cell 1 is, so the order is a best guess.
    var cell1Assumed: Bool?
    var notes: String?

    struct Face: Codable, Hashable {
        var shape: Shape
        /// Width / height of the light-emitting face.
        var aspect: Double
    }

    enum Shape: String, Codable, Hashable {
        case rect, roundedRect, capsule, circle, hexagon, ring

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Shape(rawValue: raw) ?? .rect
        }
    }

    /// One physical pixel. Coordinates are 0...1 across the face, origin top
    /// left. Rects use x, y, w, h; circles and hexagons a centre (x, y) and
    /// radius r; rings a centre, mid radius r and width w. Radii and ring
    /// widths are fractions of the face width.
    struct Pixel: Codable, Hashable, Identifiable {
        var id: Int
        var shape: Shape
        var x: Double
        var y: Double
        var w: Double?
        var h: Double?
        var r: Double?

        /// Centre in face coordinates (0...1 each way).
        var centre: (x: Double, y: Double) {
            switch shape {
            case .rect, .roundedRect, .capsule:
                return (x + (w ?? 0) / 2, y + (h ?? 0) / 2)
            case .circle, .hexagon, .ring:
                return (x, y)
            }
        }
    }

    /// One cell of a pixel mode: its number, the pixels it lights and the
    /// channels that drive it.
    struct Cell: Hashable, Identifiable {
        var group: String
        var number: Int
        var pixelIDs: [Int]
        var channels: [DmxChannel]

        var id: String { "\(group)#\(number)" }

        /// "Cell 3" or "Aura 12".
        var title: String { group.isEmpty ? "Cell \(number)" : "\(group) \(number)" }

        /// DMX channels (1-based) the cell uses, as a short range: "9-12" or "9, 11, 13".
        var channelText: String {
            let slots = channels.flatMap { channel in (channel.offset ..< channel.offset + channel.slotCount).map { $0 + 1 } }.sorted()
            guard let first = slots.first, let last = slots.last else { return "-" }
            if slots.count == last - first + 1 { return first == last ? "\(first)" : "\(first)-\(last)" }
            return slots.map(String.init).joined(separator: ", ")
        }
    }

    /// The cells of a mode this layout can draw, per group in the order the
    /// groups first appear in the mode. Empty when it has no matching grouping.
    func cells(for mode: FixtureMode) -> [Cell] {
        var order: [String] = []
        var channelsByCell: [String: [Int: [DmxChannel]]] = [:]
        for channel in mode.allChannels {
            guard let cell = channel.cell else { continue }
            let group = channel.cellGroup ?? ""
            if channelsByCell[group] == nil { order.append(group) }
            channelsByCell[group, default: [:]][cell, default: []].append(channel)
        }
        var result: [Cell] = []
        for group in order {
            guard let byCell = channelsByCell[group], let count = byCell.keys.max(),
                  let grouping = groups[group]?[String(count)], grouping.count == count else { continue }
            for (index, pixelIDs) in grouping.enumerated() {
                result.append(Cell(group: group, number: index + 1, pixelIDs: pixelIDs,
                                   channels: byCell[index + 1] ?? []))
            }
        }
        return result
    }

    /// Problems with the data: a grouping that misses or repeats a pixel, or
    /// names one that isn't drawn. Empty when the layout is sound.
    func problems() -> [String] {
        let known = Set(pixels.map(\.id))
        var found: [String] = []
        if known.count != pixels.count { found.append("pixel ids repeat") }
        for (group, counts) in groups {
            for (count, grouping) in counts {
                let ids = grouping.flatMap { $0 }
                let label = "\(group.isEmpty ? "" : group + " ")\(count) cells"
                if grouping.count != Int(count) { found.append("\(label): \(grouping.count) lists") }
                if Set(ids).count != ids.count { found.append("\(label): a pixel is in two cells") }
                if !Set(ids).isSubset(of: known) { found.append("\(label): unknown pixel") }
                if grouping.contains(where: \.isEmpty) { found.append("\(label): an empty cell") }
            }
        }
        return found
    }
}
