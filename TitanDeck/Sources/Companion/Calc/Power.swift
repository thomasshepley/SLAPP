// Companion/Calc/Power.swift
import Foundation

/// Single-phase power budget: watts summed across fixtures, amps from P = V x I
/// at the supply voltage, checked against the distro's rating.
enum PowerBudget {
    struct Item: Equatable, Identifiable {
        var id = UUID()
        var name: String
        var watts: Double
        var quantity: Int
    }

    struct Result: Equatable {
        let totalWatts: Double
        let totalAmps: Double
        let overDistro: Bool
        let excessAmps: Double?
    }

    static func compute(items: [Item], voltage: Double, distroRatingAmps: Double?) -> Result {
        let watts = items.reduce(0) { $0 + $1.watts * Double($1.quantity) }
        let amps = voltage > 0 ? watts / voltage : 0
        let over = distroRatingAmps.map { amps > $0 } ?? false
        return Result(totalWatts: round(watts, places: 1),
                      totalAmps: round(amps, places: 2),
                      overDistro: over,
                      excessAmps: over ? distroRatingAmps.map { round(amps - $0, places: 2) } : nil)
    }
}

/// Indicative capacity of flexible cable (BS 7919 / typical manufacturer
/// figures) at 30 C, single circuit, free air, derated for ambient temperature
/// (BS 7671 Table 4B1). A guide for on-set sizing, not an installation design.
enum Cable {
    struct Rating: Equatable, Identifiable {
        let csaMm2: Double
        let baseAmps: Double
        var id: Double { csaMm2 }
    }

    static let ratings: [Rating] = [
        Rating(csaMm2: 1.0, baseAmps: 14),
        Rating(csaMm2: 1.5, baseAmps: 18),
        Rating(csaMm2: 2.5, baseAmps: 25),
        Rating(csaMm2: 4.0, baseAmps: 34),
        Rating(csaMm2: 6.0, baseAmps: 43),
        Rating(csaMm2: 10.0, baseAmps: 60),
        Rating(csaMm2: 16.0, baseAmps: 80),
        Rating(csaMm2: 25.0, baseAmps: 101),
    ]

    private static let temperatureFactors: [(celsius: Double, factor: Double)] = [
        (25, 1.03), (30, 1.0), (35, 0.94), (40, 0.87), (45, 0.79), (50, 0.71), (55, 0.61), (60, 0.5),
    ]

    static func derateFactor(ambient celsius: Double) -> Double {
        let points = temperatureFactors
        if celsius <= points[0].celsius { return points[0].factor }
        if celsius >= points[points.count - 1].celsius { return points[points.count - 1].factor }
        for i in 0 ..< points.count - 1 where celsius >= points[i].celsius && celsius <= points[i + 1].celsius {
            let t = (celsius - points[i].celsius) / (points[i + 1].celsius - points[i].celsius)
            return round(points[i].factor + t * (points[i + 1].factor - points[i].factor), places: 2)
        }
        return 1
    }

    static func deratedCapacity(csaMm2: Double, ambient celsius: Double) -> Double {
        guard let rating = ratings.first(where: { $0.csaMm2 == csaMm2 }) else { return 0 }
        return round(rating.baseAmps * derateFactor(ambient: celsius), places: 1)
    }

    /// Smallest size that carries `amps` at the ambient temperature.
    static func recommend(amps: Double, ambient celsius: Double) -> Rating? {
        ratings.first { deratedCapacity(csaMm2: $0.csaMm2, ambient: celsius) >= amps }
    }
}
