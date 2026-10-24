// Tests/PixelLayoutTests.swift
import XCTest
@testable import TitanDeck

final class PixelLayoutTests: XCTestCase {
    private func bundledJSON(_ name: String) throws -> Data {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Companion/\(name).json")
        return try Data(contentsOf: resources)
    }

    private func fixtures() throws -> [String: Fixture] {
        let list = try JSONDecoder().decode([Fixture].self, from: bundledJSON("fixtures"))
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    /// A 16-pixel tube, grouped into 4, 8 or 16 cells, cell 1 at the left.
    private func tube() -> PixelLayout {
        let pixels = (1 ... 16).map { PixelLayout.Pixel(id: $0, shape: .rect, x: Double($0 - 1) / 16, y: 0, w: 1.0 / 16, h: 1) }
        func split(_ count: Int) -> [[Int]] {
            let size = 16 / count
            return (0 ..< count).map { cell in Array((cell * size + 1) ... (cell * size + size)) }
        }
        return PixelLayout(face: .init(shape: .capsule, aspect: 40), pixels: pixels,
                           groups: ["": ["4": split(4), "8": split(8), "16": split(16)]])
    }

    func testTitanPixelModesAreTaggedByCell() throws {
        let titan = try XCTUnwrap(try fixtures()["fx-astera-titan-tube"])
        let mode195 = try XCTUnwrap(titan.modes.first { $0.number == "195" })
        let cells = Set(mode195.allChannels.compactMap(\.cell))
        XCTAssertEqual(cells, Set(1 ... 16), "16 pixels, each a cell")
        let mode17 = try XCTUnwrap(titan.modes.first { $0.number == "17" })
        XCTAssertEqual(Set(mode17.allChannels.compactMap(\.cell)), Set(1 ... 4))
        // Single-pixel modes aren't pixel modes.
        let mode89 = try XCTUnwrap(titan.modes.first { $0.number == "89" })
        XCTAssertTrue(mode89.channels.allSatisfy { $0.cell == nil })
    }

    func testCellsForAModeFollowTheLayout() throws {
        let titan = try XCTUnwrap(try fixtures()["fx-astera-titan-tube"])
        let layout = tube()
        XCTAssertEqual(layout.problems(), [])

        let mode195 = try XCTUnwrap(titan.modes.first { $0.number == "195" })
        let cells = layout.cells(for: mode195)
        XCTAssertEqual(cells.count, 16)
        XCTAssertEqual(cells[0].pixelIDs, [1])
        XCTAssertEqual(cells[0].channelText, "1-10", "16-bit dimmer, CCT, G/M, crossfade, x, y, strobe")
        XCTAssertEqual(cells[15].channelText, "151-160")

        let mode17 = try XCTUnwrap(titan.modes.first { $0.number == "17" })
        let four = layout.cells(for: mode17)
        XCTAssertEqual(four.map(\.pixelIDs.count), [4, 4, 4, 4])
        XCTAssertEqual(four[1].title, "Cell 2")

        // No grouping for that count: nothing to draw.
        let mode1 = try XCTUnwrap(titan.modes.first { $0.number == "1" })
        XCTAssertTrue(layout.cells(for: mode1).isEmpty)
    }

    func testProblemsAreFound() {
        var layout = tube()
        layout.groups[""]?["4"] = [[1, 2, 3, 4], [4, 5, 6, 7], [8, 9, 10, 11], [12, 99]]
        layout.groups[""]?["8"] = [[1, 2]]
        let problems = layout.problems()
        XCTAssertTrue(problems.contains { $0.contains("two cells") })
        XCTAssertTrue(problems.contains { $0.contains("unknown pixel") })
        XCTAssertTrue(problems.contains { $0.contains("1 lists") })
    }

    func testBundledLayoutsAreSound() throws {
        let layouts = try JSONDecoder().decode([String: PixelLayout].self, from: bundledJSON("pixel-layouts"))
        let fixtures = try fixtures()
        for (id, layout) in layouts {
            XCTAssertEqual(layout.problems(), [], id)
            let fixture = try XCTUnwrap(fixtures[id], "\(id) isn't in the library")
            // Every pixel mode the layout claims to cover draws all its cells.
            XCTAssertTrue(fixture.modes.contains { !layout.cells(for: $0).isEmpty }, "\(id): no mode matches the layout")
            for pixel in layout.pixels {
                XCTAssertTrue((-0.01 ... 1.01).contains(pixel.x) && (-0.01 ... 1.01).contains(pixel.y), "\(id) pixel \(pixel.id)")
            }
        }
    }
}
