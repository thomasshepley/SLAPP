// Companion/Calc/Photometry.swift
import Foundation

/// Beam and throw geometry plus the inverse square law. Everything is metric
/// in and out (metres, lux, degrees); `CompanionUnits` converts at the UI edge.
enum Photometry {
    /// Illuminance at a distance from a 1 m reference reading.
    static func lux(atDistance metres: Double, luxAt1m: Double) -> Double {
        metres <= 0 ? .infinity : luxAt1m / (metres * metres)
    }

    /// Distance at which a 1 m reference reading falls to `targetLux`.
    static func distance(forLux targetLux: Double, luxAt1m: Double) -> Double {
        targetLux <= 0 ? .infinity : (luxAt1m / targetLux).squareRoot()
    }

    /// Beam diameter at a throw distance, for a full beam angle in degrees.
    static func beamDiameter(angle degrees: Double, distance metres: Double) -> Double {
        2 * metres * tan(degrees / 2 * .pi / 180)
    }

    /// Throw distance needed to cover a diameter at a full beam angle.
    static func throwDistance(angle degrees: Double, diameter metres: Double) -> Double {
        let t = tan(degrees / 2 * .pi / 180)
        return t == 0 ? .infinity : metres / (2 * t)
    }
}

/// Dimming curves: DMX level (fraction of full) -> relative light output. The
/// stops calculator depends on this, because square-law, S-curve and log
/// fixtures give very different output at the same DMX.
enum Dimming {
    static func output(atDmx fraction: Double, curve: DimmingCurve) -> Double {
        let x = clamp01(fraction)
        switch curve.type {
        case .linear: return x
        case .square: return x * x
        case .log: return x == 0 ? 0 : pow(x, 2.2)
        case .scurve: return x * x * (3 - 2 * x)
        case .measured: return interpolate(curve.samples ?? [], x, from: \.dmxFraction, to: \.outputFraction)
        }
    }

    /// The DMX fraction that gives an output fraction (the curve's inverse).
    static func dmx(forOutput fraction: Double, curve: DimmingCurve) -> Double {
        let y = clamp01(fraction)
        switch curve.type {
        case .linear: return y
        case .square: return y.squareRoot()
        case .log: return y == 0 ? 0 : pow(y, 1 / 2.2)
        case .scurve: return invertSmoothstep(y)
        case .measured: return interpolate(curve.samples ?? [], y, from: \.outputFraction, to: \.dmxFraction)
        }
    }

    /// Piecewise-linear lookup, clamped to the end points. No samples = linear.
    private static func interpolate(_ samples: [DimmingSample], _ x: Double,
                                    from xKey: KeyPath<DimmingSample, Double>,
                                    to yKey: KeyPath<DimmingSample, Double>) -> Double {
        guard !samples.isEmpty else { return x }
        let sorted = samples.sorted { $0[keyPath: xKey] < $1[keyPath: xKey] }
        let xs = sorted.map { $0[keyPath: xKey] }
        let ys = sorted.map { $0[keyPath: yKey] }
        if x <= xs[0] { return ys[0] }
        if x >= xs[xs.count - 1] { return ys[ys.count - 1] }
        for i in 0 ..< xs.count - 1 where x >= xs[i] && x <= xs[i + 1] {
            let t = xs[i + 1] == xs[i] ? 0 : (x - xs[i]) / (xs[i + 1] - xs[i])
            return ys[i] + t * (ys[i + 1] - ys[i])
        }
        return ys[ys.count - 1]
    }

    private static func invertSmoothstep(_ y: Double) -> Double {
        var lo = 0.0, hi = 1.0
        for _ in 0 ..< 40 {
            let mid = (lo + hi) / 2
            if mid * mid * (3 - 2 * mid) < y { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }
}

/// A photographic stop doubles or halves the light. Given a fixture's DMX
/// level and dimming curve, works out the DMX for each stop up or down.
enum Stops {
    struct Row: Equatable, Identifiable {
        let stops: Int
        /// Target output relative to full; above 1 means the fixture can't get there.
        let outputFraction: Double
        let dmx: Int
        let percent: Double
        let clipped: Bool
        var id: Int { stops }
    }

    struct Result: Equatable {
        let currentDmx: Int
        let currentPercent: Double
        /// Estimated output at 1 m, when the fixture has a lux figure.
        let currentLux: Double?
        let rows: [Row]
    }

    static func compute(dmx currentDmx: Int, curve: DimmingCurve, luxAt1m: Double?,
                        offsets: [Int] = [-2, -1, 1, 2]) -> Result {
        let currentFraction = clamp01(Double(currentDmx) / 255)
        let currentOutput = Dimming.output(atDmx: currentFraction, curve: curve)
        let rows = offsets.map { stops -> Row in
            let target = currentOutput * pow(2, Double(stops))
            let dmx = Int((Dimming.dmx(forOutput: clamp01(target), curve: curve) * 255).rounded())
            return Row(stops: stops, outputFraction: target, dmx: dmx,
                       percent: round(Double(dmx) / 255 * 100, places: 1),
                       clipped: target > 1 || target < 0)
        }
        return Result(currentDmx: currentDmx,
                      currentPercent: round(currentFraction * 100, places: 1),
                      currentLux: luxAt1m.map { $0 * currentOutput },
                      rows: rows)
    }
}

func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }

/// Rounds half away from zero, like JavaScript's Math.round for positives.
func round(_ value: Double, places: Int) -> Double {
    let factor = pow(10, Double(places))
    return (value * factor).rounded() / factor
}
