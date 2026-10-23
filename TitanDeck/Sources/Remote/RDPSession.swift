// Remote/RDPSession.swift
import CoreGraphics
import Foundation

/// Swift face of the FreeRDP session - stub until M5.
///
/// TODO(M5): build FreeRDP 3.x as an xcframework (or port iFreeRDP's
/// RDPSession / RDPSessionView), then implement these methods over it. Planned
/// flags: GFX without AVC420, /bpp:32, /network:lan, /auto-reconnect with
/// unlimited retries. See the "FreeRDP on iOS" section of the build plan:
/// https://claude.ai/artifact/PXtiepzci194FMHiHaynGM
///
/// TODO(M6): reconnect with exponential backoff (1 s, 2 s, 4 s, capped at
/// 10 s), keeping the last framebuffer on screen under a dimmed overlay.
@MainActor
final class RDPSession: ObservableObject {
    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    enum MouseButton {
        case left
        case right
        case middle
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var framebuffer: CGImage?

    func connect(settings: RDPSettings, password: String) async {
        // TODO(M5): hand the settings to FreeRDP and start the session.
    }

    func disconnect() {
        // TODO(M5)
    }

    func sendMouse(x: Int, y: Int, button: MouseButton, down: Bool) {
        // TODO(M5)
    }

    func sendScroll(x: Int, y: Int, delta: Int) {
        // TODO(M5)
    }

    func sendKey(scancode: UInt16, down: Bool) {
        // TODO(M5)
    }
}
