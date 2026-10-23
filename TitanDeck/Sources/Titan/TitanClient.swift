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
    private let session: URLSession

    init(host: String, port: Int = TitanEndpoints.defaultPort, timeout: TimeInterval = 0.5) {
        self.host = host
        self.port = port
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

    /// Returns the Titan software version string, or nil if Titan didn't answer.
    func softwareVersion() async -> String? {
        guard let url = TitanEndpoints.softwareVersionURL(host: host, port: port),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r"))
        return text.isEmpty ? nil : text
    }

    private static func elapsed(since start: Date) -> Int {
        Int((Date().timeIntervalSince(start) * 1000).rounded())
    }
}
