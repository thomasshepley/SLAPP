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

    /// The official RDP Wrapper release the Host accepts (same pin as the
    /// Host's RdpWrapperRelease): fetched here for a PC without internet.
    static let rdpWrapperURL = URL(string: "https://github.com/stascorp/rdpwrap/releases/download/v1.6.2/RDPWrap-v1.6.2.zip")!
    static let rdpWrapperSHA256 = "35a9481ddbed5177431a9ea4bd09468fe987797d7b1231d64942d17eb54ec269"
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
    /// "test" or "show" (Host 0.7+; nil from older Hosts).
    var mode: String?
}

/// `POST /api/v1/desk/keys` (Host 0.10+): keypad keys to type on the PC for Titan.
struct HostDeskKeysRequest: Codable, Equatable {
    let keys: [String]
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

/// Remote desktop picture settings on the PC (Host 0.2+).
struct HostRdpQuality: Codable, Equatable {
    var imageQuality: String
    var profile: String
    var frameRate: Int
    /// "best", "balanced", "weakSignal", or nil when customised.
    var preset: String?
}

struct HostRdpQualityRequest: Codable, Equatable {
    var preset: String?
    var imageQuality: String?
    var profile: String?
    var frameRate: Int
}

/// `{ "error": "..." }`, which the Host sends with a 4xx.
/// `GET /api/v1/dmx` (Host 0.3+): universes heard over sACN, the ones it's
/// listening to, and why it can't listen, if it can't.
struct HostDmxSummary: Codable, Equatable {
    let universes: [Int]
    let listening: [Int]
    let problem: String?
}

/// `GET /api/v1/dmx/{universe}?start=&count=`: live levels, 0-255, from `start`.
struct HostDmxLevels: Codable, Equatable {
    let universe: Int
    let start: Int
    let levels: [Int]
    let priority: Int
    let sources: [String]
    let ageMs: Int
}

/// `GET /api/v1/patch` (Host 0.6+): the show's patch from Titan's patch
/// report (Disk > Reports), with each fixture's intensity channels when the
/// Host found its personality.
struct HostPatch: Codable, Equatable {
    let source: String?
    let fixtures: [HostPatchFixture]
    let problem: String?
}

/// One patched fixture. `universe` is Titan's DMX line (taken as the sACN
/// universe); `intensity` counts from the fixture's first channel (0).
struct HostPatchFixture: Codable, Equatable {
    let user: Int
    let model: String?
    let mode: String?
    let universe: Int
    let address: Int
    let channels: Int?
    let intensity: [Int]?
}

/// `GET /api/v1/citp/selection` (Host 0.9+): the desk's selection as Titan
/// shares it with visualisers over CITP, when the Host's CITP link is on
/// (Test or Show mode) and Titan has connected. `fixtures` are user numbers.
struct HostCitpSelection: Codable, Equatable {
    let enabled: Bool
    let linked: Bool
    let peer: String?
    let fixtures: [Int]
    let problem: String?
}

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

    /// Just the host of an address: "10.0.0.5:4431" -> "10.0.0.5",
    /// "[fe80::1]:4431" -> "fe80::1". For Titan and the remote desktop, which
    /// have their own ports.
    static func hostOnly(_ address: String) -> String {
        let text = cleanAddress(address)
        if text.hasPrefix("["), let end = text.firstIndex(of: "]") {
            return String(text[text.index(after: text.startIndex) ..< end])
        }
        let colons = text.filter { $0 == ":" }.count
        return colons == 1 ? String(text.prefix { $0 != ":" }) : text
    }

    /// When the Host moves address (Change Address), Titan and the remote
    /// desktop can move with it (they're on the same PC). The remote desktop
    /// keeps following Titan (an empty address) wherever it can.
    static func follow(titanHost: String, rdpHost: String, to newAddress: String,
                       titan: Bool, remote: Bool) -> (titanHost: String, rdpHost: String) {
        let new = hostOnly(newAddress)
        let titanNow = titanHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let rdpOwn = rdpHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let rdpNow = rdpOwn.isEmpty ? titanNow : rdpOwn
        let titanAfter = titan ? new : titanNow
        let rdpWanted = remote ? new : rdpNow
        return (titanAfter, rdpWanted == titanAfter ? "" : rdpWanted)
    }

    /// Trims an address and drops an interface ending: "192.168.1.20%en0" ->
    /// "192.168.1.20" (also "[fe80::1%en0]:4431" -> "[fe80::1]:4431"), so one
    /// that came from discovery, or was pasted from it, still works.
    static func cleanAddress(_ address: String) -> String {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent = text.firstIndex(of: "%") else { return text }
        let stop: Character = text.hasPrefix("[") ? "]" : ":"
        text.removeSubrange(percent ..< (text[percent...].firstIndex(of: stop) ?? text.endIndex))
        return text
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
