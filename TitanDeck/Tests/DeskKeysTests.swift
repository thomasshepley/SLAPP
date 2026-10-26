import XCTest
@testable import TitanDeck

final class DeskKeysTests: XCTestCase {
    func testKeypadKeysHaveTheHostsNames() {
        XCTAssertEqual(DeskKeys.names(for: .keypadDigit(7)), ["7"])
        XCTAssertEqual(DeskKeys.names(for: .keypadAt), ["@"])
        XCTAssertEqual(DeskKeys.names(for: .keypadEnter), ["enter"])
        XCTAssertEqual(DeskKeys.names(for: .keypadClear), ["clear"])
        XCTAssertEqual(DeskKeys.names(for: .keypadExit), ["exit"])
        XCTAssertEqual(DeskKeys.names(for: .keypadThro), ["thro"])
        XCTAssertNil(DeskKeys.names(for: .adjustIntensity(percent: 10)), "not a keypad key: still the WebAPI")
        XCTAssertNil(DeskKeys.names(for: .playbackGo(userNumber: 1)))
    }

    func testTitansKeyboardShortcutsOverTheRemoteDesktop() {
        XCTAssertEqual(DeskKeys.strokes(for: "@"), [.key(0x37, down: true), .key(0x37, down: false)], "number pad *")
        XCTAssertEqual(DeskKeys.strokes(for: "clear"), [.key(0x38, down: true), .key(0x2E, down: true),
                                                        .key(0x2E, down: false), .key(0x38, down: false)], "Alt+C")
        XCTAssertEqual(DeskKeys.strokes(for: "exit"), [.key(0x01, down: true), .key(0x01, down: false)], "Esc")
        XCTAssertEqual(DeskKeys.strokes(for: "thro").first, .key(0x135, down: true), "number pad /, extended")
        XCTAssertTrue(DeskKeys.strokes(for: "a").isEmpty, "only keypad keys")
    }

    func testEveryKeyTheDeckTypesIsInTheTable() {
        for digit in 0...9 { XCTAssertNotNil(DeskKeys.table[DeskKeys.names(for: .keypadDigit(digit))![0]]) }
        for action in [TitanAction.keypadAt, .keypadEnter, .keypadClear, .keypadExit, .keypadThro] {
            XCTAssertNotNil(DeskKeys.table[DeskKeys.names(for: action)![0]])
        }
    }

    func testLevelsAreTypedAsAtLevelEnter() {
        XCTAssertEqual(DeskKeys.level(60), ["@", "6", "0", "enter"])
        XCTAssertEqual(DeskKeys.level(0), ["@", "0", "enter"])
        XCTAssertEqual(DeskKeys.level(100), ["@", "1", "0", "0", "enter"])
        XCTAssertEqual(DeskKeys.level(112), ["@", "1", "0", "0", "enter"], "never past full")
        XCTAssertEqual(DeskKeys.level(-5), ["@", "0", "enter"])
        XCTAssertEqual(DeskKeys.level(54.6), ["@", "5", "5", "enter"])
        for name in DeskKeys.level(73) { XCTAssertNotNil(DeskKeys.table[name]) }
    }
}
