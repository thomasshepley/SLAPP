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
    }

    func start() {
        if showingStartup { deck.startSplash() }
        startConnectionLog()
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
            self?.intensity.setFixture(fixtures.first)
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
    func fire(_ action: TitanAction, fromKey keyIndex: Int? = nil) {
        let keypadLine = keypad.press(action)
        intensity.deckWillSend(action)
        // Linked to the desk, commands act on the desk's own programmer.
        let client = deskLink.commandClient ?? titan
        Task {
            let result = await client.perform(action)
            if let keypadLine { keypad.markAnswered(keypadLine, ok: result.ok) }
            recentResults.insert(result, at: 0)
            if recentResults.count > Self.maxResults {
                recentResults.removeLast(recentResults.count - Self.maxResults)
            }
            if let keyIndex {
                deck.report(success: result.ok, forKey: keyIndex)
                if !result.ok {
                    connectionLog.record(.key, .info, "Key \(keyIndex + 1) \(action.summary) failed: \(result.error ?? "HTTP \(result.statusCode ?? 0)")")
                }
            }
        }
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
