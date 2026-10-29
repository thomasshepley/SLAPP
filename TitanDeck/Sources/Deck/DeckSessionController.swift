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
    /// A page shown in place of the profile page: the main menu, or Quick
    /// Keys after a selection.
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
    /// Called when the Masters page needs Titan's page 60 fresh.
    var onNeedMasters: (() -> Void)?
    /// Called for the FX pages' presses (Test mode), with the key that
    /// shows the result: AppState sends them to TitanDeck Host.
    var onFX: ((DeckFX.Command, Int) -> Void)?
    /// Called when the FX fixtures page needs Titan's FXZone groups.
    var onNeedFXZones: (() -> Void)?
    /// Called when a set's groups are needed (the set, 0-based).
    var onNeedGroups: ((Int) -> Void)?
    /// Called when a set is picked on the deck, to keep it for next time.
    var onGroupSetChosen: ((Int) -> Void)?
    /// Called when a group is pressed: select it on the desk (the group's
    /// handle Titan id, and the key that shows the result).
    var onPickGroup: ((Int, Int) -> Void)?

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
    /// What a key turns while it's held, unless it has a pressed look of its
    /// own (Settings > Deck > Held key colour).
    @Published var heldColorHex: String? = DeckRenderer.defaultHeldHex {
        didSet { if heldColorHex != oldValue { redraw() } }
    }
    /// Keys a finger is on right now, so a red failure flash goes back to
    /// the held look rather than the plain key.
    private var heldKeys: Set<Int> = []
    /// What's been typed on the deck's keypad, to spot "102 Enter".
    private var keypad = DeckFlow.KeypadBuffer()
    /// What's selected in Titan, as far as the deck knows: from the desk
    /// itself while the desk link is up, else what the deck's keypad left
    /// selected ("102 Enter", "102 @ 50 Enter"), empty after a Clear. Shown
    /// on the Remote screen.
    @Published private(set) var selectedFixtures: [Int] = []
    /// Where the Quick Keys selection strip starts (a tap on it moves on).
    private var stripOffset = 0
    /// The first selected fixture's live level (0...1), for the flash key.
    @Published private(set) var liveLevel: Double?
    /// The desk link is up: the desk's selection is the one that counts.
    var deskLinked = false {
        didSet { if deskLinked != oldValue { refreshSelection() } }
    }
    /// Called whenever `selectedFixtures` changes.
    var onSelectionChanged: (([Int]) -> Void)?
    /// A Slate page button (the Int is the key, to flash its result back).
    var onSlate: ((SlateStore.Command, Int) -> Void)?
    /// The slate showing, from the Host's Slate Book, for the Slate page's keys.
    var slateState: HostSlateState? {
        didSet {
            guard slateState != oldValue, case .slate? = flowOverlay else { return }
            redraw()
        }
    }
    /// The selection's colour temperature, when known (Titan's active CCT
    /// palette, or the last one the deck applied): shown on the CCT keys.
    @Published private(set) var currentKelvin: Int?
    /// Called when the colour temperature keys come up, to ask Titan for the current CCT.
    var onColourShown: (() -> Void)?

    func setCurrentKelvin(_ kelvin: Int?) {
        guard kelvin != currentKelvin else { return }
        currentKelvin = kelvin
        guard let page = currentPage else { return }
        for key in page.keys where Self.isCCT(key.action) { draw(logicalIndex: key.index) }
    }

    private static func isCCT(_ action: TitanAction?) -> Bool {
        switch action {
        case .colourTemperature?, .colourPresets?: true
        default: false
        }
    }

    /// Highlight is on, as far as the deck knows (the Rig page's key).
    @Published private(set) var highlightOn = false
    /// Group master levels set from the deck (titanId: 0...1), shown when
    /// Titan doesn't report the fader's level itself.
    @Published private(set) var masterLevels: [Int: Double] = [:]
    /// The Groups page's sets (Settings > Deck > Groups page).
    var groupSettings = DeckGroups.Settings() {
        didSet {
            guard groupSettings != oldValue else { return }
            if case .groups? = flowOverlay { redraw() } else if case .groupSets? = flowOverlay { redraw() }
        }
    }
    /// Each set's groups as Titan last listed them.
    private(set) var groupLists: [Int: [DeckGroups.Group]] = [:]

    /// The FX page is on the main menu (Test mode).
    var fxEnabled = false {
        didSet { if fxEnabled != oldValue, flowOverlay == .menu { redraw() } }
    }
    /// The FX tab's effects that have a Prism Folder and File.
    var fxItems: [DeckFX.Item] = [] {
        didSet { if fxItems != oldValue, flowOverlay.map(Self.showsFX) == true { redraw() } }
    }
    /// What the deck set on each Prism layer (clip, levels), for the FX keys.
    @Published private(set) var fxLayers: [Int: DeckFX.LayerState] = [:]
    /// The FXZone groups, read when the FX fixtures page opens.
    private(set) var fxZones: [DeckFX.Zone] = []
    /// The layer a video is being picked for from its own page (no layer pick then).
    private var fxTargetLayer: Int?

    /// What's on Titan's page 60, read when Masters opens (nil until Titan
    /// answers; then Titan's whole playback list is used).
    @Published private(set) var pageMasters: [CueChoice]?
    /// The group masters on Titan's page 60.
    var groupMasters: [DeckFlow.GroupMaster] { DeckFlow.groupMasters(pageMasters ?? availableCues, levels: masterLevels) }
    private var deskSelection: [Int] = []
    private var follower = DeckFlow.SelectionFollower()

    /// "101-110" for the Remote screen, or nil with nothing selected.
    var selectionLabel: String? { DeckFlow.selectionLabel(selectedFixtures) }
    private var started = false
    /// The loading screen's animation frame while it's up (the deck shows the
    /// TitanDeck icon with a shine across it, and its keys do nothing).
    private(set) var splashFrame: Int?
    private var splashTask: Task<Void, Never>?
    /// Running while the Menu key is held; opens the menu after a second.
    private var menuHoldTask: Task<Void, Never>?
    static let menuHoldSeconds: Double = 1
    private var cancellables = Set<AnyCancellable>()

    init(profile: DeckProfile) {
        self.profile = profile
    }

    /// What the deck is showing: a profile page, the main menu, or Quick
    /// Keys (after a selection, or its own page picked).
    var currentPage: DeckPage? {
        if let splashFrame {
            return DeckFlow.splashPage(columns: profile.geometry.logicalColumns, keyCount: profile.keyCount, frame: splashFrame)
        }
        switch flowOverlay {
        case .menu?: return DeckFlow.menuPage(profile: profile, fx: fxEnabled)
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
        case .slate(let returnTo)?:
            return DeckFlow.slatePage(profile: profile, returnTo: returnTo)
        case .rig(let returnTo)?:
            return DeckFlow.rigPage(profile: profile, returnTo: returnTo, highlightOn: highlightOn)
        case .masters?:
            return DeckFlow.mastersPage(profile: profile, masters: groupMasters)
        case .masterLevel(let titanId, _)?:
            return DeckFlow.masterLevelPage(master: groupMasters.first { $0.titanId == titanId }, keyCount: profile.keyCount)
        case .fx(let returnTo)?:
            return DeckFX.fxPage(profile: profile, layers: fxLayers, returnTo: returnTo)
        case .fxVersions(let category, _)?:
            return DeckFX.versionsPage(category: category, items: fxItems, keyCount: profile.keyCount)
        case .fxLayerPick(let id, _)?:
            return DeckFX.layerPickPage(item: fxItems.first { $0.id == id }, layers: fxLayers, keyCount: profile.keyCount)
        case .fxLayer(let layer, _)?:
            return DeckFX.layerPage(layer: layer, state: fxLayers[layer] ?? DeckFX.LayerState(), keyCount: profile.keyCount)
        case .fxLevel(let layer, let control, _)?:
            return DeckFX.levelPage(layer: layer, control: control, current: fxLayers[layer]?.levels[control],
                                    keyCount: profile.keyCount)
        case .fxFixtures(let layer, _)?:
            return DeckFX.fixturesPage(layer: layer, zones: fxZones, keyCount: profile.keyCount)
        case .groupSets?:
            return DeckGroups.setsPage(settings: groupSettings, keyCount: profile.keyCount)
        case .groups(let set, _)?:
            return DeckGroups.groupsPage(set: set, settings: groupSettings, groups: groupLists[set], keyCount: profile.keyCount)
        case nil:
            // The Quick Keys page always comes with its flash, CCT and way back.
            if currentPageIndex == DeckFlow.quickKeysPageIndex(in: profile) {
                return DeckFlow.selectionPage(profile: profile,
                                              returnTo: DeckFlow.keypadPageIndex(in: profile) ?? currentPageIndex)
            }
            return page(currentPageIndex)
        }
    }

    private func page(_ index: Int) -> DeckPage? {
        profile.pages.indices.contains(index) ? profile.pages[index] : nil
    }

    /// A key on the current page as it acts: the keypad's Clear is THRU
    /// while nothing is selected.
    private func key(at index: Int) -> KeyDefinition? {
        let onKeypad = flowOverlay == nil && currentPageIndex == DeckFlow.keypadPageIndex(in: profile)
        return DeckFlow.keypadKey(currentPage?.key(at: index), onKeypad: onKeypad, hasSelection: !selectedFixtures.isEmpty)
    }

    /// A key as drawn: the Menu key says where it goes or the page it's on,
    /// cue keys carry their cue and fade time.
    func displayedKey(at index: Int) -> KeyDefinition? {
        let menuLabel = DeckFlow.menuLabel(onPage: currentPageIndex, overlay: flowOverlay, profile: profile,
                                           pageName: currentPage?.name, hasSelection: !selectedFixtures.isEmpty,
                                           selectionText: DeckFlow.compactSelection(selectedFixtures))
        return DeckFlow.displayed(key(at: index), onPage: menuLabel, workspaceNames: workspaceNames)
            .map { DeckCues.displayed($0, slots: profile.cueSlots) }
            .map { key in
                // The selection strip shows the selected fixture numbers.
                guard case .deckChoice(.selectionStrip(let slot))? = key.action else { return key }
                let strip = DeckFlow.selectionStrip(selectedFixtures, offset: stripOffset, slots: stripSlots)
                var shown = key
                shown.label = strip.labels.indices.contains(slot) ? strip.labels[slot] : ""
                if slot == 0, shown.label.isEmpty { shown.label = DeckFlow.nothingSelected }
                return shown
            }
            .map { DeckFlow.slateKey($0, state: slateState) }
            .map { DeckFlow.cctKey($0, current: currentKelvin) }
            .map { key in
                // The flash key carries the selected fixture's live level.
                let level = liveLevel ?? typedLevel
                guard key.action == .flashSelection, level != nil || key.label == DeckFlow.flashLabel(level: nil)
                else { return key }
                var shown = key
                shown.label = DeckFlow.flashLabel(level: level)
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

    /// Fixtures the deck selected on the desk itself (a Groups page group):
    /// the deck's selection straight away, so the intensity keys act on them
    /// even without the desk link (with it, CITP confirms it).
    func selectTyped(_ fixtures: [Int]) {
        keypad.select(fixtures)
        if deskLinked { deskSelection = fixtures }
        refreshSelection()
    }

    /// The level the deck last typed for the selection (0...1), shown on the
    /// flash key when there's no live reading.
    var typedLevel: Double? {
        didSet {
            guard typedLevel != oldValue, liveLevel == nil, let page = currentPage else { return }
            for key in page.keys where key.action == .flashSelection { draw(logicalIndex: key.index) }
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
        let current = deskLinked ? deskSelection : keypad.selected
        guard current != selectedFixtures else { return }
        selectedFixtures = current
        stripOffset = 0
        onSelectionChanged?(current)
        // The keypad's Menu key and the Quick Keys selection strip show it;
        // the keypad's Clear is THRU while nothing is selected.
        if let page = currentPage {
            for key in page.keys where key.action == .mainMenu || key.action == .keypadClear || Self.isStrip(key.action) {
                draw(logicalIndex: key.index)
            }
        }
    }

    // MARK: - Loading screen

    /// The TitanDeck icon on the deck, a shine sweeping across it ten times a
    /// second, until `endSplash`.
    func startSplash() {
        guard splashTask == nil else { return }
        splashFrame = 0
        redraw()
        splashTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self, !Task.isCancelled, let frame = self.splashFrame else { return }
                self.splashFrame = frame + 1
                self.redraw()
            }
        }
    }

    func endSplash() {
        splashTask?.cancel()
        splashTask = nil
        guard splashFrame != nil else { return }
        splashFrame = nil
        overlays.removeAll()
        redraw()
    }

    func showMenu() {
        menuHoldTask?.cancel()
        menuHoldTask = nil
        show(.menu)
    }

    private func show(_ overlay: DeckFlow.Overlay?) {
        switch overlay {
        case .titanPages?: onNeedCues?()
        case .masters?: if let onNeedMasters { onNeedMasters() } else { onNeedCues?() }
        case .fxFixtures?: onNeedFXZones?()
        case .groups(let set, _)?: onNeedGroups?(set)
        case .colour?: onColourShown?()
        default: break
        }
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
        if pressed { heldKeys.insert(index) } else { heldKeys.remove(index) }
        guard splashFrame == nil, let key = key(at: index) else { return }

        // A latching key flips its look on every press, action or not.
        if pressed, key.pressedStyle?.resolvedMode == .latch {
            if latchedKeys.contains(key.id) { latchedKeys.remove(key.id) } else { latchedKeys.insert(key.id) }
            draw(logicalIndex: index)
        }
        guard let action = key.action else { return }

        guard pressed else {
            if action == .mainMenu, let hold = menuHoldTask {
                // Let go within the second: a tap, so keypad <-> Quick Keys.
                hold.cancel()
                menuHoldTask = nil
                setOverlay(nil, at: index)
                switch DeckFlow.menuTap(onPage: currentPageIndex, overlay: flowOverlay, profile: profile,
                                        hasSelection: !selectedFixtures.isEmpty) {
                case .quickKeys(let keypad): show(.selection(returnTo: keypad))
                case .page(let page): showPage(page)
                case .groups(let keypad): showGroups(returnTo: keypad)
                }
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
            // Labelled GO but latches, like a latch button on the desk: fires
            // its cue, or releases it if it's live. Nothing on it yet: a red
            // flash (Connect Cue puts one on).
            if let cue = profile.cue(onSlot: slot) {
                setOverlay(.pressed, at: index)
                onAction?(latchGo(titanId: cue.titanId), index)
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
            if action == .toggleHighlight {
                highlightOn.toggle()
                draw(logicalIndex: index)
            }
            let event = keypad.apply(action)
            refreshSelection()
            switch event {
            case .selected where flowOverlay == nil:
                // "102 Enter" selected fixtures: bring up Quick Keys.
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

    /// How many keys the selection strip on the current page has.
    private var stripSlots: Int {
        currentPage?.keys.filter { Self.isStrip($0.action) }.count ?? 0
    }

    private static func isStrip(_ action: TitanAction?) -> Bool {
        if case .deckChoice(.selectionStrip)? = action { true } else { false }
    }

    /// A press on one of the Connect Cue / fade pickers, or the selection strip.
    private func choose(_ choice: DeckChoice, at index: Int) {
        let slateCommand: SlateStore.Command? = switch choice {
        case .slateTake: .take
        case .slateNew: .newSlate(nil)
        case .slateLetter: .letter
        case .slateNight: .toggleNight
        case .slateFx: .toggleFx
        default: nil
        }
        if let slateCommand {
            setOverlay(.pressed, at: index)
            onSlate?(slateCommand, index)
            return
        }
        if case .slateShow = choice { return }
        if case .openSlates = choice {
            show(.slate(returnTo: DeckFlow.keypadPageIndex(in: profile) ?? currentPageIndex))
            return
        }
        if case .openRig = choice {
            show(.rig(returnTo: DeckFlow.keypadPageIndex(in: profile) ?? currentPageIndex))
            return
        }
        if case .openMasters = choice {
            show(.masters(returnTo: DeckFlow.keypadPageIndex(in: profile) ?? currentPageIndex))
            return
        }
        if case .openFX = choice {
            fxTargetLayer = nil
            show(.fx(returnTo: DeckFlow.keypadPageIndex(in: profile) ?? currentPageIndex))
            return
        }
        if case .selectionStrip = choice {
            // On to the next selected fixtures (back to the start after the last).
            stripOffset = DeckFlow.selectionStrip(selectedFixtures, offset: stripOffset, slots: stripSlots).next
            redraw()
            return
        }
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
        case (.pickMaster(let titanId), .masters):
            show(.masterLevel(titanId: titanId, returnTo: home))
        case (.masterLevel(let level), .masterLevel(let titanId, _)):
            onAction?(.setGroupMaster(titanId: titanId, level: level), index)
            masterLevels[titanId] = level
            show(.masters(returnTo: home))
        case (.back, .masterLevel):
            show(.masters(returnTo: home))
        // FX (Test mode).
        case (.fxCategory(let raw), .fx):
            guard let category = DeckFX.Category(rawValue: raw) else { return }
            show(.fxVersions(category: category, returnTo: home))
        case (.fxLayer(let layer), .fx):
            fxTargetLayer = nil
            show(.fxLayer(layer: layer, returnTo: home))
        case (.fxReleaseAll, .fx):
            onFX?(.releaseAll, index)
            fxLayers = [:]
            redraw()
        case (.fxItem(let raw), .fxVersions):
            guard let id = UUID(uuidString: raw), let item = fxItems.first(where: { $0.id == id }) else { return }
            if let layer = fxTargetLayer {
                fxTargetLayer = nil
                setVideo(item, on: layer, home: home)
            } else {
                show(.fxLayerPick(item: id, returnTo: home))
            }
        case (.fxLayer(let layer), .fxLayerPick(let id, _)):
            guard let item = fxItems.first(where: { $0.id == id }) else { return }
            setVideo(item, on: layer, home: home)
        case (.fxPickVideo, .fxLayer(let layer, _)):
            fxTargetLayer = layer
            show(.fx(returnTo: home))
        case (.fxControl(let raw), .fxLayer(let layer, _)):
            guard let control = DeckFX.Control(rawValue: raw) else { return }
            show(.fxLevel(layer: layer, control: control, returnTo: home))
        case (.fxLevel(let level), .fxLevel(let layer, let control, _)):
            fxLayers[layer, default: DeckFX.LayerState()].levels[control] = level
            show(.fxLayer(layer: layer, returnTo: home))
            // Its result shows on the control's key on the layer page.
            onFX?(.setLevel(layer: layer, control: control, level: level), 1 + (DeckFX.Control.allCases.firstIndex(of: control) ?? 0))
        case (.fxGo, .fxLayer(let layer, _)):
            onFX?(.go(layer: layer), index)
        case (.fxStop, .fxLayer(let layer, _)):
            onFX?(.stop(layer: layer), index)
        case (.fxRelease, .fxLayer(let layer, _)):
            onFX?(.release(layer: layer), index)
            fxLayers[layer] = nil
            redraw()
        case (.fxFixtures, .fxLayer(let layer, _)):
            show(.fxFixtures(layer: layer, returnTo: home))
        case (.fxUseSelection, .fxFixtures(let layer, _)):
            onFX?(.fixtures(layer: layer, change: .replace), index)
        case (.fxAdd, .fxFixtures(let layer, _)):
            onFX?(.fixtures(layer: layer, change: .add), index)
        case (.fxRemove, .fxFixtures(let layer, _)):
            onFX?(.fixtures(layer: layer, change: .remove), index)
        case (.fxZone(let titanId), .fxFixtures(let layer, _)):
            guard let zone = fxZones.first(where: { $0.titanId == titanId }) else { return }
            onFX?(.zone(layer: layer, zone: zone), index)
        case (.back, .fxVersions), (.back, .fxLayerPick):
            show(.fx(returnTo: home))
        case (.back, .fxLayer):
            fxTargetLayer = nil
            show(.fx(returnTo: home))
        case (.back, .fxLevel(let layer, _, _)), (.back, .fxFixtures(let layer, _)):
            show(.fxLayer(layer: layer, returnTo: home))
        // Groups (Nothing Selected).
        case (.pickGroupSet(let set), .groupSets):
            groupSettings.chosen = set
            onGroupSetChosen?(set)
            show(.groups(set: set, returnTo: home))
        case (.changeGroupSet, .groups):
            show(.groupSets(returnTo: home))
        case (.pickGroup(let titanId), .groups):
            onPickGroup?(titanId, index)
            // On to Quick Keys: the desk's selection comes in over CITP once typed.
            show(.selection(returnTo: home))
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

    /// A latching GO: release when the cue is live, fire when it isn't. The
    /// lit look flips straight away; the next poll of Titan corrects it.
    func latchGo(titanId: Int) -> TitanAction {
        if activeTitanIds.contains(titanId) {
            activeTitanIds.remove(titanId)
            redraw()
            return .releaseHandle(titanId: titanId)
        }
        activeTitanIds.insert(titanId)
        redraw()
        return .fireHandle(titanId: titanId)
    }

    /// Nothing Selected: the set in use's groups, or the sets to pick one.
    private func showGroups(returnTo keypad: Int) {
        if let set = groupSettings.current {
            show(.groups(set: set, returnTo: keypad))
        } else {
            show(.groupSets(returnTo: keypad))
        }
    }

    /// A set's groups from Titan, for the Groups page.
    func setGroups(_ groups: [DeckGroups.Group], forSet set: Int) {
        guard groupLists[set] != groups else { return }
        groupLists[set] = groups
        if case .groups(set, _)? = flowOverlay { redraw() }
    }

    /// A video onto a layer, then that layer's page (the result shows on its clip key).
    private func setVideo(_ item: DeckFX.Item, on layer: Int, home: Int) {
        fxLayers[layer, default: DeckFX.LayerState()].clip = item.title
        show(.fxLayer(layer: layer, returnTo: home))
        onFX?(.setVideo(layer: layer, item: item), 0)
    }

    /// The FXZone groups, for the FX fixtures page.
    func setFXZones(_ zones: [DeckFX.Zone]) {
        guard zones != fxZones else { return }
        fxZones = zones
        if case .fxFixtures? = flowOverlay { redraw() }
    }

    private static func showsFX(_ overlay: DeckFlow.Overlay) -> Bool {
        switch overlay {
        case .fx, .fxVersions, .fxLayerPick, .fxLayer, .fxLevel, .fxFixtures: return true
        default: return false
        }
    }

    /// The handles on Titan's page 60, for the Masters page.
    func setPageMasters(_ cues: [CueChoice]) {
        guard cues != pageMasters else { return }
        pageMasters = cues
        if flowOverlay.map(Self.showsCues) == true { redraw() }
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
        case .titanPages, .titanCues, .masters, .masterLevel: return true
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
            // Still held (a flash key): back to the held look until it's let go.
            self.setOverlay(self.heldKeys.contains(index) ? .pressed : nil, at: index)
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
                                       heldHex: heldColorHex, quarterTurns: geometry.imageQuarterTurns)
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
