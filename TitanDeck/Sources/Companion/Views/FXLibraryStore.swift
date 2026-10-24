// Companion/Views/FXLibraryStore.swift
import AVFoundation
import ImageIO
import SwiftUI

/// FX videos and bitmaps, kept in Documents/FX Library with an index.json.
@MainActor
final class FXLibraryStore: ObservableObject {
    @Published private(set) var index = FXIndex()
    @Published var lastMessage: String?

    let folder: URL
    private var indexURL: URL { folder.appendingPathComponent("index.json") }

    init(folder: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FX Library", isDirectory: true)) {
        self.folder = folder
        load()
    }

    func url(for item: FXItem) -> URL { folder.appendingPathComponent(item.fileName) }

    // MARK: - Adding

    /// Copies files in (they may come from a picker that takes access away).
    func add(_ urls: [URL]) async {
        var added = 0
        for source in urls {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            guard let kind = FXItem.kind(forExtension: source.pathExtension) else {
                lastMessage = "\(source.lastPathComponent) isn't a video or image."
                continue
            }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let name = FileDropCopier.uniqueName(source.lastPathComponent) {
                    FileManager.default.fileExists(atPath: self.folder.appendingPathComponent($0).path)
                }
                let destination = folder.appendingPathComponent(name)
                try FileManager.default.copyItem(at: source, to: destination)
                var item = FXItem(id: UUID(), title: Self.title(from: source), category: .guess(from: source.lastPathComponent),
                                  fileName: name, kind: kind, notes: "", added: Date())
                await Self.readMetadata(of: destination, into: &item)
                index.items.append(item)
                added += 1
            } catch {
                lastMessage = "Couldn't add \(source.lastPathComponent): \(error.localizedDescription)"
            }
            // Picked from Photos into a temporary copy: don't keep that twice.
            if source.path.contains("/FileDropIncoming/") { try? FileManager.default.removeItem(at: source) }
        }
        if added > 0 {
            save()
            lastMessage = added == 1 ? "Added 1 effect." : "Added \(added) effects."
        }
    }

    func update(_ item: FXItem) {
        guard let i = index.items.firstIndex(where: { $0.id == item.id }) else { return }
        index.items[i] = item
        save()
    }

    func delete(_ item: FXItem) {
        try? FileManager.default.removeItem(at: url(for: item))
        index.items.removeAll { $0.id == item.id }
        save()
    }

    func markSent(_ items: [FXItem]) {
        let now = Date()
        for item in items {
            if let i = index.items.firstIndex(where: { $0.id == item.id }) { index.items[i].lastSent = now }
        }
        save()
    }

    // MARK: - Saving

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let saved = try? JSONDecoder().decode(FXIndex.self, from: data) else { return }
        // Drop entries whose file has gone (deleted in the Files app, say).
        index = FXIndex(items: saved.items.filter { FileManager.default.fileExists(atPath: url(for: $0).path) })
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(index).write(to: indexURL, options: .atomic)
        } catch {
            lastMessage = "Couldn't save the FX list: \(error.localizedDescription)"
        }
    }

    // MARK: - Metadata

    private static func title(from url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        // Photos' temporary copies start with a UUID and a dash.
        let trimmed = stem.count > 37 && stem.dropFirst(36).first == "-" ? String(stem.dropFirst(37)) : stem
        return trimmed.replacingOccurrences(of: "_", with: " ")
    }

    private static func readMetadata(of url: URL, into item: inout FXItem) async {
        switch item.kind {
        case .video:
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) { item.durationSeconds = duration.seconds.isFinite ? duration.seconds : nil }
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                if let size = try? await track.load(.naturalSize), let transform = try? await track.load(.preferredTransform) {
                    let shown = size.applying(transform)
                    item.pixelWidth = Int(abs(shown.width).rounded())
                    item.pixelHeight = Int(abs(shown.height).rounded())
                }
                if let fps = try? await track.load(.nominalFrameRate) { item.framesPerSecond = Double(fps) }
            }
        case .image:
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return }
            item.pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
            item.pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
        }
    }
}
