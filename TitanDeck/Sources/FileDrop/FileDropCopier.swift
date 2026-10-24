// FileDrop/FileDropCopier.swift
import Foundation

/// Copies one file into the PC's shared folder in chunks, reporting progress.
/// Kept free of UI and actors so it can run off the main thread and be tested.
enum FileDropCopier {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static let chunkSize = 1 << 20   // 1 MB

    /// Copies `source` into `folder` without overwriting anything there, and
    /// returns the name it was saved under. `progress` gets 0...1.
    static func copy(_ source: URL, into folder: URL, progress: @escaping (Double) -> Void) throws -> String {
        let name = uniqueName(source.lastPathComponent) { candidate in
            FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path)
        }
        let destination = folder.appendingPathComponent(name)
        var copyError: Error?

        #if canImport(Darwin)
        // Coordinate with the Files app's SMB provider, which owns the folder.
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing,
                                       error: &coordinationError) { url in
            do { try write(source, to: url, progress: progress) } catch { copyError = error }
        }
        if let coordinationError { throw coordinationError }
        #else
        do { try write(source, to: destination, progress: progress) } catch { copyError = error }
        #endif

        if let copyError {
            try? FileManager.default.removeItem(at: destination)   // don't leave half a file
            throw copyError
        }
        return name
    }

    private static func write(_ source: URL, to destination: URL, progress: (Double) -> Void) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let total = (try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 } ?? 0
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw Failure(message: "Couldn't create \(destination.lastPathComponent) in the PC folder")
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        var written = 0
        progress(0)
        while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
            try output.write(contentsOf: chunk)
            written += chunk.count
            if total > 0 { progress(min(1, Double(written) / Double(total))) }
        }
        try output.synchronize()
        progress(1)
    }

    /// "Plot.pdf", then "Plot (2).pdf", "Plot (3).pdf"... until `isTaken` says no.
    static func uniqueName(_ name: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(name) else { return name }
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var number = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem) (\(number))" : "\(stem) (\(number)).\(ext)"
            if !isTaken(candidate) { return candidate }
            number += 1
        }
    }

    /// Copies an incoming file into the app's own staging folder, so it stays
    /// readable after the picker or share sheet that supplied it lets go.
    static func stage(_ source: URL, in staging: URL) throws -> URL {
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let name = uniqueName(source.lastPathComponent) {
            FileManager.default.fileExists(atPath: staging.appendingPathComponent($0).path)
        }
        let destination = staging.appendingPathComponent(name)
        #if canImport(Darwin)
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        #endif
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}
