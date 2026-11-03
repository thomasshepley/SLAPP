import XCTest
@testable import TitanDeck

final class DeckProgrammerTests: XCTestCase {
    func testRemembersLevelsAndCCTPerFixture() {
        var programmer = DeckProgrammer()
        programmer.setLevel(0.5, for: [101, 102])
        programmer.setKelvin(3200, for: [101, 102])
        XCTAssertEqual(programmer.level(for: [101]), 0.5, "selected again on its own")
        XCTAssertEqual(programmer.level(for: [102, 101]), 0.5)
        XCTAssertEqual(programmer.kelvin(for: [101, 102]), 3200)
        programmer.setLevel(0.3, for: [102])
        XCTAssertNil(programmer.level(for: [101, 102]), "different levels: none shown")
        XCTAssertNil(programmer.level(for: [101, 103]), "one not known: none shown")
        XCTAssertNil(programmer.level(for: []))
        programmer.setLevel(1.4, for: [104])
        XCTAssertEqual(programmer.level(for: [104]), 1)
    }

    func testClearForgetsEverything() {
        var programmer = DeckProgrammer()
        programmer.setLevel(0.5, for: [101])
        programmer.setKelvin(5600, for: [101])
        programmer.clear()
        XCTAssertNil(programmer.level(for: [101]))
        XCTAssertNil(programmer.kelvin(for: [101]))
    }
}
