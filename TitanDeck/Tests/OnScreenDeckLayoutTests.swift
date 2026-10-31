import XCTest
@testable import TitanDeck

final class OnScreenDeckLayoutTests: XCTestCase {
    private typealias Layout = OnScreenDeckLayout

    func testKeepsThePhysicalLayoutAndFillsTheSpace() {
        // The default 3-wide portrait deck on a phone held upright: 3 columns, big keys, no scrolling.
        let phone = Layout.grid(keyCount: 15, deckColumns: 3, width: 358, height: 600)
        XCTAssertEqual(phone.columns, 3)
        XCTAssertEqual(phone.rows, 5)
        XCTAssertEqual(phone.side, 112, accuracy: 0.01)   // (600 - 40) / 5, under (358 - 20) / 3
        XCTAssertFalse(phone.scrolls)
        // A 5 x 3 deck in a short, wide space stays 5 x 3 (no more reflowing to 6 across).
        let landscape = Layout.grid(keyCount: 15, deckColumns: 5, width: 800, height: 300)
        XCTAssertEqual(landscape.columns, 5)
        XCTAssertEqual(landscape.side, 93.33, accuracy: 0.01)
        XCTAssertFalse(landscape.scrolls)
    }

    func testKeysStopGrowingAtTheLargestSize() {
        let big = Layout.grid(keyCount: 15, deckColumns: 3, width: 1200, height: 1200)
        XCTAssertEqual(big.side, Layout.largestKey)
        XCTAssertFalse(big.scrolls)
    }

    func testANarrowSpaceReflowsToHalfTheWidth() {
        // An 8-wide wall on a phone held upright: 4 across, scrolling down.
        let wall = Layout.grid(keyCount: 32, deckColumns: 8, width: 358, height: 500)
        XCTAssertEqual(wall.columns, 4)
        XCTAssertEqual(wall.rows, 8)
        XCTAssertEqual(wall.side, 82, accuracy: 0.01)
        XCTAssertTrue(wall.scrolls)
        // Wide enough but too many rows: same columns, scrolling.
        let tall = Layout.grid(keyCount: 15, deckColumns: 3, width: 358, height: 200)
        XCTAssertEqual(tall.columns, 3)
        XCTAssertTrue(tall.scrolls)
        XCTAssertEqual(Layout.grid(keyCount: 0, deckColumns: 5, width: 300, height: 300).columns, 1)
    }

    func testSideBySideWhenWideAndTheKeysFitInHalf() {
        // iPhone Duo open, held like a book, and an iPad: keys on one side, selection on the other.
        XCTAssertEqual(Layout.arrangement(keyCount: 15, deckColumns: 3, width: 960, height: 640), .sideBySide)
        XCTAssertEqual(Layout.arrangement(keyCount: 15, deckColumns: 5, width: 1180, height: 700), .sideBySide)
        // A phone on its side with the 3-wide deck: still fits.
        XCTAssertEqual(Layout.arrangement(keyCount: 15, deckColumns: 3, width: 780, height: 330), .sideBySide)
        // Upright, or an 8-wide wall that wouldn't fit in half a phone: one column.
        XCTAssertEqual(Layout.arrangement(keyCount: 15, deckColumns: 3, width: 640, height: 960), .stacked)
        XCTAssertEqual(Layout.arrangement(keyCount: 32, deckColumns: 8, width: 780, height: 330), .stacked)
        // Too narrow for a selection side at all.
        XCTAssertEqual(Layout.arrangement(keyCount: 6, deckColumns: 3, width: 500, height: 300), .stacked)
    }
}
