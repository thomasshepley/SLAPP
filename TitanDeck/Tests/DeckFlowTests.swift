// Tests/DeckFlowTests.swift
import XCTest
@testable import TitanDeck

final class DeckFlowTests: XCTestCase {
    func testANumberAndEnterIsASelection() {
        var keypad = DeckFlow.KeypadBuffer()
        XCTAssertFalse(keypad.apply(.keypadDigit(1)))
        XCTAssertFalse(keypad.apply(.keypadDigit(0)))
        XCTAssertFalse(keypad.apply(.keypadDigit(2)))
        XCTAssertTrue(keypad.apply(.keypadEnter), "102 Enter selects fixture 102")
        XCTAssertEqual(keypad.text, "")
    }

    func testAnythingWithAtIsNotASelection() {
        var keypad = DeckFlow.KeypadBuffer()
        for action: TitanAction in [.keypadDigit(1), .keypadAt, .keypadDigit(5)] { _ = keypad.apply(action) }
        XCTAssertFalse(keypad.apply(.keypadEnter), "1 @ 5 sets a level, it doesn't select")
        XCTAssertFalse(keypad.apply(.keypadEnter), "Enter on an empty line selects nothing")

        _ = keypad.apply(.keypadDigit(7))
        _ = keypad.apply(.keypadClear)
        XCTAssertFalse(keypad.apply(.keypadEnter), "Clear empties the line")
        _ = keypad.apply(.keypadDigit(7))
        _ = keypad.apply(.playbackGo(userNumber: 1))
        XCTAssertTrue(keypad.apply(.keypadEnter), "other keys don't disturb what's typed")
    }

    func testSelectionPageIsTheIntensityPageWithAWayBack() throws {
        let profile = DeckProfile.makeDefault()
        let page = DeckFlow.selectionPage(profile: profile, returnTo: 0)
        let back = try XCTUnwrap(page.key(at: 13), "where Menu sits on the 15-key layout")
        XCTAssertEqual(back.label, "Return to Keypad")
        XCTAssertEqual(back.action, .switchPage(0))
        XCTAssertEqual(page.key(at: 0)?.action, .adjustIntensity(percent: 1))
        XCTAssertFalse(page.keys.contains { $0.action == .mainMenu })
        XCTAssertEqual(Set(page.keys.map(\.index)).count, page.keys.count, "one key per position")

        // A profile without an Intensity page still gets the nudges.
        var bare = profile
        bare.pages = [profile.pages[0]]
        let fallback = DeckFlow.selectionPage(profile: bare, returnTo: 0)
        XCTAssertTrue(fallback.keys.contains { $0.action == .adjustIntensity(percent: -10) })
        XCTAssertEqual(fallback.keys.last?.action, .switchPage(0))
    }

    func testMenuKeyShowsThePageNameAndCycles() {
        let menu = KeyDefinition(index: 13, label: "Menu", action: .mainMenu)
        XCTAssertEqual(DeckFlow.displayed(menu, onPage: "Playbacks")?.label, "Playbacks")
        let go = KeyDefinition(index: 0, label: "GO", action: .playbackGo(userNumber: 1))
        XCTAssertEqual(DeckFlow.displayed(go, onPage: "Playbacks")?.label, "GO")
        XCTAssertNil(DeckFlow.displayed(nil, onPage: "Keypad"))

        XCTAssertEqual(DeckFlow.nextPage(after: 0, pageCount: 3), 1)
        XCTAssertEqual(DeckFlow.nextPage(after: 2, pageCount: 3), 0, "wraps round")
        XCTAssertEqual(DeckFlow.nextPage(after: 0, pageCount: 0), 0)
    }

    func testMenuPageListsEveryPage() {
        let profile = DeckProfile.makeDefault()
        let menu = DeckFlow.menuPage(profile: profile)
        XCTAssertEqual(menu.keys.map(\.label), profile.pages.map(\.name))
        XCTAssertEqual(menu.keys.last?.action, .switchPage(profile.pages.count - 1))
    }
}

final class DeckLabelTests: XCTestCase {
    func testShortLabelsGetBigType() {
        XCTAssertEqual(DeckFlow.labelScale("7", hasIcon: false), 0.66, "a keypad digit fills the key")
        XCTAssertEqual(DeckFlow.labelScale("@", hasIcon: false), 0.66)
        XCTAssertEqual(DeckFlow.labelScale("GO\n12", hasIcon: false), 0.66, "measured by the longest line")
        XCTAssertEqual(DeckFlow.labelScale("+10%", hasIcon: false), 0.40)
        XCTAssertEqual(DeckFlow.labelScale("ENTER", hasIcon: false), 0.30)
        XCTAssertEqual(DeckFlow.labelScale("Return to Keypad", hasIcon: false), 0.24)
        XCTAssertEqual(DeckFlow.labelScale("7", hasIcon: true), 0.24, "an icon needs the room")
    }

    func testAnUntouchedDefaultIsRefreshed() {
        var old = DeckProfile.makeDefault()
        old.pages[0].keys[0].colorHex = "#3A3A3C"   // how an older build saved it
        let refreshed = DeckProfile.starting(from: old)
        XCTAssertEqual(refreshed.pages[0].keys[0].colorHex, DeckProfile.digitColor)
        XCTAssertEqual(refreshed.id, old.id)
        XCTAssertEqual(refreshed.keyCount, old.keyCount)

        var edited = old
        edited.renamePage(at: 0, to: "Mine")
        XCTAssertEqual(DeckProfile.starting(from: edited), edited, "an edited profile is left alone")
        XCTAssertTrue(DeckProfile.starting(from: nil).isBuiltInDefault)
    }
}
