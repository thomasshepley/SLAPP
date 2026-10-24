// UniFi/UniFiConnection.swift
import CryptoKit
import Foundation

/// Logs in to a UniFi console with a local admin's username and password and
/// reads the Network app's local API. The console's certificate is
/// self-signed, so it's trusted on first use and refused if it changes, the
/// same as the remote desktop.
final class UniFiConnection: NSObject, URLSessionDelegate, @unchecked Sendable {
    struct Credentials: Equatable {
        var address: String
        var username: String
        var password: String
        var site: String
    }

    enum Failure: LocalizedError, Equatable {
        case noAddress
        case wrongLogin
        /// The account wants two-factor; it has to be a local-only admin.
        case needsLocalAccount
        case certificateChanged
        case unreachable(String)
        case notUniFi
        case server(Int, String?)

        var errorDescription: String? {
            switch self {
            case .noAddress: "Add the UniFi console's address."
            case .wrongLogin: "UniFi didn't accept that username and password."
            case .needsLocalAccount:
                "That account needs two-factor sign-in. Make a local admin in UniFi (Admins & Users > Restrict to local access) and use that."
            case .certificateChanged:
                "The console's security certificate has changed since last time. If you've replaced or reset it, forget the old certificate in UniFi setup."
            case .unreachable(let detail): "Can't reach the UniFi console. \(detail)"
            case .notUniFi: "That address answered, but it doesn't look like a UniFi console."
            case .server(let code, let message): message ?? "UniFi answered with error \(code)."
            }
        }
    }

    let credentials: Credentials
    private let base: URL
    private let trust: CertificateTrustStore
    private var session: URLSession!
    private var flavour: UniFiAPI.Flavour?
    private var csrfToken: String?
    private var certificateMismatch = false

    static let trustKey = "unifiTrustedCertificates"

    init(credentials: Credentials, trust: CertificateTrustStore = CertificateTrustStore(key: UniFiConnection.trustKey)) throws {
        guard let base = UniFiAPI.baseURL(credentials.address) else { throw Failure.noAddress }
        self.credentials = credentials
        self.base = base
        self.trust = trust
        super.init()
        let configuration = URLSessionConfiguration.ephemeral   // own cookie jar, nothing saved to disk
        configuration.timeoutIntervalForRequest = 10
        configuration.httpShouldSetCookies = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    var isLoggedIn: Bool { flavour != nil }
    var consoleFlavour: UniFiAPI.Flavour? { flavour }

    // MARK: - Login

    func login() async throws {
        for flavour in [UniFiAPI.Flavour.unifiOS, .legacy] {
            var request = URLRequest(url: endpoint(UniFiAPI.loginPath(flavour)))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = flavour == .unifiOS
                ? ["username": credentials.username, "password": credentials.password, "rememberMe": false]
                : ["username": credentials.username, "password": credentials.password, "remember": false]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await send(request)
            let text = String(data: data, encoding: .utf8) ?? ""
            switch response.statusCode {
            case 200 ..< 300:
                self.flavour = flavour
                csrfToken = response.value(forHTTPHeaderField: "X-Csrf-Token")
                    ?? response.value(forHTTPHeaderField: "X-Updated-Csrf-Token")
                    ?? cookie(named: "csrf_token")
                Log.titan("UniFi: logged in (\(flavour.rawValue))")
                return
            case 499:
                throw Failure.needsLocalAccount
            case 400, 401, 403:
                if text.localizedCaseInsensitiveContains("mfa") || text.localizedCaseInsensitiveContains("2fa") {
                    throw Failure.needsLocalAccount
                }
                if flavour == .unifiOS && text.isEmpty { continue }   // probably not UniFi OS
                throw Failure.wrongLogin
            case 404, 405:
                continue   // try the other kind of controller
            default:
                throw Failure.server(response.statusCode, nil)
            }
        }
        throw Failure.notUniFi
    }

    func logout() {
        flavour = nil
        csrfToken = nil
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
    }

    // MARK: - Reading

    /// GET a site endpoint ("stat/device") and decode its data array.
    func list<T: Decodable>(_ path: String, as type: T.Type) async throws -> [T] {
        let data = try await authorised { flavour in
            URLRequest(url: self.endpoint(UniFiAPI.sitePath(flavour, site: self.credentials.site, path)))
        }
        do {
            return try UniFiAPI.decoder.decode(UniFiAPI.Envelope<T>.self, from: data).data
        } catch {
            throw Failure.server(0, "UniFi's answer to \(path) didn't make sense.")
        }
    }

    /// POST a command, e.g. {"cmd": "spectrum-scan", "mac": ...} to cmd/devmgr.
    func command(_ path: String, _ body: [String: Any]) async throws {
        let payload = try JSONSerialization.data(withJSONObject: body)
        _ = try await authorised { flavour in
            var request = URLRequest(url: self.endpoint(UniFiAPI.sitePath(flavour, site: self.credentials.site, path)))
            request.httpMethod = "POST"
            request.httpBody = payload
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return request
        }
    }

    /// Logs in if needed, and once more if the session has expired.
    private func authorised(_ make: @escaping (UniFiAPI.Flavour) -> URLRequest) async throws -> Data {
        if flavour == nil { try await login() }
        for attempt in 0 ..< 2 {
            guard let flavour else { throw Failure.notUniFi }
            var request = make(flavour)
            if let csrfToken { request.setValue(csrfToken, forHTTPHeaderField: "X-Csrf-Token") }
            let (data, response) = try await send(request)
            if let updated = response.value(forHTTPHeaderField: "X-Updated-Csrf-Token") { csrfToken = updated }
            switch response.statusCode {
            case 200 ..< 300:
                return data
            case 401 where attempt == 0, 403 where attempt == 0:
                self.flavour = nil
                try await login()
            default:
                let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { ($0["meta"] as? [String: Any])?["msg"] as? String }
                throw Failure.server(response.statusCode, message)
            }
        }
        throw Failure.wrongLogin
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        certificateMismatch = false
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw Failure.notUniFi }
            return (data, http)
        } catch let error as URLError {
            if certificateMismatch { throw Failure.certificateChanged }
            switch error.code {
            case .timedOut: throw Failure.unreachable("It didn't answer in time.")
            case .cannotConnectToHost: throw Failure.unreachable("Check the address, and that the iPad is on the network the console manages.")
            case .cannotFindHost, .dnsLookupFailed: throw Failure.unreachable("Check the address.")
            case .notConnectedToInternet, .networkConnectionLost: throw Failure.unreachable("Check the iPad's network.")
            case .cancelled: throw CancellationError()
            default: throw Failure.unreachable(error.localizedDescription)
            }
        }
    }

    /// The console's address with a path ("/api/auth/login").
    private func endpoint(_ path: String) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.path = path
        return components.url ?? base
    }

    private func cookie(named name: String) -> String? {
        session.configuration.httpCookieStorage?.cookies(for: base)?.first { $0.name == name }?.value
    }

    // MARK: - Certificate

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let leaf = (SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate])?.first else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let fingerprint = Self.fingerprint(SecCertificateCopyData(leaf) as Data)
        let port = UInt16(challenge.protectionSpace.port)
        switch trust.evaluate(host: challenge.protectionSpace.host, port: port, fingerprint: fingerprint) {
        case .trusted, .trustedFirstUse:
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        case .mismatch:
            certificateMismatch = true
            Log.titan("UniFi: certificate for \(challenge.protectionSpace.host) changed - refused")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    static func fingerprint(_ der: Data) -> String {
        SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
    }
}
