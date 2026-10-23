import XCTest
@testable import TitanDeck

final class DeckGeometryTests: XCTestCase {
    func testLandscapeIsIdentity() {
        let g = DeckGeometry(keyCount: 15, orientation: .landscape)
        XCTAssertEqual(g.logicalColumns, 5)
        XCTAssertEqual((0..<15).map { g.logicalIndex(forPhysical: $0) }, (0..<15).map { $0 })
        XCTAssertEqual(g.imageQuarterTurns, 0)
    }

    /// Turned clockwise, the deck's top-left key ends up top-right.
    func testPortraitClockwise() {
        let g = DeckGeometry(keyCount: 15, orientation: .portraitClockwise)
        XCTAssertEqual(g.logicalColumns, 3)
        XCTAssertEqual(g.logicalRows, 5)
        XCTAssertEqual(g.logicalIndex(forPhysical: 0), 2)    // top-left -> top-right
        XCTAssertEqual(g.logicalIndex(forPhysical: 4), 14)   // top-right -> bottom-right
        XCTAssertEqual(g.logicalIndex(forPhysical: 10), 0)   // bottom-left -> top-left
        XCTAssertEqual(g.logicalIndex(forPhysical: 14), 12)  // bottom-right -> bottom-left
        XCTAssertEqual(g.imageQuarterTurns, -1)
    }

    func testPortraitAnticlockwise() {
        let g = DeckGeometry(keyCount: 15, orientation: .portraitAnticlockwise)
        XCTAssertEqual(g.logicalIndex(forPhysical: 0), 12)   // top-left -> bottom-left
        XCTAssertEqual(g.logicalIndex(forPhysical: 4), 0)    // top-right -> top-left
        XCTAssertEqual(g.logicalIndex(forPhysical: 14), 2)   // bottom-right -> top-right
        XCTAssertEqual(g.imageQuarterTurns, 1)
    }

    func testMappingIsABijection() {
        for count in [6, 8, 15, 32] {
            for orientation in DeckOrientation.allCases {
                let g = DeckGeometry(keyCount: count, orientation: orientation)
                let logical = (0..<count).compactMap { g.logicalIndex(forPhysical: $0) }
                XCTAssertEqual(Set(logical), Set(0..<count), "\(count) \(orientation)")
                for l in 0..<count {
                    XCTAssertEqual(g.logicalIndex(forPhysical: g.physicalIndex(forLogical: l)!), l)
                }
            }
        }
    }
}
