// Support/TCPProbe.swift
import Foundation
import Network

/// Can a TCP connection be opened to host:port within the time? For "is
/// the PC's remote desktop answering" without logging in.
enum TCPProbe {
    static func canConnect(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty, let port = NWEndpoint.Port(rawValue: port) else { return false }
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
            let queue = DispatchQueue(label: "TitanDeck.TCPProbe")
            var finished = false
            func finish(_ result: Bool) {
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .waiting: finish(false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }
}
