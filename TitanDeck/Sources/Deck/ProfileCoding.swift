// Deck/ProfileCoding.swift
import Foundation

/// JSON in and out for profile export/import, with validation on the way in.
enum ProfileCoding {
    enum ImportError: LocalizedError {
        case unreadable
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable: return "That file isn't a TitanDeck profile."
            case .empty: return "That profile has no pages."
            }
        }
    }

    static func encode(_ profile: DeckProfile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(profile)
    }

    /// Decodes and sanity-checks an imported profile. The result is marked as
    /// hand-made so it's never re-flowed for a different deck size.
    static func decode(_ data: Data) throws -> DeckProfile {
        guard var profile = try? JSONDecoder().decode(DeckProfile.self, from: data) else {
            throw ImportError.unreadable
        }
        guard !profile.pages.isEmpty else { throw ImportError.empty }
        profile.keyCount = min(max(profile.keyCount, 1), 64)
        for page in profile.pages.indices {
            profile.pages[page].keys.removeAll { $0.index < 0 || $0.index >= profile.keyCount }
        }
        profile.isBuiltInDefault = false
        return profile
    }
}
