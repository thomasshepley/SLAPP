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

    func testFixturesAreSelectedByNumber() {
        XCTAssertEqual(DeskKeys.selecting([5]), ["5", "enter"])
        XCTAssertEqual(DeskKeys.selecting([12, 10, 11, 15, 16, 101]),
                       ["1", "0", "thro", "1", "2", "and", "1", "5", "and", "1", "6", "and", "1", "0", "1", "enter"])
        XCTAssertEqual(DeskKeys.selecting([3, 3, 0, -1]), ["3", "enter"], "once each, real fixture numbers only")
        XCTAssertEqual(DeskKeys.selecting([]), [])
        for name in DeskKeys.selecting([1, 2, 3, 7]) { XCTAssertNotNil(DeskKeys.table[name]) }
    }

    func testAFadedFlashIsTypedInSteps() {
        let down = DeskKeys.rampSteps(from: 90, to: 0, seconds: 1.05)
        XCTAssertEqual(down.map(\.percent), [60, 30, 0], "three a second, ending on 0")
        for (step, at) in zip(down, [0, 0.35, 0.7]) { XCTAssertEqual(step.at, at, accuracy: 0.001, "the first straight away") }
        XCTAssertEqual(DeskKeys.rampSteps(from: 0, to: 75, seconds: 0.7).map(\.percent), [38, 75])
        XCTAssertEqual(DeskKeys.rampSteps(from: 50, to: 0, seconds: 0.2).map(\.percent), [0], "too short to step: one go")
        XCTAssertEqual(DeskKeys.rampSteps(from: 100, to: 0, seconds: 60).count, 12, "never more than 12 steps")
        XCTAssertEqual(DeskKeys.rampSteps(from: 3, to: 0, seconds: 2).map(\.percent), [2, 1, 0], "no level typed twice")
        XCTAssertTrue(DeskKeys.rampSteps(from: 40, to: 40, seconds: 2).isEmpty, "already there")
    }

    func testOnlyTheNewestOfBackToBackLevelsIsTyped() {
        XCTAssertEqual(DeskKeys.coalesced(["@", "6", "4", "enter", "@", "5", "6", "enter", "@", "4", "8", "enter"]),
                       ["@", "4", "8", "enter"])
        XCTAssertEqual(DeskKeys.coalesced(["1", "0", "1", "@", "5", "0", "enter", "@", "7", "0", "enter", "@", "6", "0", "enter"]),
                       ["1", "0", "1", "@", "5", "0", "enter", "@", "6", "0", "enter"], "a selection's level stays")
        XCTAssertEqual(DeskKeys.coalesced(["@", "5", "0", "enter", "1", "enter", "@", "6", "0", "enter"]),
                       ["@", "5", "0", "enter", "1", "enter", "@", "6", "0", "enter"], "something in between keeps it")
        XCTAssertEqual(DeskKeys.coalesced(["@", "5", "0", "enter", "1", "0"]), ["@", "5", "0", "enter", "1", "0"])
        XCTAssertEqual(DeskKeys.coalesced([]), [])
    }
}
