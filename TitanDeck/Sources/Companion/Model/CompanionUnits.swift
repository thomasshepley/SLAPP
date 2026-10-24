// Companion/Model/CompanionUnits.swift
import Foundation

/// Metric or imperial at the UI edge. Everything is stored and calculated in
/// metres, lux and kilograms; only display and entry are converted.
enum UnitSystem: String, CaseIterable, Identifiable {
    case metric = "Metric"
    case imperial = "Imperial"
    var id: Self { self }
}

struct Measure {
    /// "m" or "ft", "lux" or "fc", "kg" or "lb".
    let unit: String
    /// Display units per canonical unit (1 when metric).
    let perCanonical: Double
    let places: Int

    func display(_ canonical: Double) -> Double { canonical * perCanonical }
    func canonical(_ display: Double) -> Double { display / perCanonical }

    /// Rounded, grouped, without the unit: "1,250" or "3.28".
    func format(_ canonical: Double, places: Int? = nil) -> String {
        let value = display(canonical)
        guard value.isFinite else { return "-" }
        return value.formatted(.number.precision(.fractionLength(0 ... (places ?? self.places))))
    }

    /// With the unit: "3.28 ft".
    func text(_ canonical: Double, places: Int? = nil) -> String {
        "\(format(canonical, places: places)) \(unit)"
    }
}

struct CompanionUnits {
    static let feetPerMetre = 3.280839895
    static let luxPerFootcandle = 10.763910417
    static let poundsPerKilogram = 2.204622622

    let system: UnitSystem

    var distance: Measure {
        system == .imperial ? Measure(unit: "ft", perCanonical: Self.feetPerMetre, places: 2)
            : Measure(unit: "m", perCanonical: 1, places: 2)
    }

    var illuminance: Measure {
        system == .imperial ? Measure(unit: "fc", perCanonical: 1 / Self.luxPerFootcandle, places: 0)
            : Measure(unit: "lux", perCanonical: 1, places: 0)
    }

    var mass: Measure {
        system == .imperial ? Measure(unit: "lb", perCanonical: Self.poundsPerKilogram, places: 1)
            : Measure(unit: "kg", perCanonical: 1, places: 1)
    }
}

/// Companion preferences, shared by the tools through @AppStorage.
enum CompanionSettings {
    static let unitsKey = "companion.units"
    static let mainsHzKey = "companion.mainsHz"
    static let voltageKey = "companion.voltage"
}
