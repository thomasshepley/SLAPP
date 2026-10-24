// Companion/Calc/ColourMaths.swift
import Foundation

struct RGB: Equatable {
    var r: Int
    var g: Int
    var b: Int
}

/// Hue 0-360, saturation and intensity 0-1. The intuitive space for LED fixtures.
struct HSI: Equatable {
    var h: Double
    var s: Double
    var i: Double
}

/// Colour temperature maths. Gel shifts are linear in mired (1,000,000 / K),
/// not kelvin, so everything works in mired.
enum ColourMaths {
    static func mired(kelvin: Double) -> Double { 1_000_000 / kelvin }
    static func kelvin(mired: Double) -> Double { 1_000_000 / mired }

    /// Mired shift from a source to a target CCT. Positive warms (CTO).
    static func correctionShift(from source: Double, to target: Double) -> Double {
        mired(kelvin: target) - mired(kelvin: source)
    }

    static func apply(shift: Double, to source: Double) -> Double {
        kelvin(mired: mired(kelvin: source) + shift)
    }

    // MARK: RGB / HSI

    static func hsi(from rgb: RGB) -> HSI {
        let r = Double(rgb.r) / 255, g = Double(rgb.g) / 255, b = Double(rgb.b) / 255
        let i = (r + g + b) / 3
        let s = i == 0 ? 0 : 1 - min(r, g, b) / i
        var h = 0.0
        let denominator = ((r - g) * (r - g) + (r - b) * (g - b)).squareRoot()
        if denominator != 0 {
            let cosine = ((r - g) + (r - b)) / (2 * denominator)
            h = acos(min(1, max(-1, cosine))) * 180 / .pi
            if b > g { h = 360 - h }
        }
        return HSI(h: round(h, places: 1), s: round(s, places: 3), i: round(i, places: 3))
    }

    static func rgb(from hsi: HSI) -> RGB {
        let hr = hsi.h.truncatingRemainder(dividingBy: 360) * .pi / 180
        let third = 2 * Double.pi / 3
        let s = hsi.s, i = hsi.i
        func lifted(_ angle: Double) -> Double { i * (1 + s * cos(angle) / cos(third / 2 - angle)) }
        var r: Double, g: Double, b: Double
        if hr < third {
            b = i * (1 - s); r = lifted(hr); g = 3 * i - (r + b)
        } else if hr < 2 * third {
            r = i * (1 - s); g = lifted(hr - third); b = 3 * i - (r + g)
        } else {
            g = i * (1 - s); b = lifted(hr - 2 * third); r = 3 * i - (g + b)
        }
        func to255(_ v: Double) -> Int { Int((clamp01(v) * 255).rounded()) }
        return RGB(r: to255(r), g: to255(g), b: to255(b))
    }

    // MARK: Tunable white

    /// Fader % -> CCT for a tunable-white fixture, interpolated in mired.
    static func cct(percent: Double, minK: Double, maxK: Double) -> Double {
        let p = clamp01(percent / 100)
        return kelvin(mired: mired(kelvin: minK) + p * (mired(kelvin: maxK) - mired(kelvin: minK))).rounded()
    }

    static func percent(cct: Double, minK: Double, maxK: Double) -> Double {
        let p = (mired(kelvin: cct) - mired(kelvin: minK)) / (mired(kelvin: maxK) - mired(kelvin: minK))
        return round(clamp01(p) * 100, places: 1)
    }

    // MARK: Tint

    enum TintDirection: String {
        case green = "Green"
        case magenta = "Magenta"
        case neutral = "Neutral"
    }

    struct TintReading: Equatable {
        let direction: TintDirection
        let magnitude: Double
        /// Rough CC eighths, the way a DoP would call it (~0.0007 Duv each).
        let ccEighths: Int
    }

    static func tint(duv: Double, neutralBand: Double = 0.0003) -> TintReading {
        let direction: TintDirection = abs(duv) <= neutralBand ? .neutral : (duv > 0 ? .green : .magenta)
        return TintReading(direction: direction, magnitude: abs(round(duv, places: 5)),
                           ccEighths: Int((abs(duv) / 0.0007).rounded()))
    }

    /// What to do about a green or magenta tint: the gel that cancels it.
    struct TintCorrection: Equatable {
        /// How the light looks: green, magenta or neutral.
        let looks: TintDirection
        /// "1/8", "1/4", "1/2", "Full" - nil when neutral.
        let strength: String?
        /// "Minus Green" for a green light, "Plus Green" for a magenta one.
        let gelName: String?
        /// The LEE number for that strength, e.g. "249".
        let leeNumber: String?
        /// More than a full gel's worth.
        let beyondFull: Bool
    }

    /// LEE's green/magenta correction gels: (eighths, strength, minus green, plus green).
    private static let tintGels: [(eighths: Int, strength: String, minus: String, plus: String)] = [
        (1, "1/8", "279", "278"),
        (2, "1/4", "249", "246"),
        (4, "1/2", "248", "245"),
        (8, "Full", "247", "244"),
    ]

    /// The nearest standard gel to cancel a Duv reading (positive Duv = green).
    static func tintCorrection(duv: Double) -> TintCorrection {
        let reading = tint(duv: duv)
        guard reading.direction != .neutral, reading.ccEighths > 0 else {
            return TintCorrection(looks: .neutral, strength: nil, gelName: nil, leeNumber: nil, beyondFull: false)
        }
        let gel = tintGels.min { abs($0.eighths - reading.ccEighths) < abs($1.eighths - reading.ccEighths) }!
        let green = reading.direction == .green
        return TintCorrection(looks: reading.direction, strength: gel.strength,
                              gelName: green ? "Minus Green" : "Plus Green",
                              leeNumber: green ? gel.minus : gel.plus,
                              beyondFull: reading.ccEighths > 10)
    }

    // MARK: Hex

    /// "#1AB39E".
    static func hex(_ rgb: RGB) -> String {
        func two(_ v: Int) -> String {
            let digits = String(min(255, max(0, v)), radix: 16, uppercase: true)
            return digits.count == 1 ? "0" + digits : digits
        }
        return "#" + two(rgb.r) + two(rgb.g) + two(rgb.b)
    }

    /// Reads "#1AB39E", "1ab39e" or "#1AB" (short form).
    static func rgb(hex text: String) -> RGB? {
        var digits = text.trimmingCharacters(in: .whitespaces).uppercased()
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        return RGB(r: (value >> 16) & 0xFF, g: (value >> 8) & 0xFF, b: value & 0xFF)
    }

    /// True when an HSI colour can't be made at that intensity without
    /// clipping a channel (so the RGB shown is the nearest it gets).
    static func isClipped(_ hsi: HSI) -> Bool {
        guard hsi.i > 0.05 else { return false }   // too dark for 8-bit RGB to judge
        let back = self.hsi(from: rgb(from: hsi))
        let hueGap = abs(back.h - hsi.h).truncatingRemainder(dividingBy: 360)
        return abs(back.i - hsi.i) > 0.02 || abs(back.s - hsi.s) > 0.03
            || (hsi.s > 0.05 && min(hueGap, 360 - hueGap) > 3)
    }

    // MARK: CT gel suggestion

    enum GelFamily: String {
        case cto = "CTO"
        case ctb = "CTB"
        case none = "None"
    }

    struct GelSuggestion: Equatable {
        let family: GelFamily
        /// "Full", "1/2", "1/4", "1/8", or "-" when none is needed.
        let strength: String
        let gelShift: Double
        /// Mired left over after the suggested gel.
        let residual: Double
    }

    private static let ctoSteps: [(String, Double)] = [("1/8", 53), ("1/4", 81), ("1/2", 137), ("Full", 167)]
    private static let ctbSteps: [(String, Double)] = [("1/8", -49), ("1/4", -78), ("1/2", -110), ("Full", -131)]

    /// The closest single standard CT gel from source to target CCT.
    static func suggestGel(from source: Double, to target: Double) -> GelSuggestion {
        let needed = correctionShift(from: source, to: target)
        if abs(needed) < 15 {
            return GelSuggestion(family: .none, strength: "-", gelShift: 0, residual: needed.rounded())
        }
        let steps = needed > 0 ? ctoSteps : ctbSteps
        let best = steps.min { abs($0.1 - needed) < abs($1.1 - needed) } ?? steps[0]
        return GelSuggestion(family: needed > 0 ? .cto : .ctb, strength: best.0, gelShift: best.1,
                             residual: (needed - best.1).rounded())
    }
}
