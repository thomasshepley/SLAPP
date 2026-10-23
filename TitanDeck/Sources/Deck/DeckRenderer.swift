// Deck/DeckRenderer.swift
import UIKit

/// Draws key images with Core Graphics: coloured background, optional SF
/// Symbol, white label. Output is sized to the deck's native key size.
enum DeckRenderer {
    enum Overlay {
        case none
        /// Key held down / request in flight.
        case pressed
        /// Titan didn't answer or returned an error.
        case failure
    }

    /// `isActive` draws a live-playback highlight: a bright frame and a bar
    /// along the bottom, readable at a glance on set.
    static func image(for key: KeyDefinition?, size: CGSize, overlay: Overlay = .none, isActive: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rect = CGRect(origin: .zero, size: size)

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let background: UIColor
            switch (overlay, key) {
            case (.failure, _): background = .systemRed
            case (_, nil): background = .black
            case (_, let key?): background = UIColor(hex: key.colorHex)
            }
            background.setFill()
            context.fill(rect)

            guard let key else { return }

            var textRect = rect.insetBy(dx: size.width * 0.06, dy: size.height * 0.06)

            if let name = key.sfSymbol,
               let symbol = UIImage(systemName: name,
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: size.height * 0.26, weight: .semibold))?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: size.height * 0.1)
                symbol.draw(at: origin)
                let top = origin.y + symbol.size.height + size.height * 0.04
                textRect = CGRect(x: textRect.minX, y: top, width: textRect.width, height: max(textRect.maxY - top, 1))
            }

            drawLabel(key.label, in: textRect, maxFontSize: size.height * 0.24)

            if isActive {
                let line = max(size.width * 0.06, 3)
                UIColor.white.setStroke()
                let frame = UIBezierPath(rect: rect.insetBy(dx: line / 2, dy: line / 2))
                frame.lineWidth = line
                frame.stroke()
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: size.height - line * 2, width: size.width, height: line * 2))
            }

            if overlay == .pressed {
                UIColor.white.withAlphaComponent(0.35).setFill()
                context.fill(rect)
            }
        }
    }

    /// Centres the label, shrinking the font until it fits.
    private static func drawLabel(_ label: String, in rect: CGRect, maxFontSize: CGFloat) {
        guard !label.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        var fontSize = maxFontSize
        var attributes: [NSAttributedString.Key: Any] = [:]
        var bounds = CGRect.zero
        repeat {
            attributes = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
            bounds = (label as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                                      options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
            fontSize -= 1
        } while bounds.height > rect.height && fontSize > 8

        let drawRect = CGRect(x: rect.minX, y: rect.minY + (rect.height - bounds.height) / 2,
                              width: rect.width, height: bounds.height)
        (label as NSString).draw(with: drawRect, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
    }
}
