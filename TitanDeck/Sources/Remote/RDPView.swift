// Remote/RDPView.swift
import SwiftUI
import UIKit

/// Full-screen remote desktop canvas.
///
/// Touch mapping: one finger = left button (press, drag, release - so Titan's
/// faders and buttons behave like a touchscreen), two-finger tap = right click,
/// two-finger drag = scroll wheel, Pencil hover = move the pointer,
/// three-finger long press = open Settings.
struct RDPView: UIViewRepresentable {
    @ObservedObject var session: RDPSession
    var onOpenSettings: () -> Void

    func makeUIView(context: Context) -> RDPCanvasView {
        let view = RDPCanvasView()
        view.session = session
        view.onOpenSettings = onOpenSettings
        session.frameHandler = { [weak view] image in view?.show(image) }
        return view
    }

    func updateUIView(_ view: RDPCanvasView, context: Context) {
        view.desktopSize = session.desktopSize
        view.onOpenSettings = onOpenSettings
    }

    static func dismantleUIView(_ view: RDPCanvasView, coordinator: ()) {
        view.session?.frameHandler = nil
    }
}

final class RDPCanvasView: UIView {
    weak var session: RDPSession?
    var onOpenSettings: (() -> Void)?
    var desktopSize: CGSize = .zero

    /// How long a single finger waits for a second finger before it counts as a
    /// left-button press. Long enough to tell a two-finger gesture apart, short
    /// enough not to feel laggy.
    private static let pressDelay: TimeInterval = 0.08
    /// Movement that commits a pending press straight away (points).
    private static let moveSlop: CGFloat = 6

    private var trackedTouch: UITouch?
    private var touchStart: CGPoint = .zero
    private var buttonDown = false
    private var pressTimer: Timer?
    private var scroll = ScrollAccumulator()
    private var lastPanY: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isMultipleTouchEnabled = true
        layer.contentsGravity = .resizeAspect
        layer.magnificationFilter = .linear
        layer.minificationFilter = .trilinear

        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        addGestureRecognizer(twoFingerTap)

        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        addGestureRecognizer(twoFingerPan)

        let settingsPress = UILongPressGestureRecognizer(target: self, action: #selector(handleSettingsPress(_:)))
        settingsPress.numberOfTouchesRequired = 3
        settingsPress.minimumPressDuration = 0.6
        addGestureRecognizer(settingsPress)

        addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show(_ image: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        CATransaction.commit()
    }

    private var mapper: DesktopMapper {
        DesktopMapper(viewSize: bounds.size, desktopSize: desktopSize)
    }

    private func desktopPoint(_ point: CGPoint) -> (x: UInt16, y: UInt16)? {
        mapper.desktopPoint(for: point)
    }

    // MARK: - One finger: left button

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let active = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? touches
        guard active.count == 1, let touch = touches.first, trackedTouch == nil else {
            // A second finger arrived: this is a gesture, not a click.
            abandonSingleTouch()
            return
        }
        trackedTouch = touch
        touchStart = touch.location(in: self)
        pressTimer = Timer.scheduledTimer(withTimeInterval: Self.pressDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.commitPress() }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        let point = touch.location(in: self)
        if !buttonDown {
            guard hypot(point.x - touchStart.x, point.y - touchStart.y) > Self.moveSlop else { return }
            commitPress()
        }
        if let p = desktopPoint(point) {
            session?.mouseMove(x: p.x, y: p.y)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        if !buttonDown {
            commitPress()   // a quick tap: press and release
        }
        if let p = desktopPoint(touch.location(in: self)) {
            session?.mouseButton(.left, down: false, x: p.x, y: p.y)
        }
        resetSingleTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch, touches.contains(touch) else { return }
        abandonSingleTouch()
    }

    private func commitPress() {
        pressTimer?.invalidate()
        pressTimer = nil
        guard !buttonDown, trackedTouch != nil, let p = desktopPoint(touchStart) else { return }
        session?.mouseMove(x: p.x, y: p.y)
        session?.mouseButton(.left, down: true, x: p.x, y: p.y)
        buttonDown = true
    }

    /// Ends a single-finger touch without clicking, releasing the button if it
    /// was already down so nothing is left held on the PC.
    private func abandonSingleTouch() {
        if buttonDown, let p = desktopPoint(touchStart) {
            session?.mouseButton(.left, down: false, x: p.x, y: p.y)
        }
        resetSingleTouch()
    }

    private func resetSingleTouch() {
        pressTimer?.invalidate()
        pressTimer = nil
        trackedTouch = nil
        buttonDown = false
    }

    // MARK: - Gestures

    @objc private func handleTwoFingerTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let p = desktopPoint(recognizer.location(in: self)) else { return }
        session?.mouseMove(x: p.x, y: p.y)
        session?.mouseButton(.right, down: true, x: p.x, y: p.y)
        session?.mouseButton(.right, down: false, x: p.x, y: p.y)
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self).y
        switch recognizer.state {
        case .began:
            scroll.reset()
            lastPanY = translation
        case .changed:
            let notches = scroll.add(translation - lastPanY)
            lastPanY = translation
            if notches != 0, let p = desktopPoint(recognizer.location(in: self)) {
                session?.scroll(notches: notches, x: p.x, y: p.y)
            }
        default:
            scroll.reset()
        }
    }

    @objc private func handleSettingsPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        abandonSingleTouch()
        onOpenSettings?()
    }

    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        guard recognizer.state == .changed || recognizer.state == .began,
              let p = desktopPoint(recognizer.location(in: self)) else { return }
        session?.mouseMove(x: p.x, y: p.y)
    }
}
