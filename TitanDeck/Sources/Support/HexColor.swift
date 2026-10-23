// Support/HexColor.swift
import Foundation

/// "#RRGGBB" (or "RRGGBB") to 0-1 components. Kept UI-framework-free so the
/// profile model can be unit tested anywhere.
struct HexColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    init?(_ hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// "#RRGGBB", upper case - the form profiles store.
    var hexString: String {
        func byte(_ v: Double) -> Int { Int((v * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

#if canImport(UIKit)
import UIKit

extension HexColor {
    init(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b))
    }
}

extension UIColor {
    convenience init(hex: String, fallback: UIColor = .darkGray) {
        if let c = HexColor(hex) {
            self.init(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        } else {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            fallback.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.init(red: r, green: g, blue: b, alpha: a)
        }
    }
}
#endif
