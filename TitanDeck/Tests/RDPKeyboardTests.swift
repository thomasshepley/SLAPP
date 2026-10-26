import XCTest
@testable import TitanDeck

final class RDPKeyboardTests: XCTestCase {
    private func code(_ usage: Int, _ command: RDPKeyboard.CommandKey = .control) -> UInt32? {
        RDPKeyboard.scancode(hidUsage: usage, command: command)
    }

    func testLettersDigitsAndTheBasics() {
        XCTAssertEqual(code(0x04), 0x1E, "A")
        XCTAssertEqual(code(0x1D), 0x2C, "Z")
        XCTAssertEqual(code(0x14), 0x10, "Q")
        XCTAssertEqual(code(0x1E), 0x02, "1")
        XCTAssertEqual(code(0x27), 0x0B, "0")
        XCTAssertEqual(code(0x28), 0x1C, "Return")
        XCTAssertEqual(code(0x29), 0x01, "Esc")
        XCTAssertEqual(code(0x2A), 0x0E, "Backspace")
        XCTAssertEqual(code(0x2C), 0x39, "Space")
        XCTAssertEqual(code(0x3A), 0x3B, "F1")
        XCTAssertEqual(code(0x45), 0x58, "F12")
        XCTAssertEqual(code(0x64), 0x56, "the ISO key left of Z (UK \\\\ |)")
    }

    func testExtendedKeysCarryTheFlag() {
        XCTAssertEqual(code(0x52), 0x148, "Up")
        XCTAssertEqual(code(0x50), 0x14B, "Left")
        XCTAssertEqual(code(0x4C), 0x153, "forward Delete")
        XCTAssertEqual(code(0x58), 0x11C, "keypad Enter")
        XCTAssertEqual(code(0xE6), 0x138, "right Option is AltGr")
    }

    func testCommandIsCtrlOrWindows() {
        XCTAssertEqual(code(0xE3), 0x1D, "left Command as left Ctrl")
        XCTAssertEqual(code(0xE7), 0x11D, "right Command as right Ctrl")
        XCTAssertEqual(code(0xE3, .windows), 0x15B)
        XCTAssertEqual(code(0xE7, .windows), 0x15C)
        XCTAssertEqual(code(0xE2), 0x38, "Option is Alt")
        XCTAssertEqual(code(0xE0), 0x1D, "Control is Ctrl")
    }

    func testUnknownKeysAreLeftToiPadOS() {
        XCTAssertNil(code(0x00))
        XCTAssertNil(code(0x7F), "volume mute")
    }

    func testModifiersDontRepeat() {
        XCTAssertTrue(RDPKeyboard.isModifier(hidUsage: 0xE1))
        XCTAssertTrue(RDPKeyboard.isModifier(hidUsage: 0x39), "Caps Lock")
        XCTAssertFalse(RDPKeyboard.isModifier(hidUsage: 0x2A))
    }

    func testHeldKeysAreAllLetGo() {
        var held = HeldKeys()
        XCTAssertTrue(held.press(hidUsage: 0xE1, scancode: 0x2A))
        XCTAssertTrue(held.press(hidUsage: 0x04, scancode: 0x1E))
        XCTAssertFalse(held.press(hidUsage: 0x04, scancode: 0x1E), "already down")
        XCTAssertEqual(held.release(hidUsage: 0x04), 0x1E)
        XCTAssertNil(held.release(hidUsage: 0x04), "not down any more")
        XCTAssertEqual(held.releaseAll(), [0x2A])
        XCTAssertTrue(held.releaseAll().isEmpty)
    }

    func testCommandKeySettingSurvivesAndDefaultsToCtrl() throws {
        var settings = RDPSettings()
        XCTAssertEqual(settings.commandKey, .control)
        settings.commandKey = .windows
        let decoded = try JSONDecoder().decode(RDPSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.commandKey, .windows)
        let old = try JSONDecoder().decode(RDPSettings.self, from: Data(#"{"host":"10.0.0.5","username":"x"}"#.utf8))
        XCTAssertEqual(old.commandKey, .control, "settings saved before 0.21")
    }
}
