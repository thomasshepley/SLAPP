import XCTest
@testable import TitanDeck

final class DeskKeysTests: XCTestCase {
    func testKeypadKeysHaveTheHostsNames() {
        XCTAssertEqual(DeskKeys.names(for: .keypadDigit(7)), ["7"])
        XCTAssertEqual(DeskKeys.names(for: .keypadAt), ["@"])
        XCTAssertEqual(DeskKeys.names(for: .keypadEnter), ["enter"])
        XCTAssertNil(DeskKeys.names(for: .keypadClear), "Clear goes through the WebAPI, never Alt+C")
        XCTAssertEqual(DeskKeys.names(for: .keypadExit), ["exit"])
        XCTAssertEqual(DeskKeys.names(for: .keypadThro), ["thro"])
        XCTAssertNil(DeskKeys.names(for: .adjustIntensity(percent: 10)), "not a keypad key: still the WebAPI")
        XCTAssertNil(DeskKeys.names(for: .playbackGo(userNumber: 1)))
    }

    func testTitansKeyboardShortcutsOverTheRemoteDesktop() {
        XCTAssertEqual(DeskKeys.strokes(for: "@"), [.key(0x37, down: true), .key(0x37, down: false)], "number pad *")
        XCTAssertTrue(DeskKeys.strokes(for: "clear").isEmpty, "no Alt shortcuts")
        XCTAssertEqual(DeskKeys.strokes(for: "exit"), [.key(0x01, down: true), .key(0x01, down: false)], "Esc")
        XCTAssertEqual(DeskKeys.strokes(for: "thro").first, .key(0x135, down: true), "number pad /, extended")
        XCTAssertTrue(DeskKeys.strokes(for: "a").isEmpty, "only keypad keys")
    }

    func testEveryKeyTheDeckTypesIsInTheTable() {
        for digit in 0...9 { XCTAssertNotNil(DeskKeys.table[DeskKeys.names(for: .keypadDigit(digit))![0]]) }
        for action in [TitanAction.keypadAt, .keypadEnter, .keypadExit, .keypadThro] {
            XCTAssertNotNil(DeskKeys.table[DeskKeys.names(for: action)![0]])
        }
    }

    func testANudgeGoesOnTopOfTheCurrentLevel() {
        XCTAssertEqual(DeskKeys.nudged(40, by: 10), 50)
        XCTAssertEqual(DeskKeys.nudged(40, by: -10), 30)
        XCTAssertEqual(DeskKeys.nudged(95, by: 10), 100, "never past full")
        XCTAssertEqual(DeskKeys.nudged(3, by: -5), 0)
        XCTAssertEqual(DeskKeys.nudged(41.6, by: 1), 43, "whole numbers")
    }

    func testKeypadLinesTellTheLevelTheySet() {
        XCTAssertEqual(DeskKeys.typedLevel("101@50"), 50)
        XCTAssertEqual(DeskKeys.typedLevel("1 THRU 10@75"), 75)
        XCTAssertEqual(DeskKeys.typedLevel("101@@"), 100)
        XCTAssertNil(DeskKeys.typedLevel("101@5"), "one digit: 5% or 50% by Titan's setting")
        XCTAssertNil(DeskKeys.typedLevel("101"))
        XCTAssertEqual(DeskKeys.typedFixtures("1 THRU 3@50"), [1, 2, 3])
        XCTAssertEqual(DeskKeys.typedFixtures("101@50"), [101])
        XCTAssertNil(DeskKeys.typedFixtures("@50"))
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

    func testRigKeysAreTitansAltArrowShortcuts() {
        XCTAssertEqual(DeskKeys.shortcut(for: .nextFixture), ["next"])
        XCTAssertEqual(DeskKeys.shortcut(for: .previousFixture), ["prev"])
        XCTAssertEqual(DeskKeys.shortcut(for: .toggleHighlight), ["highlight"])
        XCTAssertNil(DeskKeys.shortcut(for: .keypadClear), "no Alt+C: CLEAR goes over CITP")
        XCTAssertEqual(Set(DeskKeys.shortcuts.keys), ["next", "prev", "highlight"], "RIG's three and nothing else")
        XCTAssertEqual(DeskKeys.strokes(for: "next"), [
            .key(0x38, down: true), .key(0x14D, down: true), .key(0x14D, down: false), .key(0x38, down: false),
        ], "over remote desktop: Alt held for Right, then let go")
        XCTAssertEqual(DeskKeys.strokes(for: "highlight")[1], .key(0x150, down: true))
    }
}
