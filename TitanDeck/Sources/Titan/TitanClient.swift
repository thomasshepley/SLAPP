// Titan/TitanClient.swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Outcome of one call to Titan, kept for the settings screen and the log.
struct TitanResult: Equatable {
    let action: TitanAction
    let ok: Bool
    let statusCode: Int?
    /// Round trip in milliseconds - the M3 latency measurement.
    let milliseconds: Int
    let error: String?
    let date: Date
}

/// Fire-and-forget GETs to the Titan WebAPI with a short timeout, so a dead
/// network never makes a key feel sticky.
actor TitanClient {
    private(set) var host: String
    let port: Int
    /// Per-request timeout in seconds (0.5 by default).
    let timeout: TimeInterval
    private let session: URLSession

    init(host: String, port: Int = TitanEndpoints.defaultPort, timeout: TimeInterval = 0.5) {
        self.host = host
        self.port = port
        self.timeout = timeout
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config)
    }

    func setHost(_ newHost: String) {
        host = newHost
    }

    func perform(_ action: TitanAction) async -> TitanResult {
        switch action {
        case .keypadEnter: return await runEnter()
        case .keypadClear: return await runClear()
        case .colourTemperature(let kelvin): return await runColourTemperature(kelvin)
        default: break
        }
        let start = Date()
        guard let url = TitanEndpoints.url(for: action, host: host, port: port) else {
            let reason = action.isRemote ? "No Titan host set" : "Local action"
            return TitanResult(action: action, ok: false, statusCode: nil, milliseconds: 0, error: reason, date: start)
        }
        let result: TitanResult
        do {
            let (_, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode
            result = TitanResult(action: action, ok: status == 200, statusCode: status,
                                 milliseconds: Self.elapsed(since: start), error: nil, date: start)
        } catch {
            result = TitanResult(action: action, ok: false, statusCode: nil,
                                 milliseconds: Self.elapsed(since: start), error: error.localizedDescription, date: start)
        }
        Log.titan("\(action.summary) -> \(result.ok ? "OK" : "FAIL") \(result.statusCode.map(String.init) ?? "-") in \(result.milliseconds) ms \(url.absoluteString)")
        return result
    }

    // MARK: - Keypad Enter / Clear (several requests)

    /// The text currently on Titan's command line, or nil if Titan didn't answer.
    func commandLineText() async -> String? {
        guard let url = TitanEndpoints.commandLineTextURL(host: host, port: port),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        if let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r"))
    }

    /// Enter: run what's on the command line, then start a fresh one.
    private func runEnter() async -> TitanResult {
        let start = Date()
        guard let text = await commandLineText() else {
            return finish(.keypadEnter, start, ok: false, status: nil, error: "Couldn't read the command line")
        }
        guard !text.isEmpty else {
            return finish(.keypadEnter, start, ok: true, status: 200, error: nil)   // nothing typed
        }
        let run = await get(TitanEndpoints.runCommandURL(text, host: host, port: port))
        _ = await get(TitanEndpoints.startNewCommandURL(host: host, port: port))
        return finish(.keypadEnter, start, ok: run.ok, status: run.status, error: run.error, detail: "ran \"\(text)\"")
    }

    /// Clear: like the console - clears what's typed first, then the programmer.
    private func runClear() async -> TitanResult {
        let start = Date()
        let text = await commandLineText()
        let url = (text?.isEmpty == false)
            ? TitanEndpoints.startNewCommandURL(host: host, port: port)
            : TitanEndpoints.clearProgrammerURL(host: host, port: port)
        let result = await get(url)
        return finish(.keypadClear, start, ok: result.ok, status: result.status, error: result.error,
                      detail: text?.isEmpty == false ? "cleared command line" : "cleared programmer")
    }

    // MARK: - Colour temperature (find the palette, then apply it)

    /// Recalls the colour palette named for this temperature ("3200K") on the
    /// selected fixtures. A global palette carries each fixture type's own CCT
    /// value, so the deck never needs to know which channel that is.
    private func runColourTemperature(_ kelvin: Int) async -> TitanResult {
        let action = TitanAction.colourTemperature(kelvin: kelvin)
        let start = Date()
        guard let palettes = await handles(group: "Colours") else {
            return finish(action, start, ok: false, status: nil, error: "Couldn't read Titan's colour palettes")
        }
        guard let palette = TitanPaletteMatch.palette(for: kelvin, in: palettes), let id = palette.titanId else {
            return finish(action, start, ok: false, status: nil,
                          error: "No colour palette named \(kelvin)K in Titan - record one (any name with \(kelvin)K in it)")
        }
        let result = await get(TitanEndpoints.applyPaletteURL(titanId: id, host: host, port: port))
        return finish(action, start, ok: result.ok, status: result.status, error: result.error,
                      detail: "palette \"\(palette.legend)\"")
    }

    private func get(_ url: URL?) async -> (ok: Bool, status: Int?, error: String?) {
        guard let url else { return (false, nil, "No Titan host set") }
        do {
            let (_, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode
            return (status == 200, status, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    private func finish(_ action: TitanAction, _ start: Date, ok: Bool, status: Int?, error: String?,
                        detail: String? = nil) -> TitanResult {
        let result = TitanResult(action: action, ok: ok, statusCode: status,
                                 milliseconds: Self.elapsed(since: start), error: error, date: start)
        Log.titan("\(action.summary)\(detail.map { " (\($0))" } ?? "") -> \(ok ? "OK" : "FAIL") in \(result.milliseconds) ms")
        return result
    }

    /// Returns the Titan software version string, or nil if Titan didn't answer.
    func softwareVersion() async -> String? {
        guard let url = TitanEndpoints.softwareVersionURL(host: host, port: port),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r"))
        return text.isEmpty ? nil : text
    }

    /// Playback handles with their Active flags, or nil if Titan didn't answer.
    func playbackHandles() async -> [PlaybackHandleState]? {
        await handles(group: "Playbacks")
    }

    /// Every handle in a group ("Playbacks", "Colours", "Workspaces"), or nil
    /// if Titan didn't answer.
    func handles(group: String) async -> [PlaybackHandleState]? {
        guard let url = TitanEndpoints.handlesURL(group: group, host: host, port: port),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return TitanHandlesParser.parse(data)
    }

    private static func elapsed(since start: Date) -> Int {
        Int((Date().timeIntervalSince(start) * 1000).rounded())
    }
}
