// Companion/Model/GelSearch.swift
import Foundation

/// Searching the gel library, and finding gels that look alike.
extension FixtureLibrary {
    /// "LEE", "E-Colour+", "Roscolux", "Cinegel", "GamColor", in library order.
    var gelRanges: [String] {
        var seen: [String] = []
        for gel in gels {
            let range = gel.range ?? gel.manufacturer
            if !seen.contains(range) { seen.append(range) }
        }
        return seen
    }

    /// Every word must match the number, name, range or maker ("lee 201",
    /// "half cto", "e106").
    func gels(matching text: String, range: String? = nil, category: Gel.Category? = nil) -> [Gel] {
        let words = text.lowercased().split(separator: " ").map(String.init)
        return gels.filter { gel in
            if let range, (gel.range ?? gel.manufacturer) != range { return false }
            if let category, gel.category != category { return false }
            guard !words.isEmpty else { return true }
            let haystack = "\(gel.manufacturer) \(gel.range ?? "") \(gel.number) \(gel.name) \(gel.displayNumber)".lowercased()
            let compact = haystack.replacingOccurrences(of: " ", with: "")
            return words.allSatisfy { haystack.contains($0) || compact.contains($0) }
        }
    }

    /// Colour gels closest to a colour, nearest first. With `otherThan`, only
    /// from other ranges - "what's the Rosco for this LEE?".
    func nearestGels(to rgb: RGB, count: Int = 4, excluding id: String? = nil, otherThan range: String? = nil) -> [Gel] {
        let target = ColourDistance.lab(rgb)
        return gels
            .filter { $0.id != id && ($0.category == .colour || $0.category == nil) }
            .filter { range == nil || ($0.range ?? $0.manufacturer) != range }
            .map { ($0, ColourDistance.deltaE(target, ColourDistance.lab($0.rgb))) }
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map(\.0)
    }
}

/// Perceptual colour difference (CIE76 on CIELAB, D65). Good enough to say
/// two swatches look alike.
enum ColourDistance {
    struct Lab: Equatable {
        let l: Double
        let a: Double
        let b: Double
    }

    static func lab(_ rgb: RGB) -> Lab {
        func linear(_ channel: Int) -> Double {
            let c = Double(min(255, max(0, channel))) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linear(rgb.r), g = linear(rgb.g), b = linear(rgb.b)
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return Lab(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    static func deltaE(_ p: Lab, _ q: Lab) -> Double {
        ((p.l - q.l) * (p.l - q.l) + (p.a - q.a) * (p.a - q.a) + (p.b - q.b) * (p.b - q.b)).squareRoot()
    }
}
