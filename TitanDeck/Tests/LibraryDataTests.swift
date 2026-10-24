// Tests/LibraryDataTests.swift
import XCTest
@testable import TitanDeck

/// The gel book, flicker data and FX library, against the files the app ships.
final class LibraryDataTests: XCTestCase {
    private func bundledJSON(_ name: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Companion/\(name).json"))
    }

    private func library() throws -> FixtureLibrary {
        FixtureLibrary(fixtures: try JSONDecoder().decode([Fixture].self, from: bundledJSON("fixtures")),
                       gels: try JSONDecoder().decode([Gel].self, from: bundledJSON("gels")))
    }

    // MARK: Gels

    func testGelBookHasEveryRangeAndUniqueIDs() throws {
        let library = try library()
        XCTAssertEqual(Set(library.gelRanges), ["LEE", "E-Colour+", "Roscolux", "Cinegel", "GamColor"])
        XCTAssertEqual(Set(library.gels.map(\.id)).count, library.gels.count)
        XCTAssertTrue(library.gels.contains { $0.category == .diffusion })
    }

    func testSearchingGels() throws {
        let library = try library()
        let lee201 = library.gels(matching: "lee 201")
        XCTAssertEqual(lee201.first?.name, "Full C.T. Blue")
        XCTAssertEqual(lee201.first?.category, .ctb)
        XCTAssertLessThan(lee201.first?.miredShift ?? 0, -100)
        XCTAssertFalse(library.gels(matching: "straw", range: "LEE").isEmpty)
        XCTAssertTrue(library.gels(matching: "", category: .cto).allSatisfy { $0.category == .cto })
    }

    func testStopLossFromTransmission() throws {
        let half = Gel(id: "x", manufacturer: "Lee", number: "1", name: "x", transmission: 50,
                       swatchRgb: .init(r: 1, g: 1, b: 1))
        XCTAssertEqual(half.stopLoss ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(half.displayNumber, "LEE 1")
    }

    func testNearestGelsLookAlike() throws {
        let library = try library()
        let red = try XCTUnwrap(library.gels(matching: "lee 106").first)
        let matches = library.nearestGels(to: red.rgb, count: 3, excluding: red.id, otherThan: "LEE")
        XCTAssertEqual(matches.count, 3)
        XCTAssertFalse(matches.contains { $0.range == "LEE" })
        XCTAssertTrue(matches.allSatisfy { $0.rgb.r > $0.rgb.g && $0.rgb.r > $0.rgb.b }, "lookalikes of a red are red")
    }

    func testColourDistance() {
        let white = ColourDistance.lab(RGB(r: 255, g: 255, b: 255))
        XCTAssertEqual(white.l, 100, accuracy: 0.1)
        XCTAssertEqual(ColourDistance.deltaE(white, white), 0)
        XCTAssertGreaterThan(ColourDistance.deltaE(white, ColourDistance.lab(RGB(r: 0, g: 0, b: 0))), 99)
    }

    // MARK: Flicker data

    func testFlickerDataCoversTheLibrary() throws {
        let library = try library()
        let profiles = try JSONDecoder().decode([String: FlickerProfile].self, from: bundledJSON("flicker"))
        XCTAssertEqual(Set(profiles.keys), Set(library.fixtures.map(\.id)))
        let flicker = FlickerLibrary(profiles: profiles)
        for fixture in library.fixtures where fixture.category?.lowercased().contains("tungsten") == true {
            XCTAssertEqual(flicker.profile(for: fixture).kind, .tungsten, fixture.name)
        }
        XCTAssertTrue(profiles.values.contains { $0.isResearched && $0.defaultHz != nil })
    }

    func testUnknownProfilesFallBackToTheTypeButKeepNotes() {
        let fixture = Fixture(id: "f", manufacturer: "M", model: "Test HMI", category: "HMI Fresnel", modes: [], photometry: [:])
        let flicker = FlickerLibrary(profiles: ["f": FlickerProfile(kind: .unknown, notes: "Claims flicker-free.", confidence: "none")])
        let profile = flicker.profile(for: fixture)
        XCTAssertEqual(profile.kind, .hmiElectronic)
        XCTAssertEqual(profile.notes, "Claims flicker-free.")
    }

    // MARK: FX library

    func testFXCategoryGuessedFromFileName() {
        XCTAssertEqual(FXItem.Category.guess(from: "Police_Lights_v2.mp4"), .police)
        XCTAssertEqual(FXItem.Category.guess(from: "fireworks-finale.mov"), .fireworks)
        XCTAssertEqual(FXItem.Category.guess(from: "Campfire loop.mov"), .fire)
        XCTAssertEqual(FXItem.Category.guess(from: "lightning strike.mp4"), .lightning)
        XCTAssertEqual(FXItem.Category.guess(from: "IMG_0042.MOV"), .other)
    }

    func testFXKindsAndSummary() {
        XCTAssertEqual(FXItem.kind(forExtension: "MOV"), .video)
        XCTAssertEqual(FXItem.kind(forExtension: "png"), .image)
        XCTAssertNil(FXItem.kind(forExtension: "pdf"))
        let item = FXItem(id: UUID(), title: "Fire", category: .fire, fileName: "fire.mov", kind: .video,
                          pixelWidth: 1920, pixelHeight: 1080, durationSeconds: 72.4, framesPerSecond: 25,
                          notes: "", added: Date())
        XCTAssertEqual(item.summary, "1920 x 1080 · 25 fps · 1:12")
    }

    func testFXIndexGroupsAndSearches() {
        func item(_ title: String, _ category: FXItem.Category) -> FXItem {
            FXItem(id: UUID(), title: title, category: category, fileName: title, kind: .video, notes: "", added: Date())
        }
        let index = FXIndex(items: [item("Torch", .fire), item("Blue lights", .police), item("Bonfire", .fire)])
        let all = index.grouped(search: "", category: nil)
        XCTAssertEqual(all.map(\.category), [.fire, .police], "in category order")
        XCTAssertEqual(all.first?.items.map(\.title), ["Bonfire", "Torch"])
        XCTAssertEqual(index.grouped(search: "blue", category: nil).first?.items.count, 1)
        XCTAssertTrue(index.grouped(search: "", category: .water).isEmpty)
    }
}
