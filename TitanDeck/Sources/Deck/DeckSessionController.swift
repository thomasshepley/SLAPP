// Deck/DeckSessionController.swift
import Combine
import StreamDeckKit
import SwiftUI

/// Owns the Stream Deck Kit session: device attach/detach, key presses,
/// paging, and drawing the current page onto the hardware.
///
/// API checked against streamdeck-kit-ipad 1.3.0 source: devices arrive via
/// `StreamDeckSession.setUp(stateHandler:newDeviceHandler:)`, key presses via
/// `StreamDeck.inputEventHandler` (`.keyPress(index:pressed:)`), images go out
/// with `setKeyImage(_:at:)`.
@MainActor
final class DeckSessionController: ObservableObject {
    @Published private(set) var device: StreamDeck?
    @Published private(set) var statusText = "Not started"
    @Published private(set) var currentPageIndex = 0
    @Published private(set) var profile: DeckProfile

    /// Called for every key whose action goes to Titan. The Int is the key index,
    /// so the result can be flashed back onto the right key.
    var onAction: ((TitanAction, Int) -> Void)?
    /// Called when a key with the openSettings action is pressed.
    var onOpenSettings: (() -> Void)?
    /// Called when the profile changes (e.g. re-flowed for a smaller deck) so it can be saved.
    var onProfileChanged: ((DeckProfile) -> Void)?

    private var overlays: [Int: DeckRenderer.Overlay] = [:]
    private var started = false
    private var cancellables = Set<AnyCancellable>()

    init(profile: DeckProfile) {
        self.profile = profile
    }

    var currentPage: DeckPage? {
        profile.pages.indices.contains(currentPageIndex) ? profile.pages[currentPageIndex] : nil
    }

    /// Safe to call more than once - Stream Deck Kit's session is a singleton.
    func start() {
        guard !started else { return }
        started = true
        StreamDeckSession.instance.setUp(
            stateHandler: { [weak self] state in
                self?.statusText = Self.describe(state)
                Log.deck("Session state: \(state.debugDescription)")
            },
            newDeviceHandler: { [weak self] device in
                self?.attach(device)
            }
        )
        // Catch detaches that don't fire onClose (e.g. the on-screen simulator closing).
        StreamDeckSession.instance.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                guard let self, let current = self.device, !devices.contains(current) else { return }
                self.device = devices.last
                self.redraw()
            }
            .store(in: &cancellables)
    }

    /// Shows a page on the deck - used by the editor so the hardware mirrors the
    /// page being edited.
    func showPage(_ index: Int) {
        guard profile.pages.indices.contains(index), index != currentPageIndex else { return }
        currentPageIndex = index
        overlays.removeAll()
        redraw()
    }

    func replaceProfile(_ newProfile: DeckProfile) {
        profile = newProfile
        currentPageIndex = min(currentPageIndex, max(newProfile.pages.count - 1, 0))
        overlays.removeAll()
        redraw()
    }

    // MARK: - Device

    private func attach(_ newDevice: StreamDeck) {
        let caps = newDevice.capabilities
        Log.deck("Attached \(newDevice.info.productName) - \(caps.keyCount) keys (\(caps.keyColumns)x\(caps.keyRows))")
        device = newDevice

        // The shipped default is laid out for 32 keys. On a smaller deck, re-flow
        // it so the page key is still reachable. Hand-edited profiles are left alone.
        if profile.isBuiltInDefault, caps.keyCount > 0, caps.keyCount != profile.keyCount {
            profile = DeckProfile.makeDefault(keyCount: caps.keyCount)
            currentPageIndex = 0
            onProfileChanged?(profile)
        }

        newDevice.inputEventHandler = { [weak self] event in
            guard case let .keyPress(index, pressed) = event else { return }
            self?.handleKey(index, pressed: pressed)
        }
        newDevice.onClose { [weak self, weak newDevice] in
            await MainActor.run {
                guard let self, self.device === newDevice else { return }
                self.device = nil
                Log.deck("Device detached")
            }
        }
        redraw()
    }

    // MARK: - Keys

    private func handleKey(_ index: Int, pressed: Bool) {
        guard let key = currentPage?.key(at: index), let action = key.action else { return }

        guard pressed else {
            // Key up: clear the pressed highlight unless a failure flash is showing.
            if overlays[index] == .pressed { setOverlay(nil, at: index) }
            return
        }

        switch action {
        case .switchPage(let page):
            showPage(min(max(page, 0), max(profile.pages.count - 1, 0)))
        case .nextPage:
            showPage((currentPageIndex + 1) % max(profile.pages.count, 1))
        case .previousPage:
            let count = max(profile.pages.count, 1)
            showPage((currentPageIndex - 1 + count) % count)
        case .openSettings:
            onOpenSettings?()
        default:
            setOverlay(.pressed, at: index)
            onAction?(action, index)
        }
    }

    /// Called by AppState once Titan has answered.
    func report(success: Bool, forKey index: Int) {
        guard !success else {
            if overlays[index] == .failure { setOverlay(nil, at: index) }
            return
        }
        setOverlay(.failure, at: index)
        let page = currentPageIndex
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, self.currentPageIndex == page, self.overlays[index] == .failure else { return }
            self.setOverlay(nil, at: index)
        }
    }

    private func setOverlay(_ overlay: DeckRenderer.Overlay?, at index: Int) {
        overlays[index] = overlay
        draw(keyIndex: index)
    }

    // MARK: - Drawing

    func redraw() {
        guard let device else { return }
        for index in 0..<device.capabilities.keyCount {
            draw(keyIndex: index)
        }
    }

    private func draw(keyIndex index: Int) {
        guard let device, index < device.capabilities.keyCount, device.supports(.setKeyImage) else { return }
        let size = device.capabilities.keySize ?? CGSize(width: 96, height: 96)
        let image = DeckRenderer.image(for: currentPage?.key(at: index), size: size,
                                       overlay: overlays[index] ?? .none)
        device.setKeyImage(image, at: index)
    }

    // MARK: - Status text

    private static func describe(_ state: StreamDeckSession.State) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .started:
            return "Driver ready"
        case .failed(.missingEntitlement):
            return "Missing driver entitlement - check app signing"
        case .failed(.driverVersionMismatch):
            return "Driver version mismatch - update Stream Deck Connect"
        case .failed:
            return "Driver not found - install Stream Deck Connect and enable its driver in iPad Settings"
        }
    }
}
