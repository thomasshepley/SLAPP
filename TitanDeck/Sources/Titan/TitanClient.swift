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
    /// A flash fading down in steps; letting go stops it.
    private var flashRamp: Task<Void, Never>?

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
        case .setCueFade(let id, let fadeOut, let seconds): return await runCueFade(titanId: id, fadeOut: fadeOut, seconds: seconds)
        case .dimmerFlash(let down, let seconds): return await runFlash(down: down, seconds: seconds)
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

    // MARK: - Cue fades (experimental)

    /// Selects cue 1 of the playback, then writes its fade time. The API docs
    /// list both properties but not the body format, so this sends the
    /// seconds as plain text - check it on the console.
    private func runCueFade(titanId: Int, fadeOut: Bool, seconds: Double) async -> TitanResult {
        let action = TitanAction.setCueFade(titanId: titanId, fadeOut: fadeOut, seconds: seconds)
        let start = Date()
        let select = await get(TitanEndpoints.selectFirstCueURL(titanId: titanId, host: host, port: port))
        guard select.ok else {
            return finish(action, start, ok: false, status: select.status, error: select.error ?? "Couldn't select the cue")
        }
        guard let url = TitanEndpoints.cueFadePropertyURL(fadeOut: fadeOut, write: true, host: host, port: port) else {
            return finish(action, start, ok: false, status: nil, error: "No Titan host set")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(TitanEndpoints.format(number: seconds).utf8)
        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode
            return finish(action, start, ok: status == 200, status: status, error: nil)
        } catch {
            return finish(action, start, ok: false, status: nil, error: error.localizedDescription)
        }
    }

    // MARK: - Flash (hold to 0%)

    /// Down with no fade: Titan's own FlashOut, and back with ClearFlash, which
    /// puts the fixtures back exactly as they were. With a fade: -5% steps
    /// spread over `seconds` (SetDimmerLevel takes no time), and back by
    /// releasing the selection's controls over `seconds`.
    private func runFlash(down: Bool, seconds: Double?) async -> TitanResult {
        let action = TitanAction.dimmerFlash(down: down, seconds: seconds)
        let start = Date()
        flashRamp?.cancel()
        flashRamp = nil
        guard let seconds, seconds > 0 else {
            let url = down ? TitanEndpoints.flashOutURL(host: host, port: port)
                           : TitanEndpoints.clearFlashURL(host: host, port: port)
            let result = await get(url)
            return finish(action, start, ok: result.ok, status: result.status, error: result.error)
        }
        guard down else {
            let result = await get(TitanEndpoints.releaseSelectionURL(seconds: seconds, host: host, port: port))
            return finish(action, start, ok: result.ok, status: result.status, error: result.error)
        }
        let steps = (count: 20, interval: seconds / 20)
        let stepURL = TitanEndpoints.url(for: .adjustIntensity(percent: -5), host: host, port: port)
        let first = await get(stepURL)
        flashRamp = Task { [weak self] in
            for _ in 1 ..< steps.count {
                try? await Task.sleep(nanoseconds: UInt64(steps.interval * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                _ = await self.get(stepURL)
            }
        }
        return finish(action, start, ok: first.ok, status: first.status, error: first.error,
                      detail: "fading over \(TitanEndpoints.format(number: seconds))s")
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

    // MARK: - Selection and patch (desk link, live intensity)

    /// Titan ids of everything selected, or nil if Titan didn't answer or the
    /// answer couldn't be read. On the desk link client, the operator's selection.
    func selectedFixtureIds() async -> [Int]? {
        guard let data = await body(TitanEndpoints.selectedFixtureIdsURL(host: host, port: port)) else { return nil }
        let ids = TitanSelectionParser.titanIds(from: data)
        if ids == nil { Log.titan("Couldn't read the selection from: \(String(decoding: data.prefix(200), as: UTF8.self))") }
        return ids
    }

    /// Selects these fixtures (by user number) in this WebAPI user's own
    /// selection, so the deck's keys act on them. Nothing for an empty list.
    @discardableResult
    func selectFixtures(userNumbers: [Int]) async -> Bool {
        guard !userNumbers.isEmpty else { return false }
        return await get(TitanEndpoints.selectFixturesURL(userNumbers: userNumbers, host: host, port: port)).ok
    }

    /// titanId -> fixture user number, or nil if Titan didn't answer.
    func fixtureUserNumbers() async -> [Int: Int]? {
        await handles(group: "Fixtures").map(TitanSelectionParser.userNumbers)
    }

    /// The Patch route to a fixture's address (experimental, off by default):
    /// select it in this WebAPI user's own selection if asked to, copy its
    /// address into the patch editor's properties, read them back. Never call
    /// this on the desk link client: the operator's own Patch must stay shut.
    func patchedAddress(selecting fixture: Int?) async -> (address: DmxAddress?, raw: String?) {
        if let fixture {
            guard await get(TitanEndpoints.selectFixturesURL(userNumbers: [fixture], host: host, port: port)).ok else {
                return (nil, nil)
            }
        }
        guard await get(TitanEndpoints.addressFromSelectionURL(host: host, port: port)).ok,
              let data = await body(TitanEndpoints.currentDmxAssignmentURL(host: host, port: port)) else { return (nil, nil) }
        let raw = String(decoding: data.prefix(300), as: UTF8.self)
        Log.titan("Patch/CurrentDmxAssignment answered: \(raw)")
        return (DmxAddress.parse(data), raw)
    }

    private func body(_ url: URL?) async -> Data? {
        guard let url, let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    private static func elapsed(since start: Date) -> Int {
        Int((Date().timeIntervalSince(start) * 1000).rounded())
    }
}
