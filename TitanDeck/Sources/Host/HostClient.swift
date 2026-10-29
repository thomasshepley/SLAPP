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

    /// Desk keys have connections of their own, so a key never waits for a
    /// free one behind a slow Host call (status, a cue fade, a file).
    private static let keysSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        #if os(iOS)
        configuration.networkServiceType = .responsiveData
        #endif
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

    /// The most keys the Host takes in one go.
    static let maxDeskKeys = 32

    /// Types keypad keys on the PC for Titan (Host 0.10+). Throws when the
    /// Host can't (its window isn't open, Titan isn't running, an older Host).
    func typeOnDesk(_ keys: [String]) async throws {
        var request = try request("desk/keys", method: "POST")
        request.timeoutInterval = 1.5
        request.httpBody = try HostAPI.encoder.encode(HostDeskKeysRequest(keys: keys))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await transport { try await Self.keysSession.data(for: request) }
        try check(response, body: data)
    }

    /// The desk's selection from the Host's CITP link (Host 0.9+).
    func citpSelection() async throws -> HostCitpSelection {
        var request = try request("citp/selection")
        request.timeoutInterval = 1
        return try await send(request)
    }

    // MARK: - Titan actions (Host 0.14+)

    /// Sets a cue's fade time from the Host, which tries each way it knows and
    /// checks the cue. Throws on an older Host (404), so the deck can do it itself.
    func cueFade(titanId: Int, fadeOut: Bool, seconds: Double) async throws -> HostTitanAction {
        try await actionPost("actions/cue-fade", body: HostCueFadeRequest(titanId: titanId, fadeOut: fadeOut, seconds: seconds))
    }

    /// Clears the desk's selection from the Host, checked over CITP. Short:
    /// the keys pressed after CLEAR wait for it (Host 0.15 answers within a
    /// second or so).
    func clearSelection() async throws -> HostTitanAction {
        try await actionPost("actions/clear-selection", body: Optional<HostCueFadeRequest>.none, timeout: 4)
    }

    // MARK: - Groups (Host 0.17+)

    /// A Titan group's fixture numbers (by its handle's Titan id), for the
    /// deck to type on the desk.
    func groupFixtures(titanId: Int) async throws -> HostGroupFixtures {
        var request = try request("groups/\(titanId)/fixtures")
        request.timeoutInterval = 8
        return try await send(request)
    }

    // MARK: - FX (Host 0.16+, Test mode)

    /// A Prism layer fixture's controls set (or released) by the Host.
    func fxLayer(_ request: HostFxLayerRequest) async throws -> HostTitanAction {
        try await actionPost("fx/layer", body: request, timeout: 8)
    }

    /// A layer's pixel map group changed by the Host, read back to check.
    func fxGroup(_ request: HostFxGroupRequest) async throws -> HostTitanAction {
        try await actionPost("fx/group", body: request, timeout: 12)
    }

    /// Which controls a Prism layer fixture has (its personality's names).
    func fxProbe(fixture: Int, names: [String]) async throws -> HostFxProbe {
        var request = try request("fx/probe", query: [URLQueryItem(name: "fixture", value: "\(fixture)"),
                                                     URLQueryItem(name: "names", value: names.joined(separator: ","))])
        request.timeoutInterval = 15
        return try await send(request)
    }

    /// - Parameter timeout: a cue fade's several tries are each read back from Titan, so it gets time.
    private func actionPost<Body: Encodable>(_ path: String, body: Body?, timeout: TimeInterval = 20) async throws -> HostTitanAction {
        var request = try request(path, method: "POST")
        request.timeoutInterval = timeout
        if let body {
            request.httpBody = try HostAPI.encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await send(request)
    }

    // MARK: - Slate Book (Host 0.13+)

    /// Today's Slate Book, or just the slate showing with `summary`.
    func slateBook(summary: Bool = false) async throws -> HostSlateBook {
        var request = try request("slate", query: summary ? [URLQueryItem(name: "summary", value: "true")] : [])
        request.timeoutInterval = 4
        return try await send(request)
    }

    /// A past day's Slate Book ("2026-10-27").
    func slateBook(day: String) async throws -> HostSlateBook {
        var request = try request("slate/day/\(day)")
        request.timeoutInterval = 6
        return try await send(request)
    }

    /// TAKE: the next take, with the look logged.
    func slateTake() async throws -> HostSlateEntry { try await slatePost("slate/take", body: Optional<HostSlateNewRequest>.none) }

    /// NEW SLATE: the next slate (or the one typed), take 1, the look logged.
    func slateNew(_ slate: String? = nil) async throws -> HostSlateEntry {
        try await slatePost("slate/new", body: HostSlateNewRequest(slate: slate))
    }

    /// The same setup's next letter ("112" to "112A"), take 1, the look logged.
    func slateLetter() async throws -> HostSlateEntry { try await slatePost("slate/letter", body: Optional<HostSlateNewRequest>.none) }

    /// Day or night, FX, or the slate or take put right, without logging a look.
    func slateSet(_ change: HostSlateSetRequest) async throws -> HostSlateBook { try await slatePost("slate/set", body: change) }

    func slateNote(day: String, id: Int, note: String?) async throws -> HostSlateEntry {
        try await slatePost("slate/note", body: HostSlateNoteRequest(day: day, id: id, note: note))
    }

    /// What's different on stage now from a line of the book.
    func slateMatch(day: String, id: Int) async throws -> HostSlateMatch {
        var request = try request("slate/match/\(day)/\(id)")
        request.timeoutInterval = 4
        return try await send(request)
    }

    private func slatePost<Body: Encodable, Answer: Decodable>(_ path: String, body: Body?) async throws -> Answer {
        var request = try request(path, method: "POST")
        request.timeoutInterval = 4
        if let body {
            request.httpBody = try HostAPI.encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
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
