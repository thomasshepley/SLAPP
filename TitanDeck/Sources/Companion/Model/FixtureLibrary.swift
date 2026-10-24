// Companion/Model/FixtureLibrary.swift
import Foundation

/// The bundled fixture library and gels, loaded once.
struct FixtureLibrary {
    let fixtures: [Fixture]
    let gels: [Gel]
    /// Pixel layouts from the manuals, by fixture id.
    let pixelLayouts: [String: PixelLayout]

    /// Loads Resources/Companion/fixtures.json, gels.json and
    /// pixel-layouts.json from a bundle.
    static func bundled(in bundle: Bundle = .main) -> FixtureLibrary {
        FixtureLibrary(fixtures: load([Fixture].self, "fixtures", bundle) ?? [],
                       gels: load([Gel].self, "gels", bundle) ?? [],
                       pixelLayouts: load([String: PixelLayout].self, "pixel-layouts", bundle) ?? [:])
    }

    init(fixtures: [Fixture], gels: [Gel] = [], pixelLayouts: [String: PixelLayout] = [:]) {
        self.fixtures = fixtures.sorted {
            ($0.manufacturer.lowercased(), $0.model.lowercased()) < ($1.manufacturer.lowercased(), $1.model.lowercased())
        }
        self.gels = gels
        self.pixelLayouts = pixelLayouts
    }

    var manufacturers: [String] {
        Array(Set(fixtures.map(\.manufacturer))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var categories: [String] {
        Array(Set(fixtures.compactMap(\.category))).sorted()
    }

    func fixture(id: String) -> Fixture? {
        fixtures.first { $0.id == id }
    }

    /// Every search word must appear in the manufacturer, model or category.
    func search(_ text: String, category: String? = nil, manufacturer: String? = nil) -> [Fixture] {
        let words = text.lowercased().split(whereSeparator: \.isWhitespace)
        return fixtures.filter { fixture in
            (category == nil || fixture.category == category)
                && (manufacturer == nil || fixture.manufacturer == manufacturer)
                && words.allSatisfy { fixture.searchText.contains($0) }
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ name: String, _ bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            Log.deck("Companion: \(name).json missing from the app bundle")
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Log.deck("Companion: couldn't read \(name).json - \(error)")
            return nil
        }
    }
}
