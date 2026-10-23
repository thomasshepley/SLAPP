import XCTest
@testable import TitanDeck

final class OnScreenDeckLayoutTests: XCTestCase {
    func testRegularWidthMatchesPhysicalDeck() {
        XCTAssertEqual(OnScreenDeckLayout.columns(keyCount: 32, deckColumns: 8, isCompactWidth: false, isCompactHeight: false), 8)
        XCTAssertEqual(OnScreenDeckLayout.columns(keyCount: 15, deckColumns: 5, isCompactWidth: false, isCompactHeight: false), 5)
    }

    func testPhonePortraitUsesFourColumns() {
        XCTAssertEqual(OnScreenDeckLayout.columns(keyCount: 32, deckColumns: 8, isCompactWidth: true, isCompactHeight: false), 4)
        XCTAssertEqual(OnScreenDeckLayout.columns(keyCount: 6, deckColumns: 3, isCompactWidth: true, isCompactHeight: false), 3)
    }

    func testPhoneLandscapeGoesWide() {
        XCTAssertEqual(OnScreenDeckLayout.columns(keyCount: 32, deckColumns: 8, isCompactWidth: true, isCompactHeight: true), 8)
        XCTAssertEqual(OnScreenDeckLayout.columns(keyCount: 15, deckColumns: 5, isCompactWidth: true, isCompactHeight: true), 6)
        XCTAssertEqual(OnScreenDeckLayout.columns(keyCount: 0, deckColumns: 5, isCompactWidth: true, isCompactHeight: true), 1)
    }
}
