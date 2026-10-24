// Companion/Model/Fixture.swift
import Foundation

/// A fixture type in the library: specs, DMX modes and photometry. Matches the
/// lighting companion's JSON (Resources/Companion/fixtures.json, exported by
/// Tools/export_companion_data.ts), so its show bundles stay compatible.
struct Fixture: Codable, Hashable, Identifiable {
    let id: String
    var manufacturer: String
    var model: String
    var category: String?
    var weightKg: Double?
    var modes: [FixtureMode]
    /// Keyed by mode name, with "*" as the default for every mode.
    var photometry: [String: FixturePhotometry]
    var colour: FixtureColour?
    var beam: FixtureBeam?

    static let defaultPhotometryKey = "*"

    var name: String { "\(manufacturer) \(model)" }

    func photometry(for mode: String?) -> FixturePhotometry? {
        mode.flatMap { photometry[$0] } ?? photometry[Self.defaultPhotometryKey]
    }

    /// Beam angle in degrees, falling back to the narrow end of the zoom.
    var beamAngle: Double? { beam?.angleDeg ?? beam?.zoomRangeDeg?.minDeg }

    /// Power draw from the first mode that lists one.
    var powerW: Double? { modes.lazy.compactMap(\.powerW).first }

    /// Distinct footprints across the modes, smallest first ("1-16 ch").
    var footprintSummary: String {
        let counts = Set(modes.map(\.channelCount)).sorted()
        guard let low = counts.first, let high = counts.last else { return "-" }
        return low == high ? "\(low) ch" : "\(low)-\(high) ch"
    }

    /// Lower-cased text searched by the library's search field.
    var searchText: String {
        [manufacturer, model, category ?? ""].joined(separator: " ").lowercased()
    }
}

struct FixtureMode: Codable, Hashable, Identifiable {
    var name: String
    /// The manufacturer's mode number, where they number them (Astera's "89").
    var number: String?
    /// The manufacturer's short brief of what the mode covers ("Dim CCT GM RGB CRO").
    var summary: String?
    /// DMX footprint.
    var channelCount: Int
    var channels: [DmxChannel]
    var powerW: Double?
    /// Big pixel modes list one cell: `cellSize` slots from `cellStart` are
    /// cell 1, and the block repeats straight after to make `repeatCells`
    /// cells in all. Channels after the cells sit at their true offsets.
    var repeatCells: Int?
    var cellSize: Int?
    var cellStart: Int?

    var id: String { name }

    /// "Mode 89 · D CCT GM CRO RGB", or just the name for fixtures that
    /// don't number their modes.
    var title: String {
        guard let number, !number.isEmpty else { return name }
        return shortName.isEmpty ? numberTitle : "\(numberTitle) · \(shortName)"
    }

    /// "Mode 89", or the number as is when it's a code like Panalux's "P4".
    var numberTitle: String {
        guard let number else { return "" }
        return number.allSatisfy(\.isNumber) ? "Mode \(number)" : number
    }

    /// The name without "Mode 89" in front. Astera names repeat the number
    /// ("Mode 107 D CCT GM CRO RGB S (4 px, strobe per cell)"); ARRI's don't.
    var shortName: String {
        guard let number, !number.isEmpty else { return name }
        guard let prefix = ["Mode \(number)", number].first(where: { name.hasPrefix($0 + " ") || name == $0 }) else { return name }
        let rest = name.dropFirst(prefix.count).trimmingCharacters(in: CharacterSet(charactersIn: " -·:"))
        return rest.isEmpty ? (summary ?? "") : rest
    }

    /// The brief, when it says more than the name already does.
    var detail: String? {
        guard let summary, !summary.isEmpty, !shortName.contains(summary) else { return nil }
        return summary
    }

    /// Every channel, with repeated pixel cells written out.
    var allChannels: [DmxChannel] {
        guard let repeatCells, let cellSize, repeatCells > 1, cellSize > 0 else { return channels }
        let end = channels.map { $0.offset + $0.slotCount }.max() ?? 0
        let start = cellStart ?? end - cellSize
        guard start >= 0 else { return channels }
        let cell = channels.filter { $0.offset >= start && $0.offset < start + cellSize }
        var result = channels
        for index in 1 ..< repeatCells {
            result += cell.map { channel in
                var copy = channel
                copy.offset += index * cellSize
                copy.label = Self.label(channel.label, cell: index + 1)
                if channel.cell != nil { copy.cell = index + 1 }
                return copy
            }
        }
        return result.sorted { $0.offset < $1.offset }
    }

    /// Cell 1's label for another cell: "Cell 1 Red" becomes "Cell 7 Red",
    /// "LE1 Dimmer" "LE4 Dimmer"; anything else gets the cell in front.
    static func label(_ label: String, cell: Int) -> String {
        for prefix in ["Cell ", "Pixel ", "Zone ", "Engine ", "Segment ", "Section ", "Head ", "LE", "Px"] {
            let marker = prefix + "1"
            guard label.hasPrefix(marker) else { continue }
            let rest = label.dropFirst(marker.count)
            if rest.first?.isNumber == true { continue }
            return "\(prefix)\(cell)\(rest)"
        }
        return "Cell \(cell) \(label)"
    }
}

struct DmxChannel: Codable, Hashable {
    /// 0-based offset from the fixture's start address.
    var offset: Int
    /// 8, 16 or 24 bit: 16-bit channels take two slots, 24-bit three.
    var resolution: Int
    var attribute: ChannelAttribute
    var label: String
    var ranges: [DmxRange]?
    /// The pixel cell this channel drives (1-based, in DMX order), for pixel
    /// and zone modes. Tagged by Tools/tag_pixel_cells.py.
    var cell: Int?
    /// Which set of pixels, on fixtures with more than one ("Beam", "Aura").
    var cellGroup: String?

    var slotCount: Int { max(1, resolution / 8) }
}

struct DmxRange: Codable, Hashable {
    var from: Int
    var to: Int
    var label: String
}

/// What a channel controls. Unknown values from newer files decode as `.other`.
enum ChannelAttribute: String, Codable, CaseIterable {
    case intensity, red, green, blue, white, amber, lime, cyan, magenta, yellow
    case cct, tint, pan, tilt, zoom, focus, gobo, colourWheel, shutter, control, other

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ChannelAttribute(rawValue: raw) ?? .other
    }

    var title: String {
        switch self {
        case .cct: return "CCT"
        case .colourWheel: return "Colour wheel"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// Groups for colour-coding the DMX chart.
    enum Family: String {
        case intensity, colour, white, position, beam, control
    }

    var family: Family {
        switch self {
        case .intensity: return .intensity
        case .red, .green, .blue, .amber, .lime, .cyan, .magenta, .yellow, .colourWheel: return .colour
        case .white, .cct, .tint: return .white
        case .pan, .tilt: return .position
        case .zoom, .focus, .gobo, .shutter: return .beam
        case .control, .other: return .control
        }
    }
}

struct FixturePhotometry: Codable, Hashable {
    var luxAt1m: Double?
    var dimmingCurve: DimmingCurve
}

struct DimmingCurve: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case linear, square, scurve, log, measured
        var id: Self { self }

        var title: String {
            switch self {
            case .linear: return "Linear"
            case .square: return "Square law"
            case .scurve: return "S-curve"
            case .log: return "Log"
            case .measured: return "Measured"
            }
        }
    }

    var type: Kind
    var samples: [DimmingSample]?

    static let linear = DimmingCurve(type: .linear)
}

struct DimmingSample: Codable, Hashable {
    var dmxFraction: Double
    var outputFraction: Double
}

struct FixtureColour: Codable, Hashable {
    var cri: Double?
    var tlci: Double?
    var nativeCct: Double?
    var cctRange: CctRange?
    var hasColourMixing: Bool?
}

struct CctRange: Codable, Hashable {
    var minK: Double
    var maxK: Double
}

struct FixtureBeam: Codable, Hashable {
    var angleDeg: Double?
    var zoomRangeDeg: ZoomRange?
    var fieldAngleDeg: Double?
}

struct ZoomRange: Codable, Hashable {
    var minDeg: Double
    var maxDeg: Double
}

/// A colour gel swatch from the bundled starter set.
struct Gel: Codable, Hashable, Identifiable {
    let id: String
    var manufacturer: String
    /// "LEE", "E-Colour+", "Roscolux", "Cinegel", "GamColor".
    var range: String?
    var number: String
    var name: String
    var category: Category?
    var description: String?
    /// Light let through, percent (under tungsten for LEE).
    var transmission: Double?
    var transmissionDaylight: Double?
    /// Positive warms (CTO), negative cools (CTB). Nil for non-CT gels.
    var miredShift: Double?
    /// Approximate swatch colour, as the manufacturer shows it.
    var swatchRgb: SwatchRGB
    var source: String?

    struct SwatchRGB: Codable, Hashable {
        var r: Int
        var g: Int
        var b: Int
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case colour
        case cto
        case ctb
        case plusGreen
        case minusGreen
        case nd
        case diffusion
        case otherCorrection = "other correction"

        var id: Self { self }

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Category(rawValue: raw) ?? .otherCorrection
        }

        var title: String {
            switch self {
            case .colour: "Colours"
            case .cto: "CTO (warming)"
            case .ctb: "CTB (cooling)"
            case .plusGreen: "Plus Green"
            case .minusGreen: "Minus Green"
            case .nd: "ND"
            case .diffusion: "Diffusion"
            case .otherCorrection: "Other correction"
            }
        }
    }

    /// "LEE 201", "Rosco E-Colour+ E201".
    var displayNumber: String {
        if manufacturer == "Lee" { return "LEE \(number)" }
        return "\(range ?? manufacturer) \(number)"
    }

    /// Stops of light lost, from transmission.
    var stopLoss: Double? {
        guard let transmission, transmission > 0 else { return nil }
        return log2(100 / transmission)
    }

    var rgb: RGB { RGB(r: swatchRgb.r, g: swatchRgb.g, b: swatchRgb.b) }
}
