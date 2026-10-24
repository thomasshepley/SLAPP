// Tests/KeyStyleTests.swift
import XCTest
@testable import TitanDeck

final class KeyStyleTests: XCTestCase {
    private func goKey(mode: KeyDefinition.PressedStyle.Mode) -> KeyDefinition {
        KeyDefinition(index: 0, label: "GO", colorHex: "#1E7D32", sfSymbol: "play.fill", action: .playbackGo(userNumber: 3),
                      pressedStyle: .init(mode: mode, colorHex: "#B23B1E", label: "LIVE", emoji: "🔴"))
    }

    func testPressedAppearanceOverridesOnlyWhatIsSet() {
        let key = goKey(mode: .held)
        XCTAssertEqual(key.appearance(pressed: false), key)
        let pressed = key.appearance(pressed: true)
        XCTAssertEqual(pressed.colorHex, "#B23B1E")
        XCTAssertEqual(pressed.label, "LIVE")
        XCTAssertEqual(pressed.emoji, "🔴")
        XCTAssertNil(pressed.sfSymbol, "an emoji replaces the symbol")

        var colourOnly = key
        colourOnly.pressedStyle = .init(colorHex: "#000000")
        XCTAssertEqual(colourOnly.appearance(pressed: true).label, "GO")
        XCTAssertEqual(colourOnly.appearance(pressed: true).sfSymbol, "play.fill")
    }

    func testWhenThePressedLookShows() {
        XCTAssertTrue(goKey(mode: .held).showsPressedLook(held: true, latched: false, live: false))
        XCTAssertFalse(goKey(mode: .held).showsPressedLook(held: false, latched: true, live: true))
        XCTAssertTrue(goKey(mode: .latch).showsPressedLook(held: false, latched: true, live: false))
        XCTAssertFalse(goKey(mode: .latch).showsPressedLook(held: true, latched: false, live: false))
        XCTAssertTrue(goKey(mode: .live).showsPressedLook(held: false, latched: false, live: true))
        XCTAssertTrue(goKey(mode: .live).showsPressedLook(held: true, latched: false, live: false))
        XCTAssertFalse(KeyDefinition(index: 0, label: "X").showsPressedLook(held: true, latched: true, live: true))
    }

    func testEmojiIsKeptShort() {
        XCTAssertEqual(KeyDefinition.cleanEmoji(" 🔥 "), "🔥")
        XCTAssertEqual(KeyDefinition.cleanEmoji("🇬🇧👍🏽🎬"), "🇬🇧👍🏽", "flags and skin tones count as one")
        XCTAssertNil(KeyDefinition.cleanEmoji("   "))
    }

    func testPalette() {
        var custom = DeckPalette.adding("#ff8800", to: [])
        XCTAssertEqual(custom, ["#FF8800"])
        custom = DeckPalette.adding("#FF8800", to: custom)
        XCTAssertEqual(custom.count, 1, "no duplicates")
        XCTAssertEqual(DeckPalette.adding("#1e7d32", to: custom), custom, "built-in colours aren't repeated")
        custom = DeckPalette.adding("#123456", to: custom)
        XCTAssertEqual(custom.first, "#123456", "newest first")
        XCTAssertEqual(DeckPalette.decode(DeckPalette.encode(custom)), custom)
        XCTAssertEqual(DeckPalette.removing("#ff8800", from: custom), ["#123456"])
        let full = (0 ..< 40).reduce([String]()) { DeckPalette.adding(String(format: "#0000%02X", $1), to: $0) }
        XCTAssertEqual(full.count, DeckPalette.maxCustom)
        XCTAssertEqual(DeckPalette.decode("junk,#ABC,#A1B2C3"), ["#A1B2C3"])
    }

    func testProfilesStillLoadAndNewStylesRoundTrip() throws {
        let old = ##"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","index":2,"label":"GO","colorHex":"#1E7D32"}"##
        let decoded = try JSONDecoder().decode(KeyDefinition.self, from: Data(old.utf8))
        XCTAssertNil(decoded.emoji)
        XCTAssertNil(decoded.pressedStyle)

        let key = goKey(mode: .latch)
        let again = try JSONDecoder().decode(KeyDefinition.self, from: JSONEncoder().encode(key))
        XCTAssertEqual(again, key)
        XCTAssertEqual(again.pressedStyle?.resolvedMode, .latch)
    }
}
