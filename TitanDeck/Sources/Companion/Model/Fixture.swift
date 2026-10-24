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
    /// DMX footprint.
    var channelCount: Int
    var channels: [DmxChannel]
    var powerW: Double?

    var id: String { name }
}

struct DmxChannel: Codable, Hashable {
    /// 0-based offset from the fixture's start address.
    var offset: Int
    /// 8, 16 or 24 bit: 16-bit channels take two slots, 24-bit three.
    var resolution: Int
    var attribute: ChannelAttribute
    var label: String
    var ranges: [DmxRange]?

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
    var number: String
    var name: String
    var description: String?
    /// Positive warms (CTO), negative cools (CTB). Nil for non-CT gels.
    var miredShift: Double?
    var swatchRgb: SwatchRGB

    struct SwatchRGB: Codable, Hashable {
        var r: Int
        var g: Int
        var b: Int
    }
}
