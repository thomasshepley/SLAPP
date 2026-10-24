// UniFi/UniFiStore.swift
import Foundation

/// The show network as UniFi sees it: access points and their radios,
/// clients (including this iPad), neighbouring networks, and RF scans.
/// Login is a local UniFi admin; the password lives in the Keychain.
@MainActor
final class UniFiStore: ObservableObject {
    enum Status: Equatable {
        case notSetUp
        case connecting
        case connected(Date)
        case failed(String)
    }

    @Published var address: String { didSet { save() } }
    @Published var username: String { didSet { save() } }
    @Published var site: String { didSet { save() } }
    @Published private(set) var status: Status
    @Published private(set) var accessPoints: [UniFiDevice] = []
    @Published private(set) var stations: [UniFiStation] = []
    @Published private(set) var neighbours: [UniFiNeighbour] = []
    @Published private(set) var health: [UniFiHealth] = []
    /// RF scan results by AP MAC.
    @Published private(set) var scans: [String: UniFiSpectrumScan] = [:]
    /// APs with an RF scan running.
    @Published private(set) var scanning: Set<String> = []
    @Published var lastMessage: String?

    private let defaults: UserDefaults
    private var connection: UniFiConnection?
    private var isRefreshing = false

    private static let addressKey = "unifi.address"
    private static let usernameKey = "unifi.username"
    private static let siteKey = "unifi.site"
    private static let passwordAccount = "unifi-password"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        address = defaults.string(forKey: Self.addressKey) ?? ""
        username = defaults.string(forKey: Self.usernameKey) ?? ""
        site = defaults.string(forKey: Self.siteKey) ?? "default"
        status = .notSetUp
        if isConfigured { status = .connecting }
    }

    var password: String {
        get { Keychain.password(for: Self.passwordAccount) ?? "" }
        set {
            Keychain.setPassword(newValue, for: Self.passwordAccount)
            connection = nil
            objectWillChange.send()
        }
    }

    var isConfigured: Bool { !address.trimmingCharacters(in: .whitespaces).isEmpty && !username.isEmpty && !password.isEmpty }

    private func save() {
        defaults.set(address, forKey: Self.addressKey)
        defaults.set(username, forKey: Self.usernameKey)
        defaults.set(site, forKey: Self.siteKey)
        connection = nil
    }

    // MARK: - Refresh

    func refresh() async {
        guard isConfigured else {
            status = .notSetUp
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if case .connected = status {} else { status = .connecting }
        do {
            let connection = try currentConnection()
            async let devices = connection.list("stat/device", as: UniFiDevice.self)
            async let clients = connection.list("stat/sta", as: UniFiStation.self)
            async let siteHealth = connection.list("stat/health", as: UniFiHealth.self)
            accessPoints = try await devices.filter(\.isAccessPoint).sorted { $0.displayName < $1.displayName }
            stations = try await clients.filter { $0.isWired != true }
            health = (try? await siteHealth) ?? []
            // Neighbours are a nice-to-have; older controllers answer this differently.
            neighbours = (try? await connection.list("stat/rogueap", as: UniFiNeighbour.self)) ?? neighbours
            scanning = Set(accessPoints.filter { $0.spectrumScanning == true }.map(\.mac))
            status = .connected(Date())
        } catch is CancellationError {
            return
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func keepRefreshing(every interval: Duration = .seconds(10)) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }

    /// Tries the login straight away, for the setup screen.
    func test() async {
        connection = nil
        await refresh()
    }

    func forgetCertificate() {
        CertificateTrustStore(key: UniFiConnection.trustKey).forgetAll()
        connection = nil
        lastMessage = "Forgot the console's certificate. The next connection trusts whatever it sends."
    }

    private func currentConnection() throws -> UniFiConnection {
        let credentials = UniFiConnection.Credentials(address: address, username: username, password: password,
                                                      site: site.isEmpty ? "default" : site)
        if let connection, connection.credentials == credentials { return connection }
        let fresh = try UniFiConnection(credentials: credentials)
        connection = fresh
        return fresh
    }

    // MARK: - This iPad

    /// This device's own client entry, matched by its Wi-Fi IP address.
    var thisDevice: UniFiStation? {
        guard let ip = InterfaceAddress.ipv4(interface: "en0")?.address else { return nil }
        return stations.first { $0.ip == ip }
    }

    func accessPoint(mac: String?) -> UniFiDevice? {
        guard let mac = mac?.lowercased() else { return nil }
        return accessPoints.first { $0.mac.lowercased() == mac }
    }

    func clients(on ap: UniFiDevice) -> [UniFiStation] {
        stations.filter { $0.apMac?.lowercased() == ap.mac.lowercased() }
    }

    /// Wi-Fi clients with a poor signal, worst first.
    var weakClients: [UniFiStation] {
        stations.filter { ($0.signal ?? 0) < -75 && $0.signal != nil }.sorted { ($0.signal ?? 0) < ($1.signal ?? 0) }
    }

    func neighbours(in band: WiFiBand) -> [UniFiNeighbour] {
        // The same network heard by several of our APs: keep the strongest.
        var best: [String: UniFiNeighbour] = [:]
        for neighbour in neighbours where neighbour.wifiBand == band {
            if let existing = best[neighbour.bssid], (existing.dBm ?? -100) >= (neighbour.dBm ?? -100) { continue }
            best[neighbour.bssid] = neighbour
        }
        return best.values.sorted { ($0.dBm ?? -100) > ($1.dBm ?? -100) }
    }

    var ourRadios: [UniFiDevice.RadioSummary] { accessPoints.flatMap(\.radios) }

    // MARK: - RF scan

    /// Starts an AP's RF environment scan. Its radios go off air for a few
    /// minutes, dropping its clients - the caller confirms first.
    func startRFScan(_ ap: UniFiDevice) async {
        guard let connection = try? currentConnection() else { return }
        do {
            try await connection.command("cmd/devmgr", ["cmd": "spectrum-scan", "mac": ap.mac])
            scanning.insert(ap.mac)
            lastMessage = "\(ap.displayName) is scanning. Its clients will drop off for a few minutes."
            Log.titan("UniFi: RF scan started on \(ap.displayName)")
            Task { await waitForScan(ap.mac) }
        } catch {
            lastMessage = "Couldn't start the scan: \(error.localizedDescription)"
        }
    }

    /// Loads the last RF scan an AP has (scans from the UniFi app count too).
    func loadScan(_ mac: String) async {
        guard let connection = try? currentConnection(),
              let result = try? await connection.list("stat/spectrum-scan/\(mac)", as: UniFiSpectrumScan.self).first else { return }
        scans[mac] = result
        if result.spectrumScanning == true { scanning.insert(mac) } else { scanning.remove(mac) }
    }

    private func waitForScan(_ mac: String) async {
        try? await Task.sleep(for: .seconds(30))   // give the AP time to report that it's scanning
        for _ in 0 ..< 40 {   // up to ~7 more minutes
            try? await Task.sleep(for: .seconds(10))
            await loadScan(mac)
            if !scanning.contains(mac) {
                lastMessage = "RF scan finished."
                return
            }
        }
        scanning.remove(mac)
    }
}
