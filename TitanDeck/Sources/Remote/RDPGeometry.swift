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
    /// On a small screen (0.44.4) the desktop can be iPad-sized instead, the
    /// same shape as the screen but at least `iPadShortSide` points on its
    /// short side: Titan gets room to lay out, the picture is smaller, and
    /// Zoom brings it close.
    static func sessionSize(for viewSize: CGSize, choice: RDPDesktopSize = .screen) -> (width: UInt32, height: UInt32) {
        func clamp(_ value: CGFloat, fallback: UInt32) -> UInt32 {
            guard value.isFinite, value >= 64 else { return fallback }
            let even = UInt32(min(value, 4096)) & ~1
            return max(even, 64)
        }
        var size = viewSize
        let shortSide = min(viewSize.width, viewSize.height)
        if choice.isLarger(forShortSide: shortSide), shortSide > 0 {
            let scale = iPadShortSide / shortSide
            size = CGSize(width: viewSize.width * scale, height: viewSize.height * scale)
        }
        return (clamp(size.width, fallback: 1366), clamp(size.height, fallback: 1024))
    }

    /// An 11-inch iPad's short side in points.
    static let iPadShortSide: CGFloat = 834
}

/// The size of desktop to ask the PC for (Settings > Remote desktop, 0.44.4).
enum RDPDesktopSize: String, Codable, CaseIterable, Hashable {
    /// iPad-sized on a phone-sized screen (iPhone, iPhone Duo), the screen's own on an iPad.
    case automatic
    /// The screen's own size: everything 1:1, small screens get a small desktop.
    case screen
    /// iPad-sized everywhere it's smaller: precise taps, or zoom in.
    case iPad

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .screen: "This screen"
        case .iPad: "iPad size"
        }
    }

    /// A screen shorter than this on its short side counts as phone-sized.
    static let phoneShortSide: CGFloat = 700

    func isLarger(forShortSide shortSide: CGFloat) -> Bool {
        switch self {
        case .automatic: shortSide < Self.phoneShortSide
        case .screen: false
        case .iPad: shortSide < DesktopMapper.iPadShortSide
        }
    }
}

/// How far the remote desktop is zoomed and moved (0.44.4), relative to the
/// view's centre: a point `p` from the centre shows at `offset + p * scale`.
/// Kept so the picture always covers the view (no zooming out past fit,
/// no panning off its edge). Pure, so it's tested.
struct RDPZoom: Equatable {
    var scale: CGFloat = 1
    var offset: CGPoint = .zero

    static let maxScale: CGFloat = 4

    var isZoomed: Bool { scale > 1.001 }

    /// Pinched by `factor` around `focus` (from the view's centre): what's
    /// under the fingers stays under them.
    func pinched(by factor: CGFloat, around focus: CGPoint, viewSize: CGSize) -> RDPZoom {
        let newScale = min(max(scale * factor, 1), Self.maxScale)
        let content = CGPoint(x: (focus.x - offset.x) / scale, y: (focus.y - offset.y) / scale)
        let moved = RDPZoom(scale: newScale,
                            offset: CGPoint(x: focus.x - content.x * newScale, y: focus.y - content.y * newScale))
        return moved.clamped(viewSize: viewSize)
    }

    func panned(by delta: CGPoint, viewSize: CGSize) -> RDPZoom {
        RDPZoom(scale: scale, offset: CGPoint(x: offset.x + delta.x, y: offset.y + delta.y)).clamped(viewSize: viewSize)
    }

    /// Where a touch at `point` (in the view) falls on the unzoomed picture.
    func unzoomed(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        let centre = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        return CGPoint(x: centre.x + (point.x - centre.x - offset.x) / scale,
                       y: centre.y + (point.y - centre.y - offset.y) / scale)
    }

    func clamped(viewSize: CGSize) -> RDPZoom {
        let maxX = (scale - 1) * viewSize.width / 2
        let maxY = (scale - 1) * viewSize.height / 2
        return RDPZoom(scale: scale, offset: CGPoint(x: min(max(offset.x, -maxX), maxX),
                                                     y: min(max(offset.y, -maxY), maxY)))
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

/// Where the Remote screen's own controls are (the bar, the floating deck),
/// in window coordinates (0.44.4). The desktop leaves touches there alone,
/// so they always reach the controls above it.
@MainActor
final class RDPTouchExclusions {
    private var rects: [String: CGRect] = [:]

    func set(_ key: String, _ rect: CGRect?) {
        rects[key] = rect
    }

    func contains(_ point: CGPoint) -> Bool {
        rects.values.contains { $0.contains(point) }
    }
}
