// Remote/RDPSession.swift
import CoreGraphics
import Foundation

/// The Swift face of one FreeRDP connection (via the C bridge in Remote/Bridge).
/// FreeRDP runs on its own thread; everything here is main-actor.
@MainActor
final class RDPSession: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    enum MouseButton {
        case left
        case right
        case middle
    }

    @Published private(set) var state: State = .idle
    /// Remote desktop size in pixels; zero until connected.
    @Published private(set) var desktopSize: CGSize = .zero
    /// The host the current/last connection went to.
    @Published private(set) var host = ""
    /// Reconnect attempt in progress after a dropped session (0 = not reconnecting).
    @Published private(set) var reconnectAttempt = 0
    /// When the next reconnect attempt starts, while waiting between attempts.
    @Published private(set) var nextReconnect: Date?

    /// Receives each new frame. Kept off @Published so 30-60 frames a second
    /// don't re-render SwiftUI; the canvas view sets this.
    var frameHandler: ((CGImage) -> Void)?

    private let box: CallbackBox
    private var handle: OpaquePointer?
    private var buffer = [UInt8]()
    private var certificateRejected = false

    private struct Request {
        var host: String
        var port: UInt16
        var username: String
        var domain: String
        var password: String
        var viewSize: CGSize
    }

    private let policy = ReconnectPolicy()
    private var lastRequest: Request?
    /// True once a session has been up; a later failure then means "dropped",
    /// which reconnects, rather than "couldn't connect", which waits for the user.
    private var hasBeenConnected = false
    private var userDisconnected = false
    private var reconnectTask: Task<Void, Never>?

    init(trust: CertificateTrustStore = CertificateTrustStore()) {
        box = CallbackBox(trust: trust)
        var callbacks = TitanRDPCallbacks()
        callbacks.userdata = Unmanaged.passUnretained(box).toOpaque()
        callbacks.on_state = { userdata, state, message in
            guard let userdata else { return }
            let box = Unmanaged<CallbackBox>.fromOpaque(userdata).takeUnretainedValue()
            box.stateChanged(state, message: message.map { String(cString: $0) })
        }
        callbacks.on_frame = { userdata, _, _, _, _ in
            guard let userdata else { return }
            Unmanaged<CallbackBox>.fromOpaque(userdata).takeUnretainedValue().frameChanged()
        }
        callbacks.on_resize = { userdata, width, height in
            guard let userdata else { return }
            Unmanaged<CallbackBox>.fromOpaque(userdata).takeUnretainedValue().resized(width: width, height: height)
        }
        callbacks.on_certificate = { userdata, host, port, fingerprint, _ in
            guard let userdata, let host, let fingerprint else { return 0 }
            let box = Unmanaged<CallbackBox>.fromOpaque(userdata).takeUnretainedValue()
            return box.checkCertificate(host: String(cString: host), port: port,
                                        fingerprint: String(cString: fingerprint)) ? 1 : 0
        }
        handle = titan_rdp_new(callbacks)
        box.session = self
    }

    deinit {
        // Joins the connection thread, so no callback can arrive after this.
        titan_rdp_free(handle)
    }

    // MARK: - Connection

    func connect(host: String, port: UInt16, username: String, domain: String, password: String, viewSize: CGSize) {
        cancelReconnect()
        userDisconnected = false
        hasBeenConnected = false
        start(Request(host: host, port: port, username: username, domain: domain, password: password, viewSize: viewSize))
    }

    private func start(_ request: Request) {
        lastRequest = request
        let host = request.host, port = request.port, username = request.username
        let domain = request.domain, password = request.password, viewSize = request.viewSize
        guard let handle else {
            state = .failed("Remote desktop couldn't start")
            return
        }
        switch state {
        case .connecting, .connected: return
        case .idle, .failed: break
        }
        let size = DesktopMapper.sessionSize(for: viewSize)
        certificateRejected = false
        self.host = host
        let result = host.withCString { h in
            username.withCString { u in
                domain.withCString { d in
                    password.withCString { p in
                        titan_rdp_connect(handle, h, port, u, d, p, size.width, size.height)
                    }
                }
            }
        }
        state = result == 0 ? .connecting : .failed("Couldn't start the connection")
        if result != 0, hasBeenConnected, !userDisconnected {
            scheduleReconnect()
        }
        Log.deck("RDP connect to \(host):\(port) at \(size.width)x\(size.height) -> \(result == 0 ? "started" : "refused")")
    }

    func disconnect() {
        userDisconnected = true
        let wasWaiting = reconnectTask != nil
        cancelReconnect()
        if wasWaiting, state != .connecting, state != .connected {
            state = .idle   // nothing running between attempts - just stop
        }
        titan_rdp_disconnect(handle)
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        nextReconnect = nil
        reconnectAttempt = 0
    }

    /// Schedules the next attempt after a dropped session.
    private func scheduleReconnect() {
        guard let request = lastRequest else { return }
        reconnectAttempt += 1
        let delay = policy.delay(forAttempt: reconnectAttempt)
        nextReconnect = Date().addingTimeInterval(delay)
        Log.deck("RDP dropped - reconnect attempt \(reconnectAttempt) in \(delay) s")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, !self.userDisconnected else { return }
            self.reconnectTask = nil
            self.nextReconnect = nil
            self.start(request)
        }
    }

    // MARK: - Input (desktop pixel coordinates)

    func mouseMove(x: UInt16, y: UInt16) {
        titan_rdp_mouse_move(handle, x, y)
    }

    func mouseButton(_ button: MouseButton, down: Bool, x: UInt16, y: UInt16) {
        let raw: TitanRDPButton
        switch button {
        case .left: raw = TITAN_RDP_BUTTON_LEFT
        case .right: raw = TITAN_RDP_BUTTON_RIGHT
        case .middle: raw = TITAN_RDP_BUTTON_MIDDLE
        }
        titan_rdp_mouse_button(handle, raw, down ? 1 : 0, x, y)
    }

    /// Positive notches scroll up.
    func scroll(notches: Int, x: UInt16, y: UInt16) {
        guard notches != 0 else { return }
        let step: Int32 = notches > 0 ? 120 : -120
        for _ in 0..<min(abs(notches), 10) {
            titan_rdp_mouse_wheel(handle, step, x, y)
        }
    }

    func key(scancode: UInt32, down: Bool) {
        titan_rdp_key(handle, scancode, down ? 1 : 0)
    }

    // MARK: - Callbacks (main actor)

    fileprivate func handleState(_ raw: TitanRDPState, message: String?) {
        if raw == TITAN_RDP_STATE_CONNECTING {
            state = .connecting
        } else if raw == TITAN_RDP_STATE_CONNECTED {
            state = .connected
            hasBeenConnected = true
            cancelReconnect()
        } else if raw == TITAN_RDP_STATE_FAILED {
            if hasBeenConnected, !userDisconnected, !certificateRejected {
                state = .failed(message ?? "Connection lost")
                scheduleReconnect()
                Log.deck("RDP state: \(state)")
                return
            }
            state = .failed(certificateRejected
                ? "The PC's security certificate has changed. If that's expected (e.g. Windows was reinstalled), forget it in Settings."
                : (message ?? "Connection failed"))
        } else {
            state = .idle
            desktopSize = .zero
        }
        Log.deck("RDP state: \(state)")
    }

    fileprivate func handleResize(width: UInt32, height: UInt32) {
        desktopSize = CGSize(width: Int(width), height: Int(height))
    }

    fileprivate func handleCertificateRejected() {
        certificateRejected = true
    }

    /// Copies the latest desktop pixels out of FreeRDP into a CGImage.
    fileprivate func refreshFrame() {
        guard let handle, let frameHandler else { return }
        var width: UInt32 = 0, height: UInt32 = 0, stride: UInt32 = 0
        _ = titan_rdp_copy_frame(handle, nil, 0, &width, &height, &stride)
        let needed = Int(stride) * Int(height)
        guard needed > 0 else { return }
        if buffer.count != needed {
            buffer = [UInt8](repeating: 0, count: needed)
        }
        let copied = buffer.withUnsafeMutableBufferPointer { pointer in
            titan_rdp_copy_frame(handle, pointer.baseAddress, needed, &width, &height, &stride)
        }
        guard copied == 0, let provider = CGDataProvider(data: Data(buffer) as CFData) else { return }
        // FreeRDP's BGRA32 is little-endian 32-bit xRGB.
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let image = CGImage(width: Int(width), height: Int(height), bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: Int(stride), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info,
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return }
        frameHandler(image)
    }
}

/// Receives C callbacks on the FreeRDP thread and forwards them to the main
/// actor. Owned by RDPSession and outlives the connection thread.
private final class CallbackBox: @unchecked Sendable {
    /// Only touched on the main thread.
    weak var session: RDPSession?
    let trust: CertificateTrustStore
    private let lock = NSLock()
    private var framePending = false

    init(trust: CertificateTrustStore) {
        self.trust = trust
    }

    private func onMain(_ work: @escaping @MainActor (RDPSession) -> Void) {
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let session = self?.session else { return }
                work(session)
            }
        }
    }

    func stateChanged(_ state: TitanRDPState, message: String?) {
        onMain { $0.handleState(state, message: message) }
    }

    func resized(width: UInt32, height: UInt32) {
        onMain { $0.handleResize(width: width, height: height) }
    }

    /// Coalesces paints: at most one refresh queued at a time.
    func frameChanged() {
        lock.lock()
        let alreadyQueued = framePending
        framePending = true
        lock.unlock()
        guard !alreadyQueued else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.framePending = false
            self.lock.unlock()
            MainActor.assumeIsolated { self.session?.refreshFrame() }
        }
    }

    /// Runs on the FreeRDP thread and must answer straight away.
    func checkCertificate(host: String, port: UInt16, fingerprint: String) -> Bool {
        let decision = trust.evaluate(host: host, port: port, fingerprint: fingerprint)
        Log.deck("RDP certificate \(host):\(port) \(fingerprint.prefix(23))... -> \(decision)")
        if decision == .mismatch {
            onMain { $0.handleCertificateRejected() }
            return false
        }
        return true
    }
}
