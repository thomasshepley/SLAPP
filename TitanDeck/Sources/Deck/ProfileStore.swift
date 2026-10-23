// Deck/ProfileStore.swift
import Foundation

/// Saves the active profile as JSON in Application Support. iCloud Drive
/// export/import is M8.
struct ProfileStore {
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true))
                ?? FileManager.default.temporaryDirectory
            self.directory = support.appendingPathComponent("Profiles", isDirectory: true)
        }
    }

    var activeProfileURL: URL {
        directory.appendingPathComponent("active-profile.json")
    }

    func load() -> DeckProfile? {
        guard let data = try? Data(contentsOf: activeProfileURL) else { return nil }
        do {
            return try JSONDecoder().decode(DeckProfile.self, from: data)
        } catch {
            Log.deck("Could not read saved profile, using default: \(error)")
            return nil
        }
    }

    func save(_ profile: DeckProfile) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: activeProfileURL, options: .atomic)
    }
}
