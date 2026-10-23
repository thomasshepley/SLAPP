// Remote/RDPGeometry.swift
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Maps between the on-screen view and the remote desktop, which is drawn
/// aspect-fit (letterboxed) inside the view.
struct DesktopMapper: Equatable {
    var viewSize: CGSize
    var desktopSize: CGSize

    /// Where the desktop image sits inside the view.
    var fittedRect: CGRect {
        guard desktopSize.width > 0, desktopSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }
        let scale = min(viewSize.width / desktopSize.width, viewSize.height / desktopSize.height)
        let size = CGSize(width: desktopSize.width * scale, height: desktopSize.height * scale)
        return CGRect(x: (viewSize.width - size.width) / 2, y: (viewSize.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// The desktop pixel under a point in the view, clamped to the desktop edges
    /// (a touch in the letterbox lands on the nearest edge). Nil until sizes are known.
    func desktopPoint(for viewPoint: CGPoint) -> (x: UInt16, y: UInt16)? {
        let rect = fittedRect
        guard rect.width > 0, rect.height > 0 else { return nil }
        let scale = rect.width / desktopSize.width
        let x = ((viewPoint.x - rect.minX) / scale).rounded(.down)
        let y = ((viewPoint.y - rect.minY) / scale).rounded(.down)
        let clampedX = min(max(x, 0), desktopSize.width - 1)
        let clampedY = min(max(y, 0), desktopSize.height - 1)
        return (UInt16(clampedX), UInt16(clampedY))
    }

    /// Session size to ask the PC for: the view's size in points, so Titan's
    /// layout maps 1:1 onto the iPad. Even numbers, 64-4096 like FreeRDP wants.
    static func sessionSize(for viewSize: CGSize) -> (width: UInt32, height: UInt32) {
        func clamp(_ value: CGFloat, fallback: UInt32) -> UInt32 {
            guard value.isFinite, value >= 64 else { return fallback }
            let even = UInt32(min(value, 4096)) & ~1
            return max(even, 64)
        }
        return (clamp(viewSize.width, fallback: 1366), clamp(viewSize.height, fallback: 1024))
    }
}

/// Turns two-finger drag distance into mouse-wheel notches, carrying the
/// remainder so slow drags still scroll.
struct ScrollAccumulator {
    var pointsPerNotch: CGFloat = 24
    private var remainder: CGFloat = 0

    init(pointsPerNotch: CGFloat = 24) {
        self.pointsPerNotch = pointsPerNotch
    }

    /// Feed the finger movement since the last call (down is positive). Returns
    /// whole notches to send: positive scrolls up, like dragging a page down.
    mutating func add(_ deltaY: CGFloat) -> Int {
        remainder += deltaY
        let notches = (remainder / pointsPerNotch).rounded(.towardZero)
        remainder -= notches * pointsPerNotch
        return Int(notches)
    }

    mutating func reset() {
        remainder = 0
    }
}
