// Tests/FixtureLibraryTests.swift
import XCTest
@testable import TitanDeck

final class FixtureLibraryTests: XCTestCase {
    /// The JSON shipped in the app, read from the source tree.
    private func bundledJSON(_ name: String) throws -> Data {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Companion/\(name).json")
        return try Data(contentsOf: resources)
    }

    private func library() throws -> FixtureLibrary {
        FixtureLibrary(fixtures: try JSONDecoder().decode([Fixture].self, from: bundledJSON("fixtures")),
                       gels: try JSONDecoder().decode([Gel].self, from: bundledJSON("gels")))
    }

    func testEveryFixtureAndGelDecodes() throws {
        let library = try library()
        XCTAssertEqual(library.fixtures.count, 221)
        XCTAssertGreaterThan(library.gels.count, 1000, "the full LEE, Rosco and GAM books")
        XCTAssertGreaterThan(library.manufacturers.count, 10)
    }

    func testModesAreConsistent() throws {
        for fixture in try library().fixtures {
            XCTAssertFalse(fixture.modes.isEmpty, fixture.name)
            XCTAssertNotNil(fixture.photometry(for: nil), fixture.name)
            for mode in fixture.modes {
                let used = mode.channels.map { $0.offset + $0.slotCount }.max() ?? 0
                XCTAssertLessThanOrEqual(used, mode.channelCount, "\(fixture.name) / \(mode.name)")
            }
        }
    }

    func testSearch() throws {
        let library = try library()
        let skypanels = library.search("skypanel s60")
        XCTAssertTrue(skypanels.contains { $0.model == "SkyPanel S60-C" })
        XCTAssertTrue(library.search("ARRI").allSatisfy { $0.manufacturer == "ARRI" || $0.searchText.contains("arri") })
        XCTAssertEqual(library.search("").count, library.fixtures.count)
        XCTAssertTrue(library.search("no such light").isEmpty)
        let category = try XCTUnwrap(library.categories.first)
        XCTAssertTrue(library.search("", category: category).allSatisfy { $0.category == category })
    }

    func testFixtureHelpers() throws {
        let s60 = try XCTUnwrap(try library().fixtures.first { $0.model == "SkyPanel S60-C" })
        XCTAssertEqual(s60.beamAngle, 105)
        XCTAssertEqual(s60.powerW, 450)
        XCTAssertEqual(s60.photometry(for: "Standard (RGBW)")?.luxAt1m, 14_500)
        XCTAssertTrue(s60.footprintSummary.hasSuffix("ch"))
    }

    func testUnknownAttributeDecodesAsOther() throws {
        let json = #"{"offset":0,"resolution":8,"attribute":"laserBeam","label":"X"}"#
        let channel = try JSONDecoder().decode(DmxChannel.self, from: Data(json.utf8))
        XCTAssertEqual(channel.attribute, .other)
    }
}
