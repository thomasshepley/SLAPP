import XCTest
@testable import TitanDeck

final class FloatingDeckLayoutTests: XCTestCase {
    private typealias Layout = FloatingDeckLayout

    /// The 3-wide, 15-key default deck over an iPad's desktop.
    private func frame(widthFraction: Double = 0.26, centreX: Double = 0.84, centreY: Double = 0.6,
                       move: (x: Double, y: Double) = (0, 0), resize: Double = 0,
                       width: Double = 1180, height: Double = 790) -> Layout.Frame {
        Layout.frame(keyCount: 15, columns: 3, containerWidth: width, containerHeight: height,
                     widthFraction: widthFraction, centreX: centreX, centreY: centreY, move: move, resize: resize)
    }

    func testKeepsTheDecksShapeAndItsPlace() {
        let deck = frame()
        XCTAssertEqual(deck.width, 306.8, accuracy: 0.01)
        XCTAssertEqual(deck.side, 91.6, accuracy: 0.01)            // (306.8 - 20 - 12) / 3
        XCTAssertEqual(deck.height, 532, accuracy: 0.01)           // bar 40 + 5 keys + 4 gaps + 10
        XCTAssertEqual(deck.centreX, 991.2, accuracy: 0.01)
        XCTAssertEqual(deck.centreY, 474, accuracy: 0.01)
    }

    func testGrowsFromTheCornerButNeverOffScreen() {
        let big = frame(resize: 1000)
        XCTAssertEqual(big.width, 452, accuracy: 0.01, "as tall as the screen allows")
        XCTAssertEqual(big.height, 774, accuracy: 0.01)
        XCTAssertEqual(big.centreX, 946, accuracy: 0.01, "pushed back on screen")
        XCTAssertEqual(big.centreY, 395, accuracy: 0.01)
        XCTAssertEqual(frame(resize: -1000).width, Layout.smallestWidth)
    }

    func testMovingStopsAtTheEdges() {
        XCTAssertEqual(frame(move: (-5000, 0)).centreX, 306.8 / 2 + Layout.margin, accuracy: 0.01)
        XCTAssertEqual(frame(move: (0, 5000)).centreY, 790 - 532 / 2 - Layout.margin, accuracy: 0.01)
    }

    func testNoRoomDoesntTrap() {
        let tiny = frame(width: 100, height: 100)
        XCTAssertEqual(tiny.width, 38, accuracy: 0.01)
        XCTAssertEqual(tiny.centreY, 50, accuracy: 0.01, "too tall to fit: centred")
        let none = frame(width: 0, height: 0)
        XCTAssertEqual(none.width, 0)
        XCTAssertEqual(none.side, 0)
    }
}
