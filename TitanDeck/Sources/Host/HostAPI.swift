// Host/HostAPI.swift
import Foundation

/// The TitanDeck Host's API (TitanDeckHost/src/Core/Api/Messages.cs) - change
/// both together. Plain HTTP on the show network; everything except hello
/// and pair needs the token from pairing.
enum HostProtocol {
    static let apiVersion = 1
    static let port = 4431
    /// Bonjour type the Host advertises. Also listed in NSBonjourServices.
    static let serviceType = "_titandeck-host._tcp"

    /// Fixes the Host accepts from the iPad (Fixer.AllowedFromIPad). The rest,
    /// like the Defender exclusion, have to be pressed on the PC itself.
    static let fixesAllowedFromIPad: Set<String> = [
        "AllowRemoteDesktop", "StartRemoteDesktop", "RestartRemoteDesktop",
        "UpdateRdpWrapIni", "AddFirewallRules",
    ]

    /// Community-maintained rdpwrap.ini. The iPad fetches it when the PC has
    /// no internet, then hands it to the Host.
    static let rdpWrapIniURL = URL(string: "https://raw.githubusercontent.com/sebaxakerhtc/rdpwrap.ini/master/rdpwrap.ini")!
}

struct HostHello: Codable, Equatable {
    var name: String
    var machineName: String
    var hostVersion: String
    var apiVersion: Int
    var paired: Bool
}

struct HostPairRequest: Codable, Equatable {
    var code: String
    var deviceName: String
}

struct HostPairResponse: Codable, Equatable {
    var token: String
    var hostName: String
    var deviceId: String
}

struct HostCheck: Codable, Equatable, Identifiable {
    enum State: String, Codable {
        case ok, warning, problem

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = State(rawValue: raw) ?? .problem
        }
    }

    var id: String
    var title: String
    var state: State
    var detail: String
    var fix: String?
    var fixTitle: String?

    /// A fix the iPad can trigger, rather than one for the PC's own window.
    var canFixFromIPad: Bool { fix.map(HostProtocol.fixesAllowedFromIPad.contains) ?? false }
}

struct HostStatus: Codable, Equatable {
    var overall: HostCheck.State
    var checks: [HostCheck]
    var edition: String
    var windowsVersion: String
    var termsrvVersion: String
    var titanRunning: Bool
    var filesWaitingForIPad: Int
    var hostVersion: String
}

struct HostFixRequest: Codable, Equatable {
    var action: String
}

struct HostFixResult: Codable, Equatable {
    var success: Bool
    var message: String
}

struct HostFileEntry: Codable, Equatable, Identifiable, Hashable {
    var name: String
    var size: Int64
    var modified: Date
    var id: String { name }
}

struct HostUploadResult: Codable, Equatable {
    var savedAs: String
    var size: Int64
}

struct HostIniResult: Codable, Equatable {
    var supportsThisPc: Bool
    var build: String
    var updated: String?
}

/// `{ "error": "..." }`, which the Host sends with a 4xx.
struct HostErrorBody: Codable {
    var error: String?
    var message: String?
}

enum HostAPI {
    /// The Host speaks camelCase JSON with ISO 8601 dates (with or without
    /// fractional seconds, depending on the value).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = parseDate(text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Not a date: \(text)"))
        }
        return decoder
    }()

    static let encoder = JSONEncoder()

    static func parseDate(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }
        // .NET writes 7 fractional digits, which ISO8601DateFormatter can refuse.
        if let dot = text.firstIndex(of: "."),
           let end = text[dot...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) {
            let digits = text[text.index(after: dot) ..< end]
            let trimmed = text[..<dot] + "." + digits.prefix(3) + text[end...]
            return withFraction.date(from: String(trimmed))
        }
        return nil
    }

    /// `http://<host>:4431/api/v1/<path>`, or nil for an empty address. The
    /// address may carry its own port ("10.0.0.5:5000") for testing.
    static func url(host: String, path: String, query: [URLQueryItem] = []) -> URL? {
        guard let (name, port) = splitAddress(host) else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = name
        components.port = port
        components.path = "/api/v1/" + path
        components.queryItems = query.isEmpty ? nil : query
        return components.url
    }

    /// "pc.local" -> ("pc.local", 4431); "10.0.0.5:5000" -> ("10.0.0.5", 5000);
    /// "[fe80::1]:4431" -> ("fe80::1", 4431).
    static func splitAddress(_ address: String) -> (String, Int)? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("["), let close = trimmed.firstIndex(of: "]") {
            let name = String(trimmed[trimmed.index(after: trimmed.startIndex) ..< close])
            let rest = trimmed[trimmed.index(after: close)...]
            let port = rest.hasPrefix(":") ? Int(rest.dropFirst()) : nil
            return name.isEmpty ? nil : (name, port ?? HostProtocol.port)
        }
        let colons = trimmed.filter { $0 == ":" }.count
        if colons == 1, let colon = trimmed.firstIndex(of: ":"),
           let port = Int(trimmed[trimmed.index(after: colon)...]), (1 ... 65535).contains(port) {
            return (String(trimmed[..<colon]), port)
        }
        return (trimmed, HostProtocol.port)   // a name, an IPv4 address or a bare IPv6 address
    }

    /// Keeps the six digits from whatever was typed or pasted ("482 913").
    static func normaliseCode(_ text: String) -> String {
        String(text.filter(\.isASCII).filter(\.isNumber).prefix(6))
    }

    /// "482 913" for display.
    static func displayCode(_ code: String) -> String {
        code.count > 3 ? "\(code.prefix(3)) \(code.dropFirst(3))" : code
    }
}

/// Things that go wrong talking to the Host, in words for the screen.
enum HostError: LocalizedError, Equatable {
    case noAddress
    /// The PC no longer knows this iPad (removed in the Host window).
    case notPaired
    case refused(String)
    case server(Int, String?)
    case unreachable(String)
    case incompatible(Int)

    var errorDescription: String? {
        switch self {
        case .noAddress: "No PC address set."
        case .notPaired: "The PC doesn't recognise this device any more. Pair again."
        case .refused(let message): message
        case .server(let code, let message): message ?? "The Host answered with error \(code)."
        case .unreachable(let detail): "Can't reach TitanDeck Host on the PC. \(detail)"
        case .incompatible(let version):
            "The Host on the PC speaks a newer version (\(version)). Update TitanDeck."
        }
    }

    /// Turns a non-2xx answer into an error.
    static func from(status: Int, body: Data) -> HostError {
        let message = (try? HostAPI.decoder.decode(HostErrorBody.self, from: body)).flatMap { $0.error ?? $0.message }
        switch status {
        case 401: return .notPaired
        case 403: return .refused(message ?? "The PC said no.")
        default: return .server(status, message)
        }
    }
}
