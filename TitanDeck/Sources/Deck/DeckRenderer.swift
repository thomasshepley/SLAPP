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
    /// `quarterTurns` rotates the finished image (positive = clockwise) for a
    /// deck mounted in portrait.
    static func image(for key: KeyDefinition?, size: CGSize, overlay: Overlay = .none, isActive: Bool = false,
                      isLatched: Bool = false, quarterTurns: Int) -> UIImage {
        let upright = image(for: key, size: size, overlay: overlay, isActive: isActive, isLatched: isLatched)
        guard quarterTurns % 4 != 0 else { return upright }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: CGFloat(quarterTurns) * .pi / 2)
            upright.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    /// `isLatched` means a latching key has been pressed on. Keys with a
    /// pressed look draw it while held, latched or live (per its mode);
    /// keys without one get the usual white flash while held.
    static func image(for key: KeyDefinition?, size: CGSize, overlay: Overlay = .none, isActive: Bool = false,
                      isLatched: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rect = CGRect(origin: .zero, size: size)
        let pressedLook = key?.showsPressedLook(held: overlay == .pressed, latched: isLatched, live: isActive) ?? false
        let key = key?.appearance(pressed: pressedLook)
        let flash = overlay == .pressed && key?.pressedStyle == nil

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
            let ink: UIColor = DeckFlow.wantsDarkText(on: key.colorHex) && overlay != .failure ? .black : .white

            var textRect = rect.insetBy(dx: size.width * 0.06, dy: size.height * 0.06)
            let hasLabel = !key.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if let emoji = key.emoji, !emoji.isEmpty {
                // On its own the emoji fills the key; with a label it sits on top.
                let bottom = drawEmoji(emoji, in: rect, alone: !hasLabel)
                textRect = CGRect(x: textRect.minX, y: bottom, width: textRect.width, height: max(textRect.maxY - bottom, 1))
            } else if let name = key.sfSymbol,
                      let symbol = UIImage(systemName: name,
                                           withConfiguration: UIImage.SymbolConfiguration(
                                               pointSize: size.height * (hasLabel ? 0.26 : 0.42), weight: .semibold))?
                .withTintColor(ink, renderingMode: .alwaysOriginal) {
                let top = hasLabel ? size.height * 0.1 : (size.height - symbol.size.height) / 2
                let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: top)
                symbol.draw(at: origin)
                let below = origin.y + symbol.size.height + size.height * 0.04
                textRect = CGRect(x: textRect.minX, y: below, width: textRect.width, height: max(textRect.maxY - below, 1))
            }

            let hasIcon = key.emoji != nil || key.sfSymbol != nil
            drawLabel(key.label, in: textRect, maxFontSize: size.height * DeckFlow.labelScale(key.label, hasIcon: hasIcon),
                      big: !hasIcon && DeckFlow.longestLine(key.label) <= 4, ink: ink)

            if isActive {
                let line = max(size.width * 0.06, 3)
                UIColor.white.setStroke()
                let frame = UIBezierPath(rect: rect.insetBy(dx: line / 2, dy: line / 2))
                frame.lineWidth = line
                frame.stroke()
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: size.height - line * 2, width: size.width, height: line * 2))
            }

            if flash {
                UIColor.white.withAlphaComponent(0.35).setFill()
                context.fill(rect)
            }
        }
    }

    /// Draws an emoji centred across the key, big when it's alone. Returns
    /// the y where a label can start below it.
    private static func drawEmoji(_ emoji: String, in rect: CGRect, alone: Bool) -> CGFloat {
        let fontSize = rect.height * (alone ? 0.56 : 0.34)
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fontSize)]
        let text = emoji as NSString
        let bounds = text.size(withAttributes: attributes)
        let top = alone ? (rect.height - bounds.height) / 2 : rect.height * 0.06
        text.draw(at: CGPoint(x: (rect.width - bounds.width) / 2, y: top), withAttributes: attributes)
        return top + bounds.height + rect.height * 0.01
    }

    /// Centres the label, shrinking the font until it fits: no taller than the
    /// key and every word on one line, so "CLEAR" never breaks into "CLEA / R".
    /// `big` labels use heavy rounded type, like the numbers on a console keypad.
    private static func drawLabel(_ label: String, in rect: CGRect, maxFontSize: CGFloat, big: Bool = false,
                                  ink: UIColor = .white) {
        guard !label.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let words = label.split(whereSeparator: \.isWhitespace).map { String($0) as NSString }
        var fontSize = maxFontSize
        var attributes: [NSAttributedString.Key: Any] = [:]
        var bounds = CGRect.zero
        var widestWord: CGFloat = 0
        repeat {
            attributes = [
                .font: big ? roundedFont(size: fontSize) : UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: ink,
                .paragraphStyle: paragraph,
            ]
            bounds = (label as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                                      options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
            widestWord = words.map { $0.size(withAttributes: attributes).width }.max() ?? 0
            fontSize -= 1
        } while (bounds.height > rect.height || widestWord > rect.width) && fontSize > 8

        let drawRect = CGRect(x: rect.minX, y: rect.minY + (rect.height - bounds.height) / 2,
                              width: rect.width, height: bounds.height)
        (label as NSString).draw(with: drawRect, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
    }

    private static func roundedFont(size: CGFloat) -> UIFont {
        let heavy = UIFont.systemFont(ofSize: size, weight: .heavy)
        guard let rounded = heavy.fontDescriptor.withDesign(.rounded) else { return heavy }
        return UIFont(descriptor: rounded, size: size)
    }
}
