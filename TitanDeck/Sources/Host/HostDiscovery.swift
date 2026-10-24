// Host/HostDiscovery.swift
import Foundation
import Network

/// Finds TitanDeck Host on the show network over Bonjour, so pairing doesn't
/// need an IP address typing in. Only runs while the pairing screen is open.
@MainActor
final class HostDiscovery: ObservableObject {
    struct Found: Identifiable, Hashable {
        let name: String
        let version: String?
        let endpoint: NWEndpoint
        var id: String { name }
    }

    @Published private(set) var found: [Found] = []
    @Published private(set) var isSearching = false

    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: HostProtocol.serviceType, domain: nil),
                                using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let found = results.compactMap(Self.found(from:)).sorted { $0.name < $1.name }
            Task { @MainActor in self?.found = found }
        }
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready: self?.isSearching = true
                case .failed, .cancelled: self?.isSearching = false
                default: break
                }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private nonisolated static func found(from result: NWBrowser.Result) -> Found? {
        guard case .service(let name, _, _, _) = result.endpoint else { return nil }
        var version: String?
        if case .bonjour(let txt) = result.metadata { version = txt["version"] }
        return Found(name: name, version: version, endpoint: result.endpoint)
    }

    /// Turns a Bonjour service into an IPv4 address the HTTP client can use,
    /// by connecting to it once and asking where we ended up.
    nonisolated static func resolve(_ endpoint: NWEndpoint, timeout: TimeInterval = 4) async -> String? {
        await withCheckedContinuation { continuation in
            let parameters = NWParameters.tcp
            if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                ip.version = .v4
            }
            let connection = NWConnection(to: endpoint, using: parameters)
            let queue = DispatchQueue(label: "TitanDeck.HostDiscovery.resolve")
            var finished = false
            func finish(_ address: String?) {
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: address)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case .hostPort(let host, let port) = connection.currentPath?.remoteEndpoint {
                        let name = Self.text(for: host)
                        finish(port.rawValue == UInt16(HostProtocol.port) ? name : "\(name):\(port.rawValue)")
                    } else {
                        finish(nil)
                    }
                case .failed, .cancelled: finish(nil)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    private nonisolated static func text(for host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let address):
            return "\(address)"
        case .ipv6(let address):
            let plain = "\(address)".split(separator: "%").first.map(String.init) ?? ""   // drop the %en0 scope
            return "[\(plain)]"
        case .name(let name, _):
            return name
        @unknown default:
            return "\(host)"
        }
    }
}
