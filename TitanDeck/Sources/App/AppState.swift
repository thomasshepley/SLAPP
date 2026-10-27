// App/AppState.swift
import Combine
import SwiftUI
import UIKit

/// The one object that knows about all three layers. Deck, Titan and Remote
/// never talk to each other directly - everything is wired up here.
@MainActor
final class AppState: ObservableObject {
    enum Mode: Hashable {
        case remote
        case deck
        case companion
        case network
        case slates
        case settings
    }

    @Published var mode: Mode = .remote
    /// The AirDrop-style "Send to PC" sheet (M16).
    @Published var showingFileDrop = false
    @Published var titanHost: String {
        didSet {
            let host = titanHost
            UserDefaults.standard.set(host, forKey: SettingsKeys.titanHost)
            Task { await titan.setHost(host) }
            deskLink.setHost(host)
            watch.shareHost(host)
        }
    }
    /// Titan calls through TitanDeck Host (4436) instead of straight to Titan
    /// (4430), so the Host's Titan log shows every one, with Titan's errors.
    @Published var titanViaHost: Bool {
        didSet {
            UserDefaults.standard.set(titanViaHost, forKey: SettingsKeys.titanViaHost)
            let port = titanPort
            Task { await titan.setPort(port) }
        }
    }
    var titanPort: Int { titanViaHost ? TitanEndpoints.viaHostPort : TitanEndpoints.defaultPort }
    /// Newest first, capped - shown on the Settings screen as a latency log.
    @Published private(set) var recentResults: [TitanResult] = []
    @Published private(set) var titanVersion: String?
    @Published private(set) var isCheckingConnection = false
    /// Stream Deck Kit only gets key events while we're in the foreground.
    @Published private(set) var wasBackgrounded = false
    @Published var rdpSettings: RDPSettings {
        didSet { rdpSettings.save() }
    }
    /// Size of the remote view, so the RDP session can match it 1:1.
    var remoteViewSize: CGSize = .zero
    private var didAutoConnect = false

    let titan: TitanClient
    let deck: DeckSessionController
    let rdp: RDPSession
    let heartbeat: TitanHeartbeat
    let network: NetworkMonitor
    let localNetwork: LocalNetworkPermission
    /// Soak-test log of every drop-out and recovery (M7).
    let connectionLog: ConnectionLogStore
    /// Lights deck keys for playbacks that are live in Titan (M8).
    let playbackState: PlaybackStatePoller
    /// Apple Watch GO button, iPhone side (M10).
    let watch: WatchBridge
    /// Files queued for the PC (M16), through the Host or the shared folder.
    let fileDrop: FileDropStore
    /// The show Wi-Fi from the UniFi console (M17).
    let unifi: UniFiStore
    /// The Slate Book, kept by TitanDeck Host from Titan's sACN.
    let slates: SlateStore
    private var slateWatch: Task<Void, Never>?
    /// TitanDeck Host on the PC: pairing, PC health, files both ways (M18).
    let host: HostStore
    /// What's typed on the deck keypad, shown under the remote desktop.
    let keypad: KeypadReadoutStore
    /// Titan's UI WebAPI: follows the desk's selection, and takes the deck's
    /// commands while it's up so they land in the desk's own programmer.
    let deskLink: DeskLink
    /// The selected fixture's live level from sACN, through the Host.
    let intensity: IntensityReader
    private var logSubscriptions = Set<AnyCancellable>()
    private let store: ProfileStore

    private static let maxResults = 25

    init() {
        let host = UserDefaults.standard.string(forKey: SettingsKeys.titanHost) ?? ""
        titanHost = host
        let viaHost = UserDefaults.standard.bool(forKey: SettingsKeys.titanViaHost)
        titanViaHost = viaHost
        rdpSettings = RDPSettings.load()
        rdp = RDPSession()
        heartbeat = TitanHeartbeat()
        network = NetworkMonitor()
        localNetwork = LocalNetworkPermission()
        connectionLog = ConnectionLogStore()
        playbackState = PlaybackStatePoller()
        watch = WatchBridge()
        fileDrop = FileDropStore()
        unifi = UniFiStore()
        let hostStore = HostStore()
        self.host = hostStore
        slates = SlateStore(client: { [weak hostStore] in hostStore?.client })
        keypad = KeypadReadoutStore()
        let titan = TitanClient(host: host, port: viaHost ? TitanEndpoints.viaHostPort : TitanEndpoints.defaultPort)
        self.titan = titan
        let deskLink = DeskLink(api: titan)
        self.deskLink = deskLink
        intensity = IntensityReader(api: titan, host: { [weak hostStore] in hostStore?.client },
                                    deskLinked: { [weak deskLink] in deskLink?.isLinked ?? false })
        let store = ProfileStore()
        self.store = store
        deck = DeckSessionController(profile: DeckProfile.starting(from: store.load()))

        deck.onAction = { [weak self] action, keyIndex in
            self?.fire(action, fromKey: keyIndex)
        }
        deck.onOpenSettings = { [weak self] in
            self?.mode = .settings
        }
        deck.onProfileChanged = { [weak self] profile in
            self?.save(profile)
        }
        deck.onSlate = { [weak self] command, keyIndex in
            guard let self else { return }
            Task {
                let ok = await self.slates.perform(command)
                self.deck.report(success: ok, forKey: keyIndex)
                if !ok, let problem = self.slates.problem {
                    self.connectionLog.record(.key, .info, "Slate: \(problem)")
                }
            }
        }
        slates.onState = { [weak self] state in
            self?.deck.slateState = state
        }
    }

    /// Keeps the deck's Slate page showing the Host's slate and take while
    /// it's up (the Slates tab refreshes itself).
    private func watchSlates() {
        slateWatch?.cancel()
        slateWatch = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if case .slate? = self.deck.flowOverlay { await self.slates.refreshState() }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func start() {
        if showingStartup { deck.startSplash() }
        startConnectionLog()
        watchSlates()
        UIApplication.shared.isIdleTimerDisabled = true
        deck.start()
        network.start()
        localNetwork.check()
        heartbeat.start(client: titan) { [weak self] in
            !(self?.titanHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
        playbackState.onChange = { [weak self] active in
            self?.deck.setActivePlaybacks(active)
        }
        playbackState.onWorkspaceNames = { [weak self] names in
            self?.deck.setWorkspaceNames(names)
        }
        playbackState.onHandles = { [weak self] handles in
            self?.deck.setAvailableCues(Self.cueChoices(handles))
        }
        deck.onNeedCues = { [weak self] in
            guard let self else { return }
            Task {
                if let handles = await self.titan.playbackHandles() {
                    self.deck.setAvailableCues(Self.cueChoices(handles))
                }
            }
        }
        deck.flashFadeRules = flashFadeRules
        deck.heldColorHex = heldKeyColour
        deskLink.citpSelection = { [weak self] in
            guard let client = self?.host.client else { return nil }
            return try? await client.citpSelection()
        }
        deskLink.onSelection = { [weak self] fixtures in
            self?.deck.setDeskSelection(fixtures)
        }
        deskLink.onLinkChange = { [weak self] linked in
            guard let self else { return }
            self.deck.deskLinked = linked
            self.connectionLog.record(.app, .info, linked
                ? "Desk link up: following the desk's selection, deck commands go to the desk's programmer"
                : "Desk link down: deck commands go to Titan's WebAPI user (4430)")
        }
        deck.onSelectionChanged = { [weak self] fixtures in
            guard let self else { return }
            self.intensity.setFixture(fixtures.first)
            self.showTypedLevel()
            // Typed on the desk: the deck's WebAPI user selects the same fixtures,
            // so the intensity, flash and colour keys act on them. (Following the
            // desk's selection does this itself.)
            if self.keypadTypesOnDesk, !self.deskLink.isLinked {
                let titan = self.titan
                Task { await titan.selectFixtures(userNumbers: fixtures) }
            }
        }
        intensity.onLevel = { [weak self] level in
            self?.deck.setLiveLevel(level)
        }
        deskLink.setHost(titanHost)
        playbackState.start(client: titan) { [weak self] in
            self?.heartbeat.health.isReachable ?? false
        }
        watch.start(titan: titan) { [weak self] command, result in
            guard let self else { return }
            self.recentResults.insert(result, at: 0)
            if self.recentResults.count > Self.maxResults {
                self.recentResults.removeLast(self.recentResults.count - Self.maxResults)
            }
            if !result.ok {
                self.connectionLog.record(.key, .info, "Watch \(command.action.summary) failed: \(result.error ?? "no reply")")
            }
        }
        watch.shareHost(titanHost)
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            wasBackgrounded = true
            connectionLog.record(.app, .info, "Went to background - Stream Deck inactive")
            Log.deck("App went to background - Stream Deck keys are inactive until it returns")
        case .active:
            if wasBackgrounded {
                connectionLog.record(.app, .info, "Back in foreground")
            }
            UIApplication.shared.isIdleTimerDisabled = true
            localNetwork.check()
        default:
            break
        }
    }

    /// The loading screen (health checks, then Continue) is up; the deck
    /// shows the TitanDeck logo meanwhile.
    @Published private(set) var showingStartup = true

    func finishStartup() {
        showingStartup = false
        deck.endSplash()
    }

    func dismissBackgroundWarning() {
        wasBackgrounded = false
    }

    // MARK: - Titan

    /// Fire an action at Titan. Pass the key index when it came from the deck
    /// so a failure can flash that key red.
    /// The keypad types on the Titan PC (Settings > Desk link), so it's on the
    /// desk's own command line and its selection shows on the desk.
    var keypadTypesOnDesk: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.keypadTypesOnDesk) as? Bool ?? true
    }
    /// Keys typed on the desk go one after another, in the order pressed.
    private var deskTyping: Task<Void, Never>?
    /// The level (0-1) a desk-typed hold-for-0% puts back when let go.
    private var flashRestore: Double?
    /// The level last typed on the desk for a selection, for quick nudges in a
    /// row (the sACN reading takes a moment to catch up) and for when there's
    /// no live reading at all.
    private var typedLevel: (level: Double, at: Date, fixtures: [Int])?

    /// The selected fixtures' level now: what was just typed, else the live
    /// reading (sACN, with the patch from Titan over CITP or a report), else
    /// whatever the deck last typed for this same selection.
    private var currentLevel: Double? {
        let typed: (level: Double, at: Date, fixtures: [Int])? =
            typedLevel.flatMap { Set($0.fixtures) == Set(deck.selectedFixtures) ? $0 : nil }
        if let typed, Date().timeIntervalSince(typed.at) < 2 { return typed.level }
        return deck.liveLevel ?? typed?.level
    }

    private func rememberTyped(_ level: Double, fixtures: [Int]? = nil) {
        typedLevel = (level, Date(), fixtures ?? deck.selectedFixtures)
        showTypedLevel()
    }

    /// The flash key shows the level last typed for this selection when
    /// there's no live reading.
    private func showTypedLevel() {
        deck.typedLevel = typedLevel.flatMap { Set($0.fixtures) == Set(deck.selectedFixtures) ? $0.level : nil }
    }

    func fire(_ action: TitanAction, fromKey keyIndex: Int? = nil) {
        let typing = keypad.readout.current?.text
        let keypadLine = keypad.press(action)
        intensity.deckWillSend(action)
        if keypadTypesOnDesk, action == .keypadEnter, let typing, let level = DeskKeys.typedLevel(typing) {
            // "101 @ 50" is about 101 (the deck selects it after this key); "@ 50" the selection now.
            rememberTyped(level / 100, fixtures: DeskKeys.typedFixtures(typing) ?? deck.selectedFixtures)
        }
        if keypadTypesOnDesk, action == .keypadClear {
            // Exit backs out anything typed on the desk, then the WebAPI clears the selection (only).
            queueOnDesk(action, keys: typing == nil ? [] : ["exit"], keypadLine: keypadLine, keyIndex: keyIndex)
            return
        }
        let needsLevel = switch action {
        case .adjustIntensity, .dimmerFlash(down: true, seconds: _): true
        default: false
        }
        if keypadTypesOnDesk, needsLevel, !deck.selectedFixtures.isEmpty, currentLevel == nil {
            // The WebAPI's own programmer isn't the desk's: nudging or flashing
            // there did nothing you could see, or gave odd levels.
            finish(TitanResult(action: action, ok: false, statusCode: nil, milliseconds: 0,
                               error: "TitanDeck doesn't know the level yet, so it can't nudge it or put it back after Hold for 0%: needs live levels (sACN through TitanDeck Host, with Titan's patch over CITP or a patch report), or set it once from the keypad (\"@ 50\")",
                               date: Date()),
                   keypadLine: keypadLine, keyIndex: keyIndex)
            return
        }
        if keypadTypesOnDesk, case .dimmerFlash(down: false, seconds: _) = action, flashRestore == nil,
           !deck.selectedFixtures.isEmpty {
            return   // the press was refused (level unknown): nothing to put back
        }
        if keypadTypesOnDesk, let keys = DeskKeys.names(for: action) ?? deskLevelKeys(for: action) {
            queueOnDesk(action, keys: keys, keypadLine: keypadLine, keyIndex: keyIndex)
            return
        }
        // Linked to the desk, commands act on the desk's own programmer.
        let client = deskLink.commandClient ?? titan
        Task {
            let result = await client.perform(action)
            finish(result, keypadLine: keypadLine, keyIndex: keyIndex)
        }
    }

    /// Keys typed on the desk go one after another, in the order pressed.
    private func queueOnDesk(_ action: TitanAction, keys: [String], keypadLine: UUID?, keyIndex: Int?) {
        let previous = deskTyping
        deskTyping = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let result = await self.typeOnDesk(action, keys: keys)
            self.finish(result, keypadLine: keypadLine, keyIndex: keyIndex)
        }
    }

    private func finish(_ result: TitanResult, keypadLine: UUID?, keyIndex: Int?) {
        if let keypadLine { keypad.markAnswered(keypadLine, ok: result.ok) }
        recentResults.insert(result, at: 0)
        if recentResults.count > Self.maxResults {
            recentResults.removeLast(recentResults.count - Self.maxResults)
        }
        if let keyIndex {
            deck.report(success: result.ok, forKey: keyIndex)
            if !result.ok {
                connectionLog.record(.key, .info, "Key \(keyIndex + 1) \(result.action.summary) failed: \(result.error ?? "HTTP \(result.statusCode ?? 0)")")
            }
        }
    }

    /// Intensity nudges and the hold-for-0% flash, typed on the desk as
    /// "@ level Enter" so they act on the desk's own programmer (where the
    /// typed selection is): the current level plus the nudge (+10% on 40% is
    /// 50%). Nil when the level isn't known yet: the flash then goes to the
    /// WebAPI as before; nudges are refused in `fire`. All the selected
    /// fixtures go to the same level.
    private func deskLevelKeys(for action: TitanAction) -> [String]? {
        guard !deck.selectedFixtures.isEmpty else { return nil }
        switch action {
        case .adjustIntensity(let percent):
            guard let level = currentLevel else { return nil }
            let target = DeskKeys.nudged(level * 100, by: percent)
            rememberTyped(target / 100)
            return DeskKeys.level(target)
        case .dimmerFlash(let down, _):
            if down {
                guard let level = currentLevel else { return nil }
                flashRestore = level
                rememberTyped(0)
                return DeskKeys.level(0)
            }
            guard let level = flashRestore else { return nil }
            flashRestore = nil
            rememberTyped(level)
            return DeskKeys.level(level * 100)
        default:
            return nil
        }
    }

    /// Types a keypad key on the Titan PC: through TitanDeck Host if it can,
    /// else through the remote desktop if it's connected, else as before
    /// (the WebAPI's own command line). Clear also clears the deck's own
    /// WebAPI programmer, where the intensity keys' changes are.
    private func typeOnDesk(_ action: TitanAction, keys: [String]) async -> TitanResult {
        let start = Date()
        if action == .keypadClear {
            if !keys.isEmpty { _ = await typeKeys(keys) }
            return await titan.clearSelection()
        }
        let (typed, why) = await typeKeys(keys)
        guard typed else {
            if let why { Log.titan("Keypad not typed on the desk (\(why)); using the WebAPI") }
            return await titan.perform(action)
        }
        return TitanResult(action: action, ok: true, statusCode: nil,
                          milliseconds: Int((Date().timeIntervalSince(start) * 1000).rounded()), error: nil, date: start)
    }

    /// Types keys on the PC through the Host, else the remote desktop.
    private func typeKeys(_ keys: [String]) async -> (typed: Bool, why: String?) {
        var typed = false
        var why: String?
        if let client = host.client {
            do {
                try await client.typeOnDesk(keys)
                typed = true
            } catch {
                why = error.localizedDescription
            }
        }
        if !typed, rdp.state == .connected {
            for name in keys {
                for stroke in DeskKeys.strokes(for: name) { rdp.send(stroke) }
            }
            typed = true
        }
        return (typed, why)
    }

    func checkConnection() {
        isCheckingConnection = true
        Task {
            titanVersion = await titan.softwareVersion()
            isCheckingConnection = false
        }
    }

    // MARK: - Connection log

    /// Feeds the soak-test log from every link's published state.
    private func startConnectionLog() {
        guard logSubscriptions.isEmpty else { return }
        let log = connectionLog
        log.record(.app, .info, "TitanDeck started")

        heartbeat.$health
            .removeDuplicates()
            .sink { health in
                switch health {
                case .ok(let ms), .slow(let ms): log.record(.titan, .up, "Answering (\(ms) ms)")
                case .down: log.record(.titan, .down, "No reply")
                case .unknown: break
                }
            }
            .store(in: &logSubscriptions)

        rdp.$state
            .removeDuplicates()
            .sink { [weak self] state in
                let host = self?.rdp.host ?? ""
                switch state {
                case .connected: log.record(.rdp, .up, "Connected to \(host)")
                case .failed(let message): log.record(.rdp, .down, message)
                case .idle: log.record(.rdp, .info, "Disconnected")
                case .connecting: break
                }
            }
            .store(in: &logSubscriptions)

        network.$interface
            .removeDuplicates()
            .dropFirst()   // the starting value isn't news
            .sink { interface in
                if interface == .none {
                    log.record(.network, .down, interface.rawValue)
                } else {
                    log.record(.network, .up, interface.rawValue)
                }
            }
            .store(in: &logSubscriptions)

        deck.$device
            .map { $0?.info.productName }
            .removeDuplicates()
            .dropFirst()
            .sink { name in
                if let name {
                    log.record(.deck, .up, "\(name) attached")
                } else {
                    log.record(.deck, .down, "Detached")
                }
            }
            .store(in: &logSubscriptions)
    }

    // MARK: - Remote desktop

    /// Where the file drop looks for the PC: the remote desktop address, or
    /// the Titan address when that's blank.
    var pcHost: String { rdpSettings.effectiveHost(titanHost: titanHost) }

    /// Files shared to TitanDeck from another app ("Open in TitanDeck").
    func receiveSharedFile(_ url: URL) {
        fileDrop.add([url])
        showingFileDrop = true
    }

    var isRemoteConfigured: Bool {
        rdpSettings.isComplete(titanHost: titanHost)
    }

    var remotePassword: String {
        get { Keychain.password(for: rdpSettings.keychainAccount) ?? "" }
        set {
            Keychain.setPassword(newValue, for: rdpSettings.keychainAccount)
            objectWillChange.send()
        }
    }

    func connectRemote() {
        guard isRemoteConfigured else { return }
        rdp.connect(host: rdpSettings.effectiveHost(titanHost: titanHost),
                    port: rdpSettings.port,
                    username: rdpSettings.username.trimmingCharacters(in: .whitespacesAndNewlines),
                    domain: rdpSettings.domain.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: remotePassword,
                    viewSize: remoteViewSize,
                    connectionType: rdpSettings.quality.visuals.connectionType)
    }

    /// Changes the picture quality: saves it, sets the PC half through
    /// TitanDeck Host (if paired), and reconnects a live session so both take
    /// effect. Returns a line for the screen.
    @discardableResult
    func applyRemoteQuality(_ quality: RDPQuality) async -> String {
        rdpSettings.quality = quality
        var notes: [String] = []
        if let client = host.client {
            do {
                let applied = try await client.setRdpQuality(quality.hostRequest)
                host.updatePCQuality(applied)
            } catch HostError.server(404, _) {
                notes.append("The PC's Host is too old for picture settings - update TitanDeck Host to 0.2.")
            } catch {
                notes.append("Couldn't set the PC: \(error.localizedDescription)")
            }
        } else {
            notes.append("Pair TitanDeck Host to change the PC's half too.")
        }
        if rdp.state == .connected || rdp.state == .connecting {
            rdp.disconnect()
            for _ in 0 ..< 50 where rdp.state == .connected || rdp.state == .connecting {
                try? await Task.sleep(for: .milliseconds(100))
            }
            connectRemote()
            notes.insert("Reconnecting with \(quality.preset?.title ?? "custom") settings.", at: 0)
        } else {
            notes.insert("Saved. Used from the next connection.", at: 0)
        }
        Log.titan("RDP quality: \(quality.summary)")
        return notes.joined(separator: " ")
    }

    /// Connects once at launch, if Settings -> "Connect when TitanDeck opens"
    /// is on (it's off by default).
    func autoConnectRemote() {
        guard !didAutoConnect, rdpSettings.connectOnLaunch, isRemoteConfigured, rdp.state == .idle else { return }
        didAutoConnect = true
        connectRemote()
    }

    func forgetRemoteCertificates() {
        CertificateTrustStore().forgetAll()
    }

    // MARK: - Profiles

    /// Fixture ranges whose deck flash fades (Settings > Deck > Flash fades).
    @Published var flashFadeRules: [FlashFadeRule] = DeckCues.decodeRules(
        UserDefaults.standard.data(forKey: DeckCues.fadeRulesKey)) {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(flashFadeRules), forKey: DeckCues.fadeRulesKey)
            deck.flashFadeRules = flashFadeRules
        }
    }

    /// What a held deck key turns (Settings > Deck > Held key colour).
    @Published var heldKeyColour: String = UserDefaults.standard.string(forKey: AppState.heldColourKey)
        ?? DeckRenderer.defaultHeldHex {
        didSet {
            UserDefaults.standard.set(heldKeyColour, forKey: Self.heldColourKey)
            deck.heldColorHex = heldKeyColour
        }
    }
    static let heldColourKey = "deck.heldColour"

    /// Titan's playback handles as the deck's Connect Cue choices.
    static func cueChoices(_ handles: [PlaybackHandleState]) -> [CueChoice] {
        handles.compactMap { handle in
            guard let id = handle.titanId else { return nil }
            return CueChoice(titanId: id, userNumber: handle.userNumber, page: handle.page ?? 0,
                             index: handle.index ?? 0, legend: handle.legend, isActive: handle.active)
        }
    }

    /// Saves an edited profile and pushes it to the deck.
    func updateProfile(_ profile: DeckProfile) {
        deck.replaceProfile(profile)
        save(profile)
    }

    func resetProfileToDefault() {
        let keyCount = deck.device?.capabilities.keyCount ?? 15
        let profile = DeckProfile.makeDefault(keyCount: keyCount, orientation: deck.profile.orientation)
        deck.replaceProfile(profile)
        save(profile)
    }

    /// Replaces the deck profile with an imported one.
    func importProfile(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let profile = try ProfileCoding.decode(Data(contentsOf: url))
        updateProfile(profile)
    }

    private func save(_ profile: DeckProfile) {
        do {
            try store.save(profile)
        } catch {
            Log.deck("Could not save profile: \(error)")
        }
    }
}
