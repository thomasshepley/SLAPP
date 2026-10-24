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
    /// True while the main menu of layouts is showing instead of a page.
    @Published private(set) var isShowingMenu = false
    @Published private(set) var profile: DeckProfile

    /// Called for every key whose action goes to Titan. The Int is the key index,
    /// so the result can be flashed back onto the right key.
    var onAction: ((TitanAction, Int) -> Void)?
    /// Called when a key with the openSettings action is pressed.
    var onOpenSettings: (() -> Void)?
    /// Called when the profile changes (e.g. re-flowed for a smaller deck) so it can be saved.
    var onProfileChanged: ((DeckProfile) -> Void)?

    /// Per-key press/failure highlight. Published so the on-screen deck mirrors it.
    @Published private(set) var overlays: [Int: DeckRenderer.Overlay] = [:]
    /// User numbers of playbacks Titan reports as active (M8).
    @Published private(set) var activePlaybacks: Set<Int> = []
    /// Latching keys that are switched on (their pressed look shows until pressed again).
    @Published private(set) var latchedKeys: Set<UUID> = []
    private var started = false
    /// Running while the Menu key is held; opens the menu after 2 s.
    private var menuHoldTask: Task<Void, Never>?
    static let menuHoldSeconds: Double = 2
    private var cancellables = Set<AnyCancellable>()

    init(profile: DeckProfile) {
        self.profile = profile
    }

    /// What the deck is showing: a profile page, or the main menu.
    var currentPage: DeckPage? {
        if isShowingMenu { return menuPage }
        return profile.pages.indices.contains(currentPageIndex) ? profile.pages[currentPageIndex] : nil
    }

    /// The main menu: one key per layout (page), built from the profile so new
    /// pages appear automatically. Pressing one opens that layout.
    var menuPage: DeckPage {
        let palette = ["#2D4FA3", "#1E7D32", "#8A5A00", "#6A3FA0", "#0E7C86", "#B23B1E"]
        let keys = profile.pages.prefix(profile.keyCount).enumerated().map { index, page in
            KeyDefinition(index: index, label: page.name, colorHex: palette[index % palette.count],
                          action: .switchPage(index))
        }
        return DeckPage(name: "Main Menu", keys: Array(keys))
    }

    func showMenu() {
        menuHoldTask?.cancel()
        menuHoldTask = nil
        isShowingMenu = true
        overlays.removeAll()
        redraw()
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
        guard profile.pages.indices.contains(index), index != currentPageIndex || isShowingMenu else { return }
        isShowingMenu = false
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

        // The shipped default is laid out for a 15-key deck. On another size,
        // re-flow it so Menu is still reachable. Hand-edited profiles are left alone.
        if profile.isBuiltInDefault, caps.keyCount > 0, caps.keyCount != profile.keyCount {
            profile = DeckProfile.makeDefault(keyCount: caps.keyCount, orientation: profile.orientation)
            currentPageIndex = 0
            onProfileChanged?(profile)
        }

        newDevice.inputEventHandler = { [weak self] event in
            guard case let .keyPress(index, pressed) = event, let self,
                  let logical = self.profile.geometry.logicalIndex(forPhysical: index) else { return }
            self.handleKey(logical, pressed: pressed)
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

    /// Key press from the on-screen deck (iPhone, or iPad without hardware):
    /// same paging, actions and feedback as a hardware key.
    func pressOnScreenKey(_ index: Int, pressed: Bool) {
        handleKey(index, pressed: pressed)
    }

    /// `index` is the logical key (as laid out in the profile).
    private func handleKey(_ index: Int, pressed: Bool) {
        guard let key = currentPage?.key(at: index) else { return }

        // A latching key flips its look on every press, action or not.
        if pressed, key.pressedStyle?.resolvedMode == .latch {
            if latchedKeys.contains(key.id) { latchedKeys.remove(key.id) } else { latchedKeys.insert(key.id) }
            draw(logicalIndex: index)
        }
        guard let action = key.action else { return }

        guard pressed else {
            if action == .mainMenu {
                // Let go before 2 s: no menu.
                menuHoldTask?.cancel()
                menuHoldTask = nil
            }
            // Key up: clear the pressed highlight unless a failure flash is showing.
            if overlays[index] == .pressed { setOverlay(nil, at: index) }
            return
        }

        switch action {
        case .mainMenu:
            setOverlay(.pressed, at: index)
            menuHoldTask?.cancel()
            menuHoldTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.menuHoldSeconds * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                self.showMenu()
            }
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
        let page = currentPageIndex, menu = isShowingMenu
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, self.currentPageIndex == page, self.isShowingMenu == menu,
                  self.overlays[index] == .failure else { return }
            self.setOverlay(nil, at: index)
        }
    }

    private func setOverlay(_ overlay: DeckRenderer.Overlay?, at index: Int) {
        overlays[index] = overlay
        draw(logicalIndex: index)
    }

    /// Updates live playback state and redraws only the keys that changed.
    func setActivePlaybacks(_ active: Set<Int>) {
        guard active != activePlaybacks else { return }
        let changed = active.symmetricDifference(activePlaybacks)
        activePlaybacks = active
        guard let page = currentPage else { return }
        for key in page.keys where key.action?.playbackUserNumber.map({ changed.contains($0) }) == true {
            draw(logicalIndex: key.index)
        }
    }

    func isLatched(_ key: KeyDefinition?) -> Bool {
        key.map { latchedKeys.contains($0.id) } ?? false
    }

    func isActive(_ key: KeyDefinition?) -> Bool {
        guard let number = key?.action?.playbackUserNumber else { return false }
        return activePlaybacks.contains(number)
    }

    // MARK: - Drawing

    func redraw() {
        guard let device else { return }
        for physical in 0..<device.capabilities.keyCount {
            draw(physicalIndex: physical)
        }
    }

    private func draw(logicalIndex: Int) {
        guard let physical = profile.geometry.physicalIndex(forLogical: logicalIndex) else { return }
        draw(physicalIndex: physical)
    }

    /// Draws one hardware key, turned to suit how the deck is mounted.
    private func draw(physicalIndex physical: Int) {
        guard let device, physical < device.capabilities.keyCount, device.supports(.setKeyImage) else { return }
        let size = device.capabilities.keySize ?? CGSize(width: 96, height: 96)
        let geometry = profile.geometry
        let logical = geometry.logicalIndex(forPhysical: physical)
        let key = logical.flatMap { currentPage?.key(at: $0) }
        let image = DeckRenderer.image(for: key, size: size, overlay: logical.flatMap { overlays[$0] } ?? .none,
                                       isActive: isActive(key), isLatched: isLatched(key),
                                       quarterTurns: geometry.imageQuarterTurns)
        device.setKeyImage(image, at: physical)
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
