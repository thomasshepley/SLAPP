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
    /// Other ways some modes can group the pixels, picked on the fixture
    /// itself (the Vortex's Zone Orientation channel). Tied to mode numbers.
    var variants: [Variant]?
    /// What the choice is called ("Zone Orientation") and what `groups` is
    /// when a variant is on offer ("Vertical stripes").
    var variantTitle: String?
    var defaultLabel: String?

    struct Variant: Codable, Hashable {
        var label: String
        /// Mode numbers (or names) it applies to.
        var modes: [String]
        var groups: [String: [String: [[Int]]]]
        /// The fixture's default, so the plain `groups` don't apply to these modes.
        var isDefault: Bool?
        var note: String?
    }

    /// One way to group the pixels for a mode.
    struct Option: Hashable {
        var label: String
        var note: String?
        var groups: [String: [String: [[Int]]]]
    }

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

    /// The groupings on offer for a mode: just the standard one, or the
    /// fixture's choices (default first) when a variant names this mode.
    func options(for mode: FixtureMode) -> [Option] {
        let main = Option(label: defaultLabel ?? "Standard", groups: groups)
        let key = mode.number ?? mode.name
        let matching = (variants ?? []).filter { $0.modes.contains(key) }
        guard !matching.isEmpty else { return [main] }
        let choices = matching
            .sorted { ($0.isDefault == true ? 0 : 1) < ($1.isDefault == true ? 0 : 1) }
            .map { Option(label: $0.label, note: $0.note, groups: $0.groups) }
        return matching.contains { $0.isDefault == true } ? choices : [main] + choices
    }

    /// The cells of a mode this layout can draw, per group in the order the
    /// groups first appear in the mode. Empty when it has no matching grouping.
    /// `option` picks one of `options(for:)`.
    func cells(for mode: FixtureMode, option: Int = 0) -> [Cell] {
        let choices = options(for: mode)
        let groups = choices[min(max(option, 0), choices.count - 1)].groups
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

    /// Problems with the data: a grouping with the wrong number of cells, a
    /// pixel in two cells, or one that isn't drawn. Empty when the layout is
    /// sound. An empty cell is fine: it lights nothing on this one fixture
    /// (SkyPanel X zones 9-24 live on the next panel of an array).
    func problems() -> [String] {
        let known = Set(pixels.map(\.id))
        var found: [String] = []
        if known.count != pixels.count { found.append("pixel ids repeat") }
        let all = [groups] + (variants ?? []).map(\.groups)
        for (group, counts) in all.flatMap({ $0 }) {
            for (count, grouping) in counts {
                let ids = grouping.flatMap { $0 }
                let label = "\(group.isEmpty ? "" : group + " ")\(count) cells"
                if grouping.count != Int(count) { found.append("\(label): \(grouping.count) lists") }
                if Set(ids).count != ids.count { found.append("\(label): a pixel is in two cells") }
                if !Set(ids).isSubset(of: known) { found.append("\(label): unknown pixel") }
            }
        }
        return found
    }
}
