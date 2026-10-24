import XCTest
@testable import TitanDeck

final class KeypadReadoutTests: XCTestCase {
    private func type(_ text: String, into readout: inout KeypadReadout) -> UUID? {
        var last: UUID?
        for character in text {
            if character == "@" {
                last = readout.press(.keypadAt)
            } else if let digit = character.wholeNumberValue {
                last = readout.press(.keypadDigit(digit))
            }
        }
        return last
    }

    func testBuildsTheLineAsYouType() {
        var readout = KeypadReadout()
        XCTAssertNil(readout.current)
        _ = type("102@30", into: &readout)
        XCTAssertEqual(readout.current?.text, "102@30")
        XCTAssertTrue(readout.history.isEmpty)
    }

    func testEnterMovesTheLineToHistoryKeepingItsID() {
        var readout = KeypadReadout()
        let typing = type("102@30", into: &readout)
        let entered = readout.press(.keypadEnter)
        XCTAssertEqual(entered, typing, "same id, so the view can animate it across")
        XCTAssertNil(readout.current)
        XCTAssertEqual(readout.lastCommand?.text, "102@30")
    }

    func testKeepsTheLastThreeNewestLast() {
        var readout = KeypadReadout()
        for command in ["1@50", "2@60", "3@70", "4@80"] {
            _ = type(command, into: &readout)
            readout.press(.keypadEnter)
        }
        XCTAssertEqual(readout.history.map(\.text), ["2@60", "3@70", "4@80"])
        XCTAssertEqual(readout.lastCommand?.text, "4@80")
    }

    func testClearAndExitThrowAwayTheLine() {
        var readout = KeypadReadout()
        _ = type("12", into: &readout)
        readout.press(.keypadClear)
        XCTAssertNil(readout.current)
        _ = type("34", into: &readout)
        readout.press(.keypadExit)
        XCTAssertNil(readout.current)
        XCTAssertTrue(readout.history.isEmpty)
    }

    func testEnterOnAnEmptyLineAddsNothing() {
        var readout = KeypadReadout()
        XCTAssertNil(readout.press(.keypadEnter))
        XCTAssertTrue(readout.history.isEmpty)
    }

    func testOtherKeysAreIgnored() {
        var readout = KeypadReadout()
        XCTAssertNil(readout.press(.playbackGo(userNumber: 1)))
        XCTAssertNil(readout.press(.adjustIntensity(percent: 5)))
        XCTAssertNil(readout.current)
        XCTAssertFalse(KeypadReadout.isKeypad(.mainMenu))
        XCTAssertTrue(KeypadReadout.isKeypad(.keypadDigit(4)))
    }

    func testDeliveryTurnsSentWhenEveryKeyIsAnswered() {
        var readout = KeypadReadout()
        let id = type("12", into: &readout)!
        readout.press(.keypadEnter)
        XCTAssertEqual(readout.lastCommand?.delivery, .sending)
        readout.markAnswered(id, ok: true)
        readout.markAnswered(id, ok: true)
        XCTAssertEqual(readout.lastCommand?.delivery, .sending, "Enter still outstanding")
        readout.markAnswered(id, ok: true)
        XCTAssertEqual(readout.lastCommand?.delivery, .sent)
    }

    func testAnyFailedKeyMarksTheLineFailed() {
        var readout = KeypadReadout()
        let id = type("5", into: &readout)!
        readout.markAnswered(id, ok: false)
        XCTAssertEqual(readout.current?.delivery, .failed)
        readout.press(.keypadEnter)
        readout.markAnswered(id, ok: true)
        readout.markAnswered(id, ok: true)
        XCTAssertEqual(readout.lastCommand?.delivery, .failed, "stays red: Titan's line may differ")
    }

    func testStopsAtMaxLength() {
        var readout = KeypadReadout()
        _ = type(String(repeating: "1", count: KeypadReadout.maxLength + 5), into: &readout)
        XCTAssertEqual(readout.current?.text.count, KeypadReadout.maxLength)
    }
}
