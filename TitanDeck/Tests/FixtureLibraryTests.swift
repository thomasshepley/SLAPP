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
        XCTAssertEqual(library.fixtures.count, 251)
        XCTAssertGreaterThan(library.gels.count, 1000, "the full LEE, Rosco and GAM books")
        XCTAssertGreaterThan(library.manufacturers.count, 10)
    }

    func testModesAreConsistent() throws {
        for fixture in try library().fixtures {
            XCTAssertFalse(fixture.modes.isEmpty, fixture.name)
            XCTAssertNotNil(fixture.photometry(for: nil), fixture.name)
            XCTAssertEqual(Set(fixture.modes.map(\.name)).count, fixture.modes.count, "\(fixture.name): mode names repeat")
            for mode in fixture.modes {
                let place = "\(fixture.name) / \(mode.name)"
                var taken = Set<Int>()
                for channel in mode.allChannels {
                    for slot in channel.offset ..< channel.offset + channel.slotCount {
                        XCTAssertTrue(taken.insert(slot).inserted, "\(place): slot \(slot + 1) used twice")
                    }
                }
                XCTAssertLessThanOrEqual(taken.max().map { $0 + 1 } ?? 0, mode.channelCount, place)
            }
        }
    }

    func testAsteraModesAreNumbered() throws {
        let astera = try library().fixtures.filter { $0.manufacturer == "Astera" }
        XCTAssertFalse(astera.isEmpty)
        for fixture in astera {
            for mode in fixture.modes {
                XCTAssertNotNil(mode.number, "\(fixture.name) / \(mode.name)")
                XCTAssertTrue(mode.title.hasPrefix("Mode "), mode.title)
            }
        }
    }

    func testModeTitleAndPixelCells() {
        let cell = [
            DmxChannel(offset: 1, resolution: 8, attribute: .red, label: "Cell 1 Red"),
            DmxChannel(offset: 2, resolution: 8, attribute: .green, label: "Cell 1 Green"),
            DmxChannel(offset: 3, resolution: 8, attribute: .blue, label: "Blue"),
        ]
        let mode = FixtureMode(name: "Mode 21 Dim RGB (16 px)", number: "21", summary: "Dim RGB",
                               channelCount: 49, channels: [DmxChannel(offset: 0, resolution: 8, attribute: .intensity, label: "Dimmer")] + cell,
                               repeatCells: 16, cellSize: 3)
        XCTAssertEqual(mode.title, "Mode 21 · Dim RGB (16 px)")
        XCTAssertNil(mode.detail, "Astera's brief is already in the name")
        let arri = FixtureMode(name: "CCT 8 bit", number: "2", summary: "Dimmer, CCT, GM, fan", channelCount: 6, channels: [])
        XCTAssertEqual(arri.title, "Mode 2 · CCT 8 bit")
        XCTAssertEqual(arri.detail, "Dimmer, CCT, GM, fan")
        let all = mode.allChannels
        XCTAssertEqual(all.count, 49)
        XCTAssertEqual(all.last?.offset, 48)
        XCTAssertEqual(all.first { $0.offset == 46 }?.label, "Cell 16 Red")
        XCTAssertEqual(all.first { $0.offset == 6 }?.label, "Cell 2 Blue")

        // Zones in the middle, control channels after them (SkyPanel style).
        let zoned = FixtureMode(name: "LE", number: "24", channelCount: 25, channels: [
            DmxChannel(offset: 0, resolution: 16, attribute: .intensity, label: "LE1 Dimmer"),
            DmxChannel(offset: 2, resolution: 8, attribute: .cct, label: "LE1 CCT"),
            DmxChannel(offset: 24, resolution: 8, attribute: .control, label: "Fan"),
        ], repeatCells: 8, cellSize: 3, cellStart: 0)
        let zones = zoned.allChannels
        XCTAssertEqual(zones.map { $0.slotCount }.reduce(0, +), 25)
        XCTAssertEqual(zones.first { $0.offset == 21 }?.label, "LE8 Dimmer")
        XCTAssertEqual(zones.last?.label, "Fan")
        XCTAssertEqual(FixtureMode.label("Zone 1 Red", cell: 12), "Zone 12 Red")
        XCTAssertEqual(FixtureMode.label("Cell 10 Red", cell: 2), "Cell 2 Cell 10 Red")

        XCTAssertEqual(FixtureMode(name: "Standard", channelCount: 4, channels: []).title, "Standard")
        XCTAssertEqual(FixtureMode(name: "Mode 5", number: "5", channelCount: 4, channels: []).title, "Mode 5")
        XCTAssertEqual(FixtureMode(name: "P4 RGBW", number: "P4", channelCount: 4, channels: []).title, "P4 · RGBW")
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
