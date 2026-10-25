// Host/HostClient.swift
import CryptoKit
import Foundation

/// Talks to TitanDeck Host on the PC (port 4431). A value type: make a new
/// one when the address or token changes.
struct HostClient: Sendable {
    let address: String
    var token: String?

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    // MARK: - Pairing

    /// Who's there. Works without a token; `paired` says whether ours is still good.
    func hello(timeout: TimeInterval = 3) async throws -> HostHello {
        var request = try request("hello")
        request.timeoutInterval = timeout
        let hello: HostHello = try await send(request)
        if hello.apiVersion > HostProtocol.apiVersion { throw HostError.incompatible(hello.apiVersion) }
        return hello
    }

    func pair(code: String, deviceName: String) async throws -> HostPairResponse {
        var request = try request("pair", method: "POST")
        request.httpBody = try HostAPI.encoder.encode(HostPairRequest(code: code, deviceName: deviceName))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    // MARK: - PC health

    func status() async throws -> HostStatus {
        var request = try request("status")
        request.timeoutInterval = 20   // the Host asks Windows a lot of questions
        return try await send(request)
    }

    func fix(_ action: String) async throws -> HostFixResult {
        var request = try request("fix", method: "POST")
        request.timeoutInterval = 120   // restarting Remote Desktop takes a while
        request.httpBody = try HostAPI.encoder.encode(HostFixRequest(action: action))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            return try await send(request)
        } catch HostError.refused(let message) {
            return HostFixResult(success: false, message: message)
        }
    }

    /// Hands the PC an rdpwrap.ini (fetched by the iPad, for a PC without internet).
    func uploadRdpWrapIni(_ text: String) async throws -> HostIniResult {
        var request = try request("rdpwrap/ini", method: "POST")
        request.httpBody = Data(text.utf8)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    // MARK: - Remote desktop picture (Host 0.2+)

    func rdpQuality() async throws -> HostRdpQuality {
        try await send(request("rdp/quality"))
    }

    func setRdpQuality(_ quality: HostRdpQualityRequest) async throws -> HostRdpQuality {
        var request = try request("rdp/quality", method: "POST")
        request.httpBody = try HostAPI.encoder.encode(quality)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    /// Hands the PC the official RDP Wrapper zip. It checks it before keeping it.
    func sendRdpWrapperPackage(_ zip: Data) async throws {
        var request = try request("rdpwrap/package", method: "POST")
        request.timeoutInterval = 60
        request.httpBody = zip
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await transport { try await Self.session.data(for: request) }
        try check(response, body: data)
    }

    // MARK: - Live levels from sACN (Host 0.3+)

    /// The sACN universes the Host hears.
    func dmxSummary() async throws -> HostDmxSummary {
        var request = try request("dmx")
        request.timeoutInterval = 2
        return try await send(request)
    }

    /// The show's patch from Titan's patch report (Host 0.6+).
    func patch() async throws -> HostPatch {
        var request = try request("patch")
        request.timeoutInterval = 5
        return try await send(request)
    }

    /// Levels (0-255) of one universe from `start` (1-based).
    func dmx(universe: Int, start: Int = 1, count: Int = 512) async throws -> HostDmxLevels {
        var request = try request("dmx/\(universe)", query: [URLQueryItem(name: "start", value: "\(start)"),
                                                               URLQueryItem(name: "count", value: "\(count)")])
        request.timeoutInterval = 1
        return try await send(request)
    }

    // MARK: - Files

    /// Uploads a file into the PC's To PC folder. Returns the name it was saved as.
    func upload(_ file: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> HostUploadResult {
        var request = try request("files", method: "POST",
                                  query: [URLQueryItem(name: "name", value: file.lastPathComponent)])
        request.timeoutInterval = 60   // between packets, not for the whole file
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let watcher = ProgressWatcher(progress)
        let (data, response) = try await transport {
            try await Self.session.upload(for: request, fromFile: file, delegate: watcher)
        }
        progress(1)
        return try decode(data, response)
    }

    /// Files waiting in the PC's To iPad folder.
    func outbox() async throws -> [HostFileEntry] {
        try await send(request("outbox"))
    }

    /// Downloads one To iPad file to a temporary location.
    func download(_ entry: HostFileEntry, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        var request = try request("outbox/" + Self.pathComponent(entry.name))
        request.timeoutInterval = 60
        let watcher = ProgressWatcher(progress)
        let (temporary, response) = try await transport {
            try await Self.session.download(for: request, delegate: watcher)
        }
        try check(response, body: (try? Data(contentsOf: temporary)) ?? Data())
        progress(1)
        return temporary
    }

    /// Tells the PC a file arrived, so it moves into To iPad\Sent.
    func markReceived(_ entry: HostFileEntry) async throws {
        let request = try request("outbox/" + Self.pathComponent(entry.name) + "/received", method: "POST")
        let (data, response) = try await transport { try await Self.session.data(for: request) }
        try check(response, body: data)
    }

    // MARK: - Plumbing

    private func request(_ path: String, method: String = "GET", query: [URLQueryItem] = []) throws -> URLRequest {
        guard let url = HostAPI.url(host: address, path: path, query: query) else { throw HostError.noAddress }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await transport { try await Self.session.data(for: request) }
        return try decode(data, response)
    }

    private func decode<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        try check(response, body: data)
        do {
            return try HostAPI.decoder.decode(T.self, from: data)
        } catch {
            throw HostError.server(0, "The Host's answer didn't make sense (\(error.localizedDescription)).")
        }
    }

    private func check(_ response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw HostError.server(0, nil) }
        guard (200 ..< 300).contains(http.statusCode) else { throw HostError.from(status: http.statusCode, body: body) }
    }

    /// Network failures become `.unreachable` with a short reason.
    private func transport<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw HostError.unreachable("It didn't answer in time.")
            case .cannotConnectToHost: throw HostError.unreachable("Is the Host installed and the PC on?")
            case .cannotFindHost, .dnsLookupFailed: throw HostError.unreachable("Check the PC address.")
            case .notConnectedToInternet, .networkConnectionLost:
                throw HostError.unreachable("Check the iPad is on the show network.")
            default: throw HostError.unreachable(error.localizedDescription)
            }
        }
    }

    private static func pathComponent(_ name: String) -> String {
        name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))) ?? name
    }
}

/// Reports a transfer's progress from the task URLSession creates for an
/// async upload or download.
private final class ProgressWatcher: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let report: @Sendable (Double) -> Void
    private var observation: NSKeyValueObservation?

    init(_ report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [report] progress, _ in
            report(min(1, max(0, progress.fractionCompleted)))
        }
    }

    deinit { observation?.invalidate() }
}

extension HostAPI {
    /// Lowercase hex SHA-256, for checking downloads against a pinned hash.
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
