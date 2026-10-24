// App/DeskLink.swift
import Foundation

/// The desk link: Titan's UI WebAPI, which shares the operator's selection
/// and programmer (Titan's normal WebAPI on 4430 is a separate user and sees
/// neither). TitanDeck Host turns it on (Titan port 4433) and passes it on
/// to the iPad on 4434. While it answers, TitanDeck follows what's selected
/// in Layouts or on the desk, and sends the deck's commands there so they
/// act on the desk's own programmer. If it stops answering, everything goes
/// back to 4430 by itself. Off in Settings turns all of it off.
@MainActor
final class DeskLink: ObservableObject {
    enum State: Equatable {
        case off
        case connecting
        case linked
        case unavailable(String)
    }

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            restart()
        }
    }
    @Published var port: Int {
        didSet {
            defaults.set(port, forKey: Keys.port)
            restart()
        }
    }
    @Published private(set) var state: State = .off
    /// The desk's selection, as fixture user numbers.
    @Published private(set) var selection: [Int] = []

    /// Called when the desk's selection changes (and once when it's dropped).
    var onSelection: (([Int]) -> Void)?
    /// Called when the link comes up or goes down.
    var onLinkChange: ((Bool) -> Void)?

    static let defaultPort = 4434
    /// About three times a second: quick enough to feel live, light on Titan's UI.
    static let pollInterval: UInt64 = 330_000_000

    private enum Keys {
        static let enabled = "desk.link.enabled"
        static let port = "desk.link.port"
    }

    private let defaults: UserDefaults
    private let api: TitanClient
    private var host = ""
    private(set) var client: TitanClient?
    private var poll: Task<Void, Never>?
    private var userNumbers: [Int: Int] = [:]
    private var lastMapRefresh = Date.distantPast
    private var failures = 0

    /// `api` is the normal WebAPI (4430), used for the fixture list.
    init(api: TitanClient, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        port = defaults.object(forKey: Keys.port) as? Int ?? Self.defaultPort
    }

    var isLinked: Bool { state == .linked }

    /// Where deck commands should go: the desk while linked, else nil (4430).
    var commandClient: TitanClient? { isLinked ? client : nil }

    func setHost(_ newHost: String) {
        let clean = newHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean != host else { return }
        host = clean
        restart()
    }

    private func restart() {
        poll?.cancel()
        poll = nil
        userNumbers = [:]
        lastMapRefresh = .distantPast
        failures = 0
        setLinked(false, reason: isEnabled ? nil : "")
        if !selection.isEmpty {
            selection = []
            onSelection?([])
        }
        guard isEnabled, !host.isEmpty else {
            client = nil
            state = isEnabled ? .unavailable("No Titan address set.") : .off
            return
        }
        // A little longer than the deck's own 0.5 s: there's an extra hop through the Host.
        let client = TitanClient(host: host, port: port, timeout: 1.0)
        self.client = client
        state = .connecting
        poll = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick(client)
                try? await Task.sleep(nanoseconds: Self.pollInterval)
            }
        }
    }

    private func tick(_ client: TitanClient) async {
        guard let ids = await client.selectedFixtureIds() else {
            failures += 1
            // A blip doesn't drop the link; three misses in a row does.
            if failures >= 3 {
                setLinked(false, reason: "Titan's UI WebAPI isn't answering on port \(port). Turn it on in TitanDeck Host on the PC (Desk selection for TitanDeck), then restart Titan.")
                if !selection.isEmpty {
                    selection = []
                    onSelection?([])
                }
            }
            return
        }
        failures = 0
        setLinked(true, reason: nil)
        if ids.contains(where: { userNumbers[$0] == nil }), Date().timeIntervalSince(lastMapRefresh) > 5 {
            lastMapRefresh = Date()
            var map = await api.fixtureUserNumbers()
            if map == nil { map = await client.fixtureUserNumbers() }
            if let map { userNumbers = map }
        }
        let fixtures = ids.compactMap { userNumbers[$0] }
        guard fixtures != selection else { return }
        selection = fixtures
        onSelection?(fixtures)
    }

    private func setLinked(_ linked: Bool, reason: String?) {
        let was = isLinked
        if linked {
            state = .linked
        } else if let reason {
            state = reason.isEmpty ? .off : .unavailable(reason)
        }
        if was != isLinked { onLinkChange?(isLinked) }
    }
}
