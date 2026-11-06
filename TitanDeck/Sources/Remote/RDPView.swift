// Remote/RDPView.swift
import SwiftUI
import UIKit

/// Full-screen remote desktop canvas.
///
/// Touch (0.44.2): while the PC has RDP's touch channel open (Windows takes
/// touch over RDP), every finger goes as a real Windows touch, several at
/// once, so Titan's faders and buttons work as on a touchscreen and fingers
/// don't cancel each other; Windows does its own touch gestures. Otherwise
/// (the Windows sign-in screen, a PC without it, or Multi-touch off in
/// Settings) it's the mouse: one finger = left button (press, drag,
/// release), two-finger tap = right click, two-finger drag = scroll wheel.
/// Either way Pencil hover moves the pointer and a three-finger long press
/// opens Settings. Zoom (0.44.4, the Remote bar's magnifier): pinch to zoom
/// in, two fingers to move around, one finger clicks as the mouse. A hardware keyboard (Magic
/// Keyboard) types on the PC while the remote desktop is showing, and so does
/// the iPad's on-screen keyboard while `softKeyboardShown` is on.
struct RDPView: UIViewRepresentable {
    @ObservedObject var session: RDPSession
    var commandKey: RDPKeyboard.CommandKey = .control
    /// Real multi-touch when the PC takes it (Settings > Remote desktop).
    var multitouch = true
    /// Pinch and two-finger drag zoom and move the picture (0.44.4).
    var zoomMode = false
    /// Where the Remote bar's controls and the floating deck are: touches
    /// there are theirs, never the desktop's (0.44.4).
    var exclusions: RDPTouchExclusions?
    @Binding var softKeyboardShown: Bool
    var onOpenSettings: () -> Void

    func makeUIView(context: Context) -> RDPCanvasView {
        let view = RDPCanvasView()
        view.session = session
        view.commandKey = commandKey
        view.multitouch = multitouch
        view.exclusions = exclusions
        view.onOpenSettings = onOpenSettings
        view.onSoftKeyboardHidden = { [binding = $softKeyboardShown] in
            // Hidden with the keyboard's own key: put the button back.
            DispatchQueue.main.async { if binding.wrappedValue { binding.wrappedValue = false } }
        }
        session.frameHandler = { [weak view] image in view?.show(image) }
        return view
    }

    func updateUIView(_ view: RDPCanvasView, context: Context) {
        view.desktopSize = session.desktopSize
        view.commandKey = commandKey
        view.multitouch = multitouch
        view.exclusions = exclusions
        view.zoomMode = zoomMode
        view.onOpenSettings = onOpenSettings
        view.setSoftKeyboard(shown: softKeyboardShown)
    }

    static func dismantleUIView(_ view: RDPCanvasView, coordinator: ()) {
        view.releaseAllKeys()
        view.session?.frameHandler = nil
    }
}

final class RDPCanvasView: UIView, UIGestureRecognizerDelegate {
    weak var session: RDPSession?
    var multitouch = true
    var exclusions: RDPTouchExclusions?
    var zoomMode = false {
        didSet {
            guard zoomMode != oldValue else { return }
            pinch?.isEnabled = zoomMode
            if !zoomMode {
                zoom = RDPZoom()
                applyZoom(animated: true)
            }
        }
    }
    /// The picture, in its own layer so it can be zoomed without moving the view.
    private let imageLayer = CALayer()
    private var zoom = RDPZoom()
    private var pinch: UIPinchGestureRecognizer?
    var onOpenSettings: (() -> Void)?
    var desktopSize: CGSize = .zero
    var commandKey: RDPKeyboard.CommandKey = .control
    var onSoftKeyboardHidden: (() -> Void)?
    /// First responder while the on-screen keyboard is up (it's what makes iPadOS show it).
    private lazy var typingView: RDPTypingView = {
        let typing = RDPTypingView(frame: .zero)
        typing.canvas = self
        addSubview(typing)
        return typing
    }()

    /// How long a single finger waits for a second finger before it counts as a
    /// left-button press. Long enough to tell a two-finger gesture apart, short
    /// enough not to feel laggy.
    private static let pressDelay: TimeInterval = 0.08
    /// Movement that commits a pending press straight away (points).
    private static let moveSlop: CGFloat = 6

    /// The fingers going as real touch: the id each has on the PC (1-10,
    /// RDP's limit) and where it last was, so letting go off the desktop
    /// still lifts it where it left.
    private var fingers: [ObjectIdentifier: (id: Int32, x: UInt16, y: UInt16)] = [:]
    /// The touches on screen now go as real touch (decided as the first
    /// finger lands, for the whole lot until every finger is up).
    private var touchMode = false
    private var twoFingerTap: UITapGestureRecognizer?
    private var twoFingerPan: UIPanGestureRecognizer?

    private var trackedTouch: UITouch?
    private var touchStart: CGPoint = .zero
    private var buttonDown = false
    private var pressTimer: Timer?
    private var scroll = ScrollAccumulator()
    private var lastPanY: CGFloat = 0
    private var heldKeys = HeldKeys()
    private var repeatTimer: Timer?
    private var repeating: UInt32?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isMultipleTouchEnabled = true
        clipsToBounds = true
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .trilinear
        layer.addSublayer(imageLayer)

        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        addGestureRecognizer(twoFingerTap)
        self.twoFingerTap = twoFingerTap

        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.delegate = self
        addGestureRecognizer(twoFingerPan)
        self.twoFingerPan = twoFingerPan

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        pinch.isEnabled = false
        addGestureRecognizer(pinch)
        self.pinch = pinch

        let settingsPress = UILongPressGestureRecognizer(target: self, action: #selector(handleSettingsPress(_:)))
        settingsPress.numberOfTouchesRequired = 3
        settingsPress.minimumPressDuration = 0.6
        addGestureRecognizer(settingsPress)

        addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:))))

        // Nothing may stay held on the PC once TitanDeck isn't in front.
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show(_ image: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = image
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        zoom = zoom.clamped(viewSize: bounds.size)
        applyZoom(animated: false)
    }

    private func applyZoom(animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        imageLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        imageLayer.setAffineTransform(CGAffineTransform(translationX: zoom.offset.x, y: zoom.offset.y)
            .scaledBy(x: zoom.scale, y: zoom.scale))
        CATransaction.commit()
    }

    /// Touches on the Remote bar's controls or the floating deck aren't the
    /// desktop's: hit testing passes them on to those, above.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let exclusions, exclusions.contains(convert(point, to: nil)) { return nil }
        return super.hitTest(point, with: event)
    }

    private var mapper: DesktopMapper {
        DesktopMapper(viewSize: bounds.size, desktopSize: desktopSize)
    }

    /// The desktop pixel under a point in the view, through any zoom.
    private func desktopPoint(_ point: CGPoint) -> (x: UInt16, y: UInt16)? {
        mapper.desktopPoint(for: zoom.unzoomed(point, viewSize: bounds.size))
    }

    // MARK: - Hardware keyboard

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() } else { releaseAllKeys() }
    }

    /// Shows or hides the iPad's on-screen keyboard.
    func setSoftKeyboard(shown: Bool) {
        guard window != nil else { return }
        if shown, !typingView.isFirstResponder {
            typingView.becomeFirstResponder()
        } else if !shown, typingView.isFirstResponder {
            becomeFirstResponder()
        }
    }

    fileprivate func softKeyboardDidHide() {
        onSoftKeyboardHidden?()
    }

    /// The on-screen keyboard's typing (and its row of extra keys).
    fileprivate func send(_ strokes: [RDPKeyStroke]) {
        for stroke in strokes { session?.send(stroke) }
    }

    override func resignFirstResponder() -> Bool {
        releaseAllKeys()
        return super.resignFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unhandled = keysDown(presses)
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unhandled = keysUp(presses)
        if !unhandled.isEmpty { super.pressesEnded(unhandled, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }

    /// Hardware keys going down, sent to the PC; returns the ones it doesn't take.
    fileprivate func keysDown(_ presses: Set<UIPress>) -> Set<UIPress> {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let usage = press.key.map({ $0.keyCode.rawValue }),
                  let scancode = RDPKeyboard.scancode(hidUsage: usage, command: commandKey) else {
                unhandled.insert(press)
                continue
            }
            guard heldKeys.press(hidUsage: usage, scancode: scancode) else { continue }
            session?.key(scancode: scancode, down: true)
            if !RDPKeyboard.isModifier(hidUsage: usage) { startRepeat(scancode) }
        }
        return unhandled
    }

    fileprivate func keysUp(_ presses: Set<UIPress>) -> Set<UIPress> {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let usage = press.key.map({ $0.keyCode.rawValue }),
                  let scancode = heldKeys.release(hidUsage: usage) else {
                unhandled.insert(press)
                continue
            }
            if repeating == scancode { stopRepeat() }
            session?.key(scancode: scancode, down: false)
        }
        return unhandled
    }

    /// Lets go of every key still down on the PC.
    func releaseAllKeys() {
        liftAllFingers()
        stopRepeat()
        for scancode in heldKeys.releaseAll() {
            session?.key(scancode: scancode, down: false)
        }
    }

    @objc private func appWillResignActive() {
        releaseAllKeys()
        liftAllFingers()
    }

    /// The last key pressed repeats while held, like a PC keyboard.
    private func startRepeat(_ scancode: UInt32) {
        stopRepeat()
        repeating = scancode
        repeatTimer = Timer.scheduledTimer(withTimeInterval: RDPKeyboard.repeatDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.repeatTimer = Timer.scheduledTimer(withTimeInterval: RDPKeyboard.repeatInterval, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.session?.key(scancode: scancode, down: true) }
                }
            }
        }
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeating = nil
    }

    // MARK: - One finger: left button

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isFirstResponder, !typingView.isFirstResponder { becomeFirstResponder() }   // back from a menu or sheet
        let active = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? touches
        // The first finger down decides: real touch if the PC takes it now.
        if active.count == touches.count, fingers.isEmpty, trackedTouch == nil {
            // Zooming, two fingers are the zoom's: fingers go as the mouse.
            touchMode = !zoomMode && multitouch && session?.touchReady == true
        }
        if touchMode {
            touches.forEach(fingerDown)
            return
        }
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
        if touchMode {
            touches.forEach(fingerMoved)
            return
        }
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
        if touchMode {
            for touch in touches { fingerUp(touch, phase: .up) }
            return
        }
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
        if touchMode {
            for touch in touches { fingerUp(touch, phase: .cancelled) }
            return
        }
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

    // MARK: - Real touch (0.44.2)

    private func fingerDown(_ touch: UITouch) {
        let key = ObjectIdentifier(touch)
        guard fingers[key] == nil, let p = desktopPoint(touch.location(in: self)),
              let id = (1 ... Int32(Self.maxFingers)).first(where: { id in !fingers.values.contains { $0.id == id } })
        else { return }   // off the desktop, or more fingers than RDP takes
        fingers[key] = (id: id, x: p.x, y: p.y)
        session?.touch(.down, id: id, x: p.x, y: p.y)
    }

    private func fingerMoved(_ touch: UITouch) {
        let key = ObjectIdentifier(touch)
        guard let finger = fingers[key], let p = desktopPoint(touch.location(in: self)),
              p.x != finger.x || p.y != finger.y else { return }
        fingers[key] = (id: finger.id, x: p.x, y: p.y)
        session?.touch(.moved, id: finger.id, x: p.x, y: p.y)
    }

    private func fingerUp(_ touch: UITouch, phase: RDPSession.TouchPhase) {
        guard let finger = fingers.removeValue(forKey: ObjectIdentifier(touch)) else { return }
        let p = desktopPoint(touch.location(in: self)) ?? (x: finger.x, y: finger.y)
        session?.touch(phase, id: finger.id, x: p.x, y: p.y)
    }

    /// Nothing may stay touching the PC once TitanDeck isn't in front.
    private func liftAllFingers() {
        for finger in fingers.values {
            session?.touch(.cancelled, id: finger.id, x: finger.x, y: finger.y)
        }
        fingers.removeAll()
    }

    /// RDP's touch channel takes up to ten contacts.
    private static let maxFingers = 10

    /// In real touch, two fingers are Windows' own: no right click or scroll wheel.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if touchMode, gestureRecognizer === twoFingerTap || gestureRecognizer === twoFingerPan { return false }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    // MARK: - Gestures

    @objc private func handleTwoFingerTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let p = desktopPoint(recognizer.location(in: self)) else { return }
        session?.mouseMove(x: p.x, y: p.y)
        session?.mouseButton(.right, down: true, x: p.x, y: p.y)
        session?.mouseButton(.right, down: false, x: p.x, y: p.y)
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        if zoomMode {
            // Zooming: two fingers move the picture around.
            let delta = recognizer.translation(in: self)
            recognizer.setTranslation(.zero, in: self)
            zoom = zoom.panned(by: delta, viewSize: bounds.size)
            applyZoom(animated: false)
            return
        }
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

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard zoomMode, recognizer.state == .changed || recognizer.state == .ended else { return }
        let location = recognizer.location(in: self)
        let focus = CGPoint(x: location.x - bounds.midX, y: location.y - bounds.midY)
        zoom = zoom.pinched(by: recognizer.scale, around: focus, viewSize: bounds.size)
        recognizer.scale = 1
        applyZoom(animated: false)
    }

    /// Zooming, pinch and two-finger drag work together.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        (gestureRecognizer === pinch && other === twoFingerPan) || (gestureRecognizer === twoFingerPan && other === pinch)
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

/// Invisible, and first responder while the on-screen keyboard is up: iPadOS
/// only shows its keyboard for a view that takes text. What's typed goes to the
/// PC as keystrokes (`RDPTyping`); a hardware keyboard still goes key by key
/// through the canvas, so nothing is typed twice.
private final class RDPTypingView: UIView, UIKeyInput {
    weak var canvas: RDPCanvasView?
    private var latched: [RDPExtraKey] = []
    private var latchButtons: [RDPExtraKey: UIButton] = [:]

    // Plain typing: no autocorrect, capitals or smart punctuation changing what's sent.
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var inlinePredictionType: UITextInlinePredictionType = .no
    var keyboardAppearance: UIKeyboardAppearance = .dark

    override var canBecomeFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            clearLatches()
            canvas?.softKeyboardDidHide()
        }
        return resigned
    }

    // MARK: UIKeyInput

    /// Always: so Backspace always sends, even with nothing "typed" here.
    var hasText: Bool { true }

    func insertText(_ text: String) {
        canvas?.send(RDPTyping.strokes(for: text, holding: latched.map(\.scancode)))
        clearLatches()
    }

    func deleteBackward() {
        canvas?.send(RDPTyping.tap(RDPTyping.backspace, holding: latched.map(\.scancode)))
        clearLatches()
    }

    // A hardware keyboard: key by key, like the canvas (not calling super keeps
    // iPadOS from also inserting it as text).
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unhandled = canvas?.keysDown(presses) ?? presses
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unhandled = canvas?.keysUp(presses) ?? presses
        if !unhandled.isEmpty { super.pressesEnded(unhandled, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }

    // MARK: Extra keys

    override var inputAccessoryView: UIView? { extraKeys }

    private lazy var extraKeys: UIView = {
        let bar = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 52), inputViewStyle: .keyboard)
        bar.allowsSelfSizing = true
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        for key in RDPExtraKey.allCases {
            let button = UIButton(configuration: Self.configuration(for: key, lit: false),
                                  primaryAction: UIAction { [weak self] _ in self?.tapped(key) })
            button.accessibilityLabel = key.title
            if key.latches { latchButtons[key] = button }
            row.addArrangedSubview(button)
        }
        bar.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: bar.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: bar.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: bar.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -6),
            row.heightAnchor.constraint(equalToConstant: 40),
        ])
        return bar
    }()

    private static func configuration(for key: RDPExtraKey, lit: Bool) -> UIButton.Configuration {
        var configuration = lit ? UIButton.Configuration.prominentGlass() : .glass()
        configuration.title = key.title
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = .systemFont(ofSize: 15, weight: .semibold)
            return attributes
        }
        return configuration
    }

    private func tapped(_ key: RDPExtraKey) {
        if key.latches {
            if let index = latched.firstIndex(of: key) { latched.remove(at: index) } else { latched.append(key) }
            showLatches()
            return
        }
        canvas?.send(RDPTyping.tap(key.scancode, holding: latched.map(\.scancode)))
        clearLatches()
    }

    private func clearLatches() {
        guard !latched.isEmpty else { return }
        latched = []
        showLatches()
    }

    /// A latched Ctrl or Alt shows lit until the next key.
    private func showLatches() {
        for (key, button) in latchButtons {
            button.configuration = Self.configuration(for: key, lit: latched.contains(key))
        }
    }
}
