// Companion/Model/FXLibrary.swift
import Foundation

/// A video or bitmap kept for pixel effects (fire, police lights, lightning...)
/// to send to the Titan PC for Prism / the pixel mapper.
struct FXItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case video
        case image
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case fire = "Fire"
        case police = "Police & Emergency"
        case fireworks = "Fireworks"
        case lightning = "Lightning & Storm"
        case water = "Water & Underwater"
        case tv = "TV & Screen Flicker"
        case candle = "Candle & Flame"
        case explosion = "Explosion"
        case strobe = "Strobe & Chase"
        case sky = "Sky & Clouds"
        case abstract = "Abstract & Texture"
        case other = "Other"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .fire: "flame.fill"
            case .police: "light.beacon.max.fill"
            case .fireworks: "sparkles"
            case .lightning: "cloud.bolt.fill"
            case .water: "drop.fill"
            case .tv: "tv.fill"
            case .candle: "flame"
            case .explosion: "burst.fill"
            case .strobe: "bolt.fill"
            case .sky: "cloud.fill"
            case .abstract: "circle.hexagongrid.fill"
            case .other: "film"
            }
        }

        /// A guess from the file name ("Police_Lights_v2.mp4" -> police).
        static func guess(from name: String) -> Category {
            let text = name.lowercased()
            let rules: [(Category, [String])] = [
                (.police, ["police", "siren", "emergency", "ambulance", "blue light", "bluelight", "nypd", "cop"]),
                (.fireworks, ["firework", "sparkler", "pyro"]),
                (.lightning, ["lightning", "storm", "thunder"]),
                (.candle, ["candle", "torch", "lantern"]),
                (.fire, ["fire", "flame", "burn", "blaze", "ember"]),
                (.explosion, ["explosion", "explode", "blast", "boom"]),
                (.water, ["water", "underwater", "ocean", "sea", "pool", "ripple", "caustic"]),
                (.tv, ["tv", "television", "screen", "monitor", "flicker"]),
                (.strobe, ["strobe", "chase", "flash"]),
                (.sky, ["sky", "cloud", "sunset", "sunrise"]),
            ]
            for (category, words) in rules where words.contains(where: text.contains) { return category }
            return .other
        }
    }

    let id: UUID
    var title: String
    var category: Category
    /// File name inside the FX folder.
    var fileName: String
    var kind: Kind
    var pixelWidth: Int?
    var pixelHeight: Int?
    var durationSeconds: Double?
    var framesPerSecond: Double?
    var notes: String
    var added: Date
    var lastSent: Date?
    /// Where Prism has the clip: the Prism layer's Folder and File in Titan
    /// (the deck's FX page uses it when both are set).
    var prismFolder: Int? = nil
    var prismFile: Int? = nil
    /// From Prism (Sync with Prism, 0.39): the bank's name, the clip's file
    /// on the PC, and whether the last sync didn't find it in Prism.
    var prismBank: String? = nil
    var prismPath: String? = nil
    var prismMissing: Bool? = nil

    /// A clip only on the PC (from Prism) has no file on the iPad.
    var isOnIPad: Bool { !fileName.isEmpty }

    /// The deck FX page's kind for this category, if it has one.
    var deckCategory: DeckFX.Category? {
        switch category {
        case .fire: .fire
        case .candle: .candle
        case .lightning: .lightning
        case .police: .police
        case .fireworks: .fireworks
        case .tv: .tv
        default: nil
        }
    }

    /// On the deck's FX page: a deck category and both Prism numbers.
    var deckItem: DeckFX.Item? {
        guard let deckCategory, let prismFolder, let prismFile else { return nil }
        return DeckFX.Item(id: id, title: title, category: deckCategory, folder: prismFolder, file: prismFile)
    }

    /// "1920 x 1080 · 25 fps · 0:12".
    var summary: String {
        var parts: [String] = []
        if let w = pixelWidth, let h = pixelHeight { parts.append("\(w) x \(h)") }
        if let fps = framesPerSecond, fps > 0 { parts.append("\(fps.formatted(.number.precision(.fractionLength(0 ... 2)))) fps") }
        if let seconds = durationSeconds, seconds > 0 { parts.append(Self.clock(seconds)) }
        if kind == .image { parts.append("still") }
        if parts.isEmpty, let prismFolder, let prismFile { parts.append("Folder \(prismFolder) · File \(prismFile)") }
        return parts.joined(separator: " · ")
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func kind(forExtension ext: String) -> Kind? {
        let ext = ext.lowercased()
        if ["mov", "mp4", "m4v", "avi", "mkv", "webm", "mpg", "mpeg", "wmv", "mxf", "aim", "hap", "dxv"].contains(ext) { return .video }
        if ["png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "heic", "webp", "tga"].contains(ext) { return .image }
        return nil
    }
}

/// The FX list, saved as JSON next to the files.
struct FXIndex: Codable, Equatable {
    var items: [FXItem] = []

    func grouped(search: String, category: FXItem.Category?) -> [(category: FXItem.Category, items: [FXItem])] {
        let words = search.lowercased().split(separator: " ")
        let matching = items.filter { item in
            if let category, item.category != category { return false }
            let text = "\(item.title) \(item.category.rawValue) \(item.notes) \(item.fileName) \(item.prismBank ?? "")".lowercased()
            return words.allSatisfy { text.contains($0) }
        }
        return FXItem.Category.allCases.compactMap { category in
            let inCategory = matching.filter { $0.category == category }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return inCategory.isEmpty ? nil : (category, inCategory)
        }
    }
}
