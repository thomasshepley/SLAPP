// Host/HostStore.swift
import Foundation
import UIKit

/// The paired TitanDeck Host: who it is, whether it's answering, the PC's
/// Remote Desktop health, and files waiting to come to the iPad. The token
/// lives in the Keychain; the address and name in UserDefaults.
@MainActor
final class HostStore: ObservableObject {
    enum Connection: Equatable {
        case notPaired
        case checking
        case online(HostHello)
        case offline(String)
    }

    /// A file that came from the PC, kept in Documents/From PC.
    struct Received: Identifiable, Hashable {
        let url: URL
        let size: Int64
        let date: Date
        var id: URL { url }
        var name: String { url.lastPathComponent }
    }

    @Published private(set) var address: String
    @Published private(set) var hostName: String?
    @Published private(set) var connection: Connection
    @Published private(set) var status: HostStatus?
    @Published private(set) var outbox: [HostFileEntry] = []
    @Published private(set) var received: [Received] = []
    /// Downloads in flight, by file name, 0...1.
    @Published private(set) var downloading: [String: Double] = [:]
    /// Fix being run, by check id.
    @Published private(set) var fixing: String?
    @Published var lastMessage: String?

    private let defaults: UserDefaults
    private var token: String?
    private var lastStatusFetch: Date = .distantPast

    private static let addressKey = "host.address"
    private static let nameKey = "host.name"
    private static let deviceKey = "host.deviceId"
    private static let tokenAccount = "titandeck-host-token"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        address = defaults.string(forKey: Self.addressKey) ?? ""
        hostName = defaults.string(forKey: Self.nameKey)
        token = Keychain.password(for: Self.tokenAccount)
        connection = token == nil ? .notPaired : .checking
        loadReceived()
    }

    var isPaired: Bool { token != nil }
    var isOnline: Bool { if case .online = connection { return true } else { return false } }
    var displayName: String { hostName ?? address }

    /// A client for the paired Host, or nil if not paired.
    var client: HostClient? {
        guard let token, !address.isEmpty else { return nil }
        return HostClient(address: address, token: token)
    }

    // MARK: - Pairing

    /// Pairs with the Host at `address` using the 6-digit code from the PC's window.
    func pair(address: String, code: String) async throws {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let probe = HostClient(address: address, token: nil)
        _ = try await probe.hello()
        let response = try await probe.pair(code: HostAPI.normaliseCode(code), deviceName: UIDevice.current.name)
        guard Keychain.setPassword(response.token, for: Self.tokenAccount) else {
            throw HostError.refused("Paired, but the token couldn't be saved in the Keychain.")
        }
        token = response.token
        self.address = address
        hostName = response.hostName
        defaults.set(address, forKey: Self.addressKey)
        defaults.set(response.hostName, forKey: Self.nameKey)
        defaults.set(response.deviceId, forKey: Self.deviceKey)
        Log.titan("Host: paired with \(response.hostName) at \(address)")
        lastStatusFetch = .distantPast
        await refresh()
    }

    /// Forgets the pairing on this device. (The PC's window can remove it too.)
    func forget() {
        Keychain.setPassword(nil, for: Self.tokenAccount)
        token = nil
        hostName = nil
        defaults.removeObject(forKey: Self.nameKey)
        defaults.removeObject(forKey: Self.deviceKey)
        connection = .notPaired
        status = nil
        outbox = []
    }

    // MARK: - Keeping up to date

    /// Hello plus the To iPad list; the full health check at most every 20 s
    /// (or now, with `full`), since it makes the PC do some work.
    func refresh(full: Bool = false) async {
        guard let client else {
            connection = .notPaired
            return
        }
        if !isOnline { connection = .checking }
        do {
            let hello = try await client.hello()
            guard hello.paired else {
                Log.titan("Host: the PC no longer knows this device")
                forget()
                lastMessage = HostError.notPaired.localizedDescription
                return
            }
            connection = .online(hello)
            if hello.machineName != hostName {
                hostName = hello.machineName
                defaults.set(hello.machineName, forKey: Self.nameKey)
            }
            outbox = try await client.outbox()
            if full || Date().timeIntervalSince(lastStatusFetch) > 20 {
                status = try await client.status()
                lastStatusFetch = Date()
            }
        } catch is CancellationError {
            return
        } catch HostError.notPaired {
            forget()
            lastMessage = HostError.notPaired.localizedDescription
        } catch {
            connection = .offline(error.localizedDescription)
        }
    }

    /// Keeps refreshing while the calling view is on screen.
    func keepRefreshing(every interval: Duration = .seconds(4)) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }

    // MARK: - Fixes

    func fix(_ check: HostCheck) async {
        guard let client, let action = check.fix, fixing == nil else { return }
        fixing = check.id
        defer { fixing = nil }
        do {
            let result = try await client.fix(action)
            lastMessage = result.success ? result.message : "Didn't work: \(result.message)"
        } catch {
            lastMessage = error.localizedDescription
        }
        lastStatusFetch = .distantPast
        await refresh(full: true)
    }

    /// Fetches the newest rdpwrap.ini over the iPad's internet and gives it
    /// to the PC - for a Titan PC that's kept offline.
    func sendNewestRdpWrapIni() async {
        guard let client, fixing == nil else { return }
        fixing = "rdpwrap-ini"
        defer { fixing = nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: HostProtocol.rdpWrapIniURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let text = String(data: data, encoding: .utf8) else {
                lastMessage = "Couldn't download rdpwrap.ini. Is the iPad online?"
                return
            }
            let result = try await client.uploadRdpWrapIni(text)
            if result.supportsThisPc {
                let fix = try await client.fix("UpdateRdpWrapIni")
                lastMessage = fix.success ? fix.message : "Sent, but applying it didn't work: \(fix.message)"
            } else {
                lastMessage = "Sent the newest rdpwrap.ini (\(result.updated ?? "undated")), but it doesn't cover this PC's build \(result.build) yet. Check again in a few days."
            }
        } catch {
            lastMessage = error.localizedDescription
        }
        lastStatusFetch = .distantPast
        await refresh(full: true)
    }

    // MARK: - Files from the PC

    static var receivedFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("From PC", isDirectory: true)
    }

    func download(_ entry: HostFileEntry) async {
        guard let client, downloading[entry.name] == nil else { return }
        downloading[entry.name] = 0
        defer { downloading[entry.name] = nil }
        do {
            let temporary = try await client.download(entry) { fraction in
                Task { @MainActor [weak self] in
                    if self?.downloading[entry.name] != nil { self?.downloading[entry.name] = fraction }
                }
            }
            let folder = Self.receivedFolder
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = FileDropCopier.uniqueName(entry.name) {
                FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
            }
            try FileManager.default.moveItem(at: temporary, to: folder.appendingPathComponent(name))
            try await client.markReceived(entry)
            outbox.removeAll { $0.name == entry.name }
            loadReceived()
            Log.titan("Host: received \(entry.name)")
        } catch {
            lastMessage = "Couldn't get \(entry.name): \(error.localizedDescription)"
        }
    }

    func downloadAll() async {
        for entry in outbox { await download(entry) }
    }

    func deleteReceived(_ file: Received) {
        try? FileManager.default.removeItem(at: file.url)
        loadReceived()
    }

    private func loadReceived() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: Self.receivedFolder, includingPropertiesForKeys: keys,
                                                                  options: .skipsHiddenFiles)) ?? []
        received = urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return Received(url: url, size: Int64(values?.fileSize ?? 0), date: values?.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.date > $1.date }
    }
}
