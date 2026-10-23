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
}

#if canImport(UIKit)
import UIKit

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
