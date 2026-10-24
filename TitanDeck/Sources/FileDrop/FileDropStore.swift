// FileDrop/FileDropStore.swift
import Foundation
import Network

/// Sends files to the Titan PC: through TitanDeck Host when it's paired and
/// answering (into Public Documents\TitanDeck\To PC), otherwise into a shared
/// folder. The folder is a Windows share connected in the Files app (Connect
/// to Server, smb://<PC>), picked once in TitanDeck and remembered as a
/// security-scoped bookmark - so iOS's own SMB client does the networking.
@MainActor
final class FileDropStore: ObservableObject {
    struct Item: Identifiable, Equatable {
        enum State: Equatable {
            case waiting
            case sending
            /// Saved under this name on the PC.
            case sent(String)
            case failed(String)
        }

        let id = UUID()
        let url: URL
        let name: String
        let size: Int64
        var progress: Double = 0
        var state: State = .waiting
    }

    enum Reachability: Equatable {
        case unknown
        case checking
        case reachable
        case unreachable
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var folderName: String?
    @Published private(set) var isSending = false
    @Published private(set) var reachability: Reachability = .unknown
    /// How the last send went: "TitanDeck Host" or the folder's name.
    @Published private(set) var lastRoute: String?
    @Published var lastError: String?

    private let defaults: UserDefaults
    private let staging: URL
    private static let bookmarkKey = "fileDrop.folderBookmark"
    private static let folderNameKey = "fileDrop.folderName"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        staging = FileManager.default.temporaryDirectory.appendingPathComponent("FileDrop", isDirectory: true)
        folderName = defaults.string(forKey: Self.folderNameKey)
    }

    var hasFolder: Bool { defaults.data(forKey: Self.bookmarkKey) != nil }
    var waitingCount: Int { items.filter { $0.state == .waiting || isFailed($0) }.count }

    /// Overall progress of the current send, 0...1.
    var overallProgress: Double {
        let active = items.filter { $0.state != .waiting }
        guard !active.isEmpty else { return 0 }
        let total = active.reduce(Int64(0)) { $0 + max($1.size, 1) }
        let done = active.reduce(0.0) { $0 + Double(max($1.size, 1)) * $1.progress }
        return done / Double(total)
    }

    // MARK: - Folder

    /// Remembers a folder picked with the document picker.
    func setFolder(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: Self.bookmarkKey)
            defaults.set(url.lastPathComponent, forKey: Self.folderNameKey)
            folderName = url.lastPathComponent
            lastError = nil
        } catch {
            lastError = "Couldn't remember that folder: \(error.localizedDescription)"
        }
    }

    func forgetFolder() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        defaults.removeObject(forKey: Self.folderNameKey)
        folderName = nil
    }

    private func resolveFolder() -> URL? {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        if stale { setFolder(url) }
        return url
    }

    // MARK: - Queue

    /// Adds files. They're copied into the app first, because the picker or
    /// share sheet that supplied them may take access away again.
    func add(_ urls: [URL]) {
        for url in urls {
            do {
                let staged = try FileDropCopier.stage(url, in: staging)
                let size = (try? staged.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 } ?? 0
                items.append(Item(url: staged, name: staged.lastPathComponent, size: Int64(size)))
            } catch {
                lastError = "Couldn't add \(url.lastPathComponent): \(error.localizedDescription)"
            }
            // Files opened in TitanDeck land in Documents/Inbox; don't keep them twice.
            if url.path.contains("/Documents/Inbox/") { try? FileManager.default.removeItem(at: url) }
        }
    }

    func remove(_ item: Item) {
        try? FileManager.default.removeItem(at: item.url)
        items.removeAll { $0.id == item.id }
    }

    func clearSent() {
        for item in items where isSent(item) { try? FileManager.default.removeItem(at: item.url) }
        items.removeAll(where: isSent)
    }

    // MARK: - Sending

    /// Sends everything waiting (or failed) to the PC, one file at a time:
    /// through `host` when given, falling back to the shared folder if the
    /// Host stops answering part way.
    func send(via host: HostClient? = nil) async {
        guard !isSending else { return }
        let folder = resolveFolder()
        guard host != nil || folder != nil else {
            lastError = "Pair with TitanDeck Host in Settings, or set up a shared folder."
            return
        }
        isSending = true
        lastError = nil
        defer { isSending = false }

        let scoped = folder?.startAccessingSecurityScopedResource() ?? false
        defer { if scoped { folder?.stopAccessingSecurityScopedResource() } }

        var host = host
        for id in items.filter({ $0.state == .waiting || isFailed($0) }).map(\.id) {
            guard let source = items.first(where: { $0.id == id })?.url else { continue }
            update(id) { $0.state = .sending; $0.progress = 0 }
            var result: Result<String, Error>
            if let client = host {
                result = await upload(source, id: id, via: client)
                if case .failure(let error) = result, let folder, case HostError.unreachable = error {
                    Log.titan("File drop: Host stopped answering, using the shared folder")
                    host = nil
                    update(id) { $0.progress = 0 }
                    result = await copy(source, id: id, into: folder)
                }
            } else if let folder {
                result = await copy(source, id: id, into: folder)
            } else {
                result = .failure(FileDropCopier.Failure(message: "TitanDeck Host stopped answering."))
            }
            switch result {
            case .success(let savedAs):
                update(id) { $0.state = .sent(savedAs); $0.progress = 1 }
            case .failure(let error):
                update(id) { $0.state = .failed(error.localizedDescription) }
                lastError = host != nil
                    ? "Some files didn't send. Is TitanDeck Host running on the PC?"
                    : "Some files didn't send. Is the PC on and the folder still connected in Files?"
            }
        }
        lastRoute = host != nil ? "TitanDeck Host" : folderName
        Log.titan("File drop: sent \(items.filter(isSent).count) file(s) via \(lastRoute ?? "PC")")
    }

    private func upload(_ source: URL, id: UUID, via client: HostClient) async -> Result<String, Error> {
        do {
            let result = try await client.upload(source) { fraction in
                Task { @MainActor [weak self] in self?.update(id) { $0.progress = fraction } }
            }
            return .success(result.savedAs)
        } catch {
            return .failure(error)
        }
    }

    private func copy(_ source: URL, id: UUID, into folder: URL) async -> Result<String, Error> {
        await Task.detached(priority: .userInitiated) {
            Result {
                try FileDropCopier.copy(source, into: folder) { fraction in
                    Task { @MainActor [weak self] in self?.update(id) { $0.progress = fraction } }
                }
            }
        }.value
    }

    private func update(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    private func isSent(_ item: Item) -> Bool {
        if case .sent = item.state { return true }
        return false
    }

    private func isFailed(_ item: Item) -> Bool {
        if case .failed = item.state { return true }
        return false
    }

    // MARK: - Is the PC there?

    /// Tries the PC's file sharing port (SMB, 445) with a short timeout.
    func checkReachability(host: String) async {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty, let port = NWEndpoint.Port(rawValue: 445) else {
            reachability = .unknown
            return
        }
        if reachability != .reachable { reachability = .checking }
        let reachable = await Self.canConnect(host: host, port: port, timeout: 2)
        reachability = reachable ? .reachable : .unreachable
    }

    private nonisolated static func canConnect(host: String, port: NWEndpoint.Port, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
            let queue = DispatchQueue(label: "TitanDeck.FileDrop.reachability")
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
