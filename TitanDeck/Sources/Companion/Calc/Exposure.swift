// Companion/Calc/Exposure.swift
import Foundation

/// Camera helpers, referenced at ISO 100 (EV100) - the usual convention when
/// going from an incident lux reading to a stills or cine exposure.
enum Exposure {
    /// Incident lux -> EV at ISO 100: EV = log2(E x S / C), S = 100, C = 250.
    /// 2500 lux is about EV 10, like a real incident meter.
    static func ev100(lux: Double) -> Double {
        lux <= 0 ? -.infinity : log2(lux * 100 / 250)
    }

    /// Optical density -> stops (0.3 density is one stop).
    static func stops(ndDensity density: Double) -> Double { density / log10(2) }
    static func ndDensity(stops: Double) -> Double { stops * log10(2) }

    /// A stack of ND filters: densities add, so stops add.
    static func stack(densities: [Double]) -> (density: Double, stops: Double) {
        let total = densities.reduce(0, +)
        return (round(total, places: 2), round(stops(ndDensity: total), places: 2))
    }

    struct FlickerCheck: Equatable {
        let safe: Bool
        /// Light pulses per second: twice the mains frequency.
        let flickerHz: Int
        /// Safe shutter speeds (1/x s) either side of the one checked.
        let nearestSafe: [Int]
    }

    /// A shutter is safe with mains-flickering lamps when it spans a whole
    /// number of half-cycles: 1/x with x a multiple of 2 x mains Hz.
    static func checkFlicker(shutter: Double, mainsHz: Int) -> FlickerCheck {
        let flickerHz = mainsHz * 2
        let ratio = shutter / Double(flickerHz)
        let safe = abs(ratio - ratio.rounded()) < 1e-6 && shutter >= Double(flickerHz)
        let lower = max(1, Int(ratio.rounded(.down))) * flickerHz
        let upper = Int((ratio + 1e-9).rounded(.up)) * flickerHz
        return FlickerCheck(safe: safe, flickerHz: flickerHz,
                            nearestSafe: lower == upper ? [lower] : [lower, upper])
    }

    static let fStops: [Double] = [1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11, 16, 22, 32]

    /// Aperture for a lux reading, ISO and shutter (1/x s): N = sqrt(2^EV x t)
    /// with EV = EV100 + log2(ISO / 100). Exact value and nearest full stop.
    static func aperture(lux: Double, iso: Double, shutter: Double) -> (exact: Double, nearestStop: Double) {
        let ev = ev100(lux: lux) + log2(iso / 100)
        let exact = max(0, pow(2, ev) / shutter).squareRoot()
        return (round(exact, places: 2), nearestFStop(exact))
    }

    static func nearestFStop(_ n: Double) -> Double {
        fStops.min { abs(log2($0) - log2(n)) < abs(log2($1) - log2(n)) } ?? fStops[0]
    }
}
