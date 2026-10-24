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
    /// A page shown in place of the profile page: the main menu, or the
    /// intensity keys after a keypad selection.
    @Published private(set) var flowOverlay: DeckFlow.Overlay?
    /// True while the main menu of layouts is showing instead of a page.
    var isShowingMenu: Bool { flowOverlay == .menu }
    @Published private(set) var profile: DeckProfile

    /// Called for every key whose action goes to Titan. The Int is the key index,
    /// so the result can be flashed back onto the right key.
    var onAction: ((TitanAction, Int) -> Void)?
    /// Called when a key with the openSettings action is pressed.
    var onOpenSettings: (() -> Void)?
    /// Called when the profile changes (e.g. re-flowed for a smaller deck) so it can be saved.
    var onProfileChanged: ((DeckProfile) -> Void)?
    /// Called when Connect Cue needs Titan's playback list fresh.
    var onNeedCues: (() -> Void)?

    /// Per-key press/failure highlight. Published so the on-screen deck mirrors it.
    @Published private(set) var overlays: [Int: DeckRenderer.Overlay] = [:]
    /// User numbers of playbacks Titan reports as active (M8).
    @Published private(set) var activePlaybacks: Set<Int> = []
    /// Titan's workspace names by user number, for workspace keys with no label.
    @Published private(set) var workspaceNames: [Int: String] = [:]
    /// Every playback Titan has, across its pages, for Connect Cue.
    @Published private(set) var availableCues: [CueChoice] = []
    /// titanIds of live playbacks, to light connected GO keys.
    @Published private(set) var activeTitanIds: Set<Int> = []
    /// Fixture ranges whose flash fades rather than snaps (Settings > Deck).
    var flashFadeRules: [FlashFadeRule] = []
    /// Latching keys that are switched on (their pressed look shows until pressed again).
    @Published private(set) var latchedKeys: Set<UUID> = []
    /// What's been typed on the deck's keypad, to spot "102 Enter".
    private var keypad = DeckFlow.KeypadBuffer()
    /// What's selected in Titan, as far as the deck knows: from the desk
    /// itself while the desk link is up, else what the deck's keypad left
    /// selected ("102 Enter", "102 @ 50 Enter"), empty after a Clear. Shown
    /// on the Remote screen.
    @Published private(set) var selectedFixtures: [Int] = []
    /// The first selected fixture's live level (0...1), for the flash key.
    @Published private(set) var liveLevel: Double?
    /// The desk link is up: the desk's selection is the one that counts.
    var deskLinked = false {
        didSet { if deskLinked != oldValue { refreshSelection() } }
    }
    /// Called whenever `selectedFixtures` changes.
    var onSelectionChanged: (([Int]) -> Void)?
    private var deskSelection: [Int] = []
    private var follower = DeckFlow.SelectionFollower()

    /// "101-110" for the Remote screen, or nil with nothing selected.
    var selectionLabel: String? { DeckFlow.selectionLabel(selectedFixtures) }
    private var started = false
    /// Running while the Menu key is held; opens the menu after 2 s.
    private var menuHoldTask: Task<Void, Never>?
    static let menuHoldSeconds: Double = 2
    private var cancellables = Set<AnyCancellable>()

    init(profile: DeckProfile) {
        self.profile = profile
    }

    /// What the deck is showing: a profile page, the main menu, or the
    /// intensity keys after a selection.
    var currentPage: DeckPage? {
        switch flowOverlay {
        case .menu?: return DeckFlow.menuPage(profile: profile)
        case .selection(let returnTo)?: return DeckFlow.selectionPage(profile: profile, returnTo: returnTo)
        case .colour(let returnTo)?: return DeckFlow.colourPage(profile: profile, returnTo: returnTo)
        case .connectCue(let returnTo)?:
            return DeckCues.connectPage(from: page(returnTo) ?? DeckPage(name: "", keys: []), slots: profile.cueSlots)
        case .titanPages(_, let first, _, _)?:
            return DeckCues.pagesPage(cues: availableCues, keyCount: profile.keyCount, first: first)
        case .titanCues(_, let titanPage, _, _)?:
            return DeckCues.cuesPage(cues: availableCues, page: titanPage, keyCount: profile.keyCount)
        case .fadePicker(let slot, let fadeOut, _)?:
            let cue = profile.cue(onSlot: slot)
            return DeckCues.fadePage(current: fadeOut ? cue?.fadeOut : cue?.fadeIn, fadeOut: fadeOut,
                                     keyCount: profile.keyCount)
        case nil: return page(currentPageIndex)
        }
    }

    private func page(_ index: Int) -> DeckPage? {
        profile.pages.indices.contains(index) ? profile.pages[index] : nil
    }

    /// A key as drawn: the Menu key carries the current page's name, cue keys
    /// their cue and fade time.
    func displayedKey(at index: Int) -> KeyDefinition? {
        DeckFlow.displayed(currentPage?.key(at: index), onPage: currentPage?.name, workspaceNames: workspaceNames)
            .map { DeckCues.displayed($0, slots: profile.cueSlots) }
            .map { key in
                // The flash key carries the selected fixture's live level.
                guard key.action == .flashSelection, liveLevel != nil || key.label == DeckFlow.flashLabel(level: nil)
                else { return key }
                var shown = key
                shown.label = DeckFlow.flashLabel(level: liveLevel)
                return shown
            }
    }

    /// The desk's selection, from the desk link. Something new selected
    /// brings up the intensity keys (as if typed on the keypad); an empty
    /// selection puts them away again.
    func setDeskSelection(_ fixtures: [Int]) {
        deskSelection = fixtures
        guard deskLinked else { return }
        refreshSelection()
        switch follower.update(fixtures) {
        case .show:
            if flowOverlay == nil { show(.selection(returnTo: currentPageIndex)) }
        case .hide:
            if case .selection(let home)? = flowOverlay { showPage(home) }
        case .none:
            break
        }
    }

    /// The live level of the first selected fixture, or nil.
    func setLiveLevel(_ level: Double?) {
        guard level != liveLevel else { return }
        liveLevel = level
        guard let page = currentPage else { return }
        for key in page.keys where key.action == .flashSelection { draw(logicalIndex: key.index) }
    }

    private func refreshSelection() {
        let current = deskLinked ? deskSelection : keypad.selection.map { [$0] } ?? []
        guard current != selectedFixtures else { return }
        selectedFixtures = current
        onSelectionChanged?(current)
    }

    func showMenu() {
        menuHoldTask?.cancel()
        menuHoldTask = nil
        show(.menu)
    }

    private func show(_ overlay: DeckFlow.Overlay?) {
        if case .titanPages? = overlay { onNeedCues?() }
        flowOverlay = overlay
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
        guard profile.pages.indices.contains(index), index != currentPageIndex || flowOverlay != nil else { return }
        flowOverlay = nil
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
            let slots = profile.cueSlots
            profile = DeckProfile.makeDefault(keyCount: caps.keyCount, orientation: profile.orientation)
            profile.cueSlots = slots
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
            if action == .mainMenu, let hold = menuHoldTask {
                // Let go before 2 s: a tap, so on to the next page.
                hold.cancel()
                menuHoldTask = nil
                setOverlay(nil, at: index)
                showPage(DeckFlow.nextPage(after: currentPageIndex, pageCount: profile.pages.count))
                return
            }
            if action == .flashSelection {
                onAction?(.dimmerFlash(down: false, seconds: flashFade), index)
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
        case .colourPresets:
            // Back to wherever the selection started, or this page.
            show(.colour(returnTo: flowOverlay?.returnTo ?? currentPageIndex))
        case .cueGo(let slot):
            // Just a GO: fires its cue. Nothing on it yet: a red flash (Connect Cue puts one on).
            if let cue = profile.cue(onSlot: slot) {
                setOverlay(.pressed, at: index)
                onAction?(.fireHandle(titanId: cue.titanId), index)
            } else {
                report(success: false, forKey: index)
            }
        case .cueFade(let slot, let fadeOut):
            if profile.cue(onSlot: slot) != nil {
                show(.fadePicker(slot: slot, fadeOut: fadeOut, returnTo: currentPageIndex))
            } else {
                report(success: false, forKey: index)
            }
        case .connectCue:
            show(.connectCue(returnTo: currentPageIndex))
        case .deckChoice(let choice):
            choose(choice, at: index)
        case .flashSelection:
            setOverlay(.pressed, at: index)
            onAction?(.dimmerFlash(down: true, seconds: flashFade), index)
        default:
            setOverlay(.pressed, at: index)
            onAction?(action, index)
            let event = keypad.apply(action)
            refreshSelection()
            switch event {
            case .selected where flowOverlay == nil:
                // "102 Enter" selected fixtures: bring up the intensity keys.
                show(.selection(returnTo: currentPageIndex))
            case .clearedProgrammer:
                // Nothing's selected any more, so back to the keypad.
                if let keypadPage = DeckFlow.keypadPageIndex(in: profile) { showPage(keypadPage) }
            default:
                break
            }
        }
    }

    /// The fade for the flash key: from the rule covering the fixture last
    /// selected on the keypad, else none.
    private var flashFade: Double? {
        DeckCues.flashFade(forFixture: selectedFixtures.first, rules: flashFadeRules)
    }

    /// A press on one of the Connect Cue / fade pickers.
    private func choose(_ choice: DeckChoice, at index: Int) {
        guard let overlay = flowOverlay else { return }
        let home = overlay.returnTo
        switch (choice, overlay) {
        case (.assignSlot(let slot), _):
            show(.titanPages(slot: slot, first: 0, fromConnect: true, returnTo: home))
        case (.unassignSlot(let slot), _):
            changeProfile { $0.unassignSlot(slot) }
            redraw()
        case (.titanPage(let titanPage), .titanPages(let slot, _, let fromConnect, _)):
            show(.titanCues(slot: slot, page: titanPage, fromConnect: fromConnect, returnTo: home))
        case (.morePages(let first), .titanPages(let slot, _, let fromConnect, _)):
            show(.titanPages(slot: slot, first: first, fromConnect: fromConnect, returnTo: home))
        case (.pickCue(let titanId), .titanCues(let slot, _, let fromConnect, _)):
            guard let cue = availableCues.first(where: { $0.titanId == titanId }) else { return }
            changeProfile { $0.assign(cue.ref, toSlot: slot) }
            if fromConnect { show(.connectCue(returnTo: home)) } else { showPage(home) }
        case (.fadeTime(let seconds), .fadePicker(let slot, let fadeOut, _)):
            if let cue = profile.cue(onSlot: slot) {
                onAction?(.setCueFade(titanId: cue.titanId, fadeOut: fadeOut, seconds: seconds), index)
                changeProfile { $0.recordFade(seconds, fadeOut: fadeOut, onSlot: slot) }
            }
            showPage(home)
        case (.back, .titanCues(let slot, _, let fromConnect, _)):
            show(.titanPages(slot: slot, first: 0, fromConnect: fromConnect, returnTo: home))
        case (.back, .titanPages(_, _, true, _)):
            show(.connectCue(returnTo: home))
        case (.intensity, _):
            show(.selection(returnTo: home))
        case (.back, _), (.done, _):
            showPage(home)
        default:
            break
        }
    }

    /// Changes the profile from the deck itself (a connected cue, a fade) and saves it.
    private func changeProfile(_ change: (inout DeckProfile) -> Void) {
        change(&profile)
        onProfileChanged?(profile)
    }

    /// Titan's playbacks, for Connect Cue and for lighting connected GOs.
    func setAvailableCues(_ cues: [CueChoice]) {
        let active = Set(cues.filter(\.isActive).map(\.titanId))
        let changed = cues != availableCues
        availableCues = cues
        if active != activeTitanIds {
            activeTitanIds = active
            redraw()
        } else if changed, flowOverlay.map(Self.showsCues) == true {
            redraw()
        }
    }

    private static func showsCues(_ overlay: DeckFlow.Overlay) -> Bool {
        switch overlay {
        case .titanPages, .titanCues: return true
        default: return false
        }
    }

    /// Called by AppState once Titan has answered.
    func report(success: Bool, forKey index: Int) {
        guard !success else {
            if overlays[index] == .failure { setOverlay(nil, at: index) }
            return
        }
        setOverlay(.failure, at: index)
        let page = currentPageIndex, shown = flowOverlay
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, self.currentPageIndex == page, self.flowOverlay == shown,
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

    func setWorkspaceNames(_ names: [Int: String]) {
        guard names != workspaceNames else { return }
        workspaceNames = names
        redraw()
    }

    func isLatched(_ key: KeyDefinition?) -> Bool {
        key.map { latchedKeys.contains($0.id) } ?? false
    }

    func isActive(_ key: KeyDefinition?) -> Bool {
        switch key?.action {
        case .cueGo(let slot)?:
            return profile.cue(onSlot: slot).map { activeTitanIds.contains($0.titanId) } ?? false
        case .fireHandle(let id)?:
            return activeTitanIds.contains(id)
        default:
            guard let number = key?.action?.playbackUserNumber else { return false }
            return activePlaybacks.contains(number)
        }
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
        let key = logical.flatMap(displayedKey(at:))
        let overlay = logical.flatMap { overlays[$0] } ?? .none
        guard key != nil || overlay != .none else {
            // Nothing on this key: the deck's own fill, so it goes blank
            // rather than keeping the last page's picture.
            device.fillKey(.black, at: physical)
            return
        }
        let image = DeckRenderer.image(for: key, size: size, overlay: overlay,
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
