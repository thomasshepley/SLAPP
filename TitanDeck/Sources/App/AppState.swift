// App/AppState.swift
import SwiftUI
import UIKit

/// The one object that knows about all three layers. Deck, Titan and Remote
/// never talk to each other directly - everything is wired up here.
@MainActor
final class AppState: ObservableObject {
    enum Mode: Hashable {
        case remote
        case settings
    }

    @Published var mode: Mode = .remote
    @Published var titanHost: String {
        didSet {
            let host = titanHost
            UserDefaults.standard.set(host, forKey: Self.hostKey)
            Task { await titan.setHost(host) }
        }
    }
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
    private let store: ProfileStore

    private static let hostKey = "titanHost"
    private static let maxResults = 25

    init() {
        let host = UserDefaults.standard.string(forKey: Self.hostKey) ?? ""
        titanHost = host
        rdpSettings = RDPSettings.load()
        rdp = RDPSession()
        heartbeat = TitanHeartbeat()
        network = NetworkMonitor()
        localNetwork = LocalNetworkPermission()
        titan = TitanClient(host: host)
        let store = ProfileStore()
        self.store = store
        deck = DeckSessionController(profile: store.load() ?? DeckProfile.makeDefault())

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
        UIApplication.shared.isIdleTimerDisabled = true
        deck.start()
        network.start()
        localNetwork.check()
        heartbeat.start(client: titan) { [weak self] in
            !(self?.titanHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            wasBackgrounded = true
            Log.deck("App went to background - Stream Deck keys are inactive until it returns")
        case .active:
            UIApplication.shared.isIdleTimerDisabled = true
            localNetwork.check()
        default:
            break
        }
    }

    func dismissBackgroundWarning() {
        wasBackgrounded = false
    }

    // MARK: - Titan

    /// Fire an action at Titan. Pass the key index when it came from the deck
    /// so a failure can flash that key red.
    func fire(_ action: TitanAction, fromKey keyIndex: Int? = nil) {
        Task {
            let result = await titan.perform(action)
            recentResults.insert(result, at: 0)
            if recentResults.count > Self.maxResults {
                recentResults.removeLast(recentResults.count - Self.maxResults)
            }
            if let keyIndex {
                deck.report(success: result.ok, forKey: keyIndex)
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

    // MARK: - Remote desktop

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
                    viewSize: remoteViewSize)
    }

    /// Connects once at launch, if set up to. The app goes straight to the
    /// Titan desktop with no taps needed.
    func autoConnectRemote() {
        guard !didAutoConnect, rdpSettings.autoConnect, isRemoteConfigured, rdp.state == .idle else { return }
        didAutoConnect = true
        connectRemote()
    }

    func forgetRemoteCertificates() {
        CertificateTrustStore().forgetAll()
    }

    // MARK: - Profiles

    /// Saves an edited profile and pushes it to the deck.
    func updateProfile(_ profile: DeckProfile) {
        deck.replaceProfile(profile)
        save(profile)
    }

    func resetProfileToDefault() {
        let keyCount = deck.device?.capabilities.keyCount ?? 32
        let profile = DeckProfile.makeDefault(keyCount: keyCount)
        deck.replaceProfile(profile)
        save(profile)
    }

    private func save(_ profile: DeckProfile) {
        do {
            try store.save(profile)
        } catch {
            Log.deck("Could not save profile: \(error)")
        }
    }
}
