// Tests/DeckFlowTests.swift
import XCTest
@testable import TitanDeck

final class DeckFlowTests: XCTestCase {
    func testANumberAndEnterIsASelection() {
        var keypad = DeckFlow.KeypadBuffer()
        XCTAssertEqual(keypad.apply(.keypadDigit(1)), .none)
        XCTAssertEqual(keypad.apply(.keypadDigit(0)), .none)
        XCTAssertEqual(keypad.apply(.keypadDigit(2)), .none)
        XCTAssertEqual(keypad.apply(.keypadEnter), .selected, "102 Enter selects fixture 102")
        XCTAssertEqual(keypad.text, "")
        XCTAssertEqual(keypad.selection, 102)
    }

    func testTheSelectionFollowsTitan() {
        var keypad = DeckFlow.KeypadBuffer()
        func type(_ actions: TitanAction...) -> DeckFlow.KeypadBuffer.Event {
            actions.map { keypad.apply($0) }.last ?? .none
        }
        XCTAssertEqual(type(.keypadDigit(1), .keypadDigit(0), .keypadDigit(1), .keypadAt, .keypadDigit(5),
                            .keypadDigit(0), .keypadEnter), .none, "101 @ 50 sets a level, no page change")
        XCTAssertEqual(keypad.selection, 101, "but Titan keeps 101 selected")
        _ = type(.keypadAt, .keypadDigit(8), .keypadEnter)
        XCTAssertEqual(keypad.selection, 101, "@ 8 on its own acts on the same selection")
        _ = type(.keypadDigit(7), .keypadEnter)
        XCTAssertEqual(keypad.selection, 7)

        XCTAssertEqual(type(.keypadDigit(3), .keypadClear), .none, "the first Clear empties the line")
        XCTAssertEqual(keypad.selection, 7)
        XCTAssertEqual(type(.keypadClear), .clearedProgrammer, "the next clears the programmer")
        XCTAssertNil(keypad.selection)
        _ = type(.keypadDigit(4), .keypadExit, .keypadEnter)
        XCTAssertNil(keypad.selection, "Exit drops what's typed")
    }

    func testAnythingWithAtIsNotASelection() {
        var keypad = DeckFlow.KeypadBuffer()
        for action: TitanAction in [.keypadDigit(1), .keypadAt, .keypadDigit(5)] { _ = keypad.apply(action) }
        XCTAssertEqual(keypad.apply(.keypadEnter), .none, "1 @ 5 sets a level, it doesn't select")
        XCTAssertEqual(keypad.apply(.keypadEnter), .none, "Enter on an empty line selects nothing")

        _ = keypad.apply(.keypadDigit(7))
        _ = keypad.apply(.keypadClear)
        XCTAssertEqual(keypad.apply(.keypadEnter), .none, "Clear empties the line")
        _ = keypad.apply(.keypadDigit(7))
        _ = keypad.apply(.playbackGo(userNumber: 1))
        XCTAssertEqual(keypad.apply(.keypadEnter), .selected, "other keys don't disturb what's typed")
    }

    func testSelectionPageIsQuickKeysWithAWayBack() throws {
        let profile = DeckProfile.makeDefault()
        let page = DeckFlow.selectionPage(profile: profile, returnTo: 0)
        XCTAssertEqual(page.name, "Quick Keys")
        let back = try XCTUnwrap(page.key(at: 14), "bottom right")
        XCTAssertEqual(back.label, "Return to Keypad")
        XCTAssertEqual(back.action, .mainMenu, "tap for the keypad, hold for the menu")
        XCTAssertEqual(back.sfSymbol, DeckFlow.returnSymbol)
        XCTAssertNil(page.key(at: 13), "Menu's spot is left empty")
        XCTAssertEqual(page.key(at: 12)?.action, .keypadClear)
        XCTAssertEqual(page.key(at: 0)?.action, .adjustIntensity(percent: 1))
        XCTAssertEqual(page.key(at: 7)?.action, .flashSelection)
        XCTAssertEqual(page.key(at: 10)?.action, .colourPresets)
        XCTAssertEqual(page.keys.filter { $0.action == .mainMenu }.count, 1)
        XCTAssertEqual(Set(page.keys.map(\.index)).count, page.keys.count, "one key per position")

        // A profile without an Intensity page still gets the nudges.
        var bare = profile
        bare.pages = [profile.pages[0]]
        let fallback = DeckFlow.selectionPage(profile: bare, returnTo: 0)
        XCTAssertTrue(fallback.keys.contains { $0.action == .adjustIntensity(percent: -10) })
        XCTAssertEqual(fallback.keys.last?.action, .mainMenu)

        // A profile from before 0.17 still calls it Intensity.
        var old = profile
        old.pages[1].name = "Intensity"
        old.pages[1].keys.removeAll { $0.action == .adjustIntensity(percent: 10) }
        XCTAssertEqual(DeckFlow.quickKeysPageIndex(in: old), 1)
        XCTAssertNil(DeckFlow.selectionPage(profile: old, returnTo: 0).key(at: 2), "its own keys, not the standard ones")
        XCTAssertEqual(DeckFlow.quickKeysPageIndex(in: profile), 1)
        XCTAssertNil(DeckFlow.quickKeysPageIndex(in: bare))
    }

    func testMenuTapSwapsKeypadAndQuickKeys() {
        let profile = DeckProfile.makeDefault()
        let playbacks = profile.pages.firstIndex { $0.name == "Playbacks" }!
        XCTAssertEqual(DeckFlow.menuTap(onPage: 0, overlay: nil, profile: profile), .quickKeys(returnTo: 0))
        XCTAssertEqual(DeckFlow.menuTap(onPage: 0, overlay: .selection(returnTo: 0), profile: profile), .page(0),
                       "Return to Keypad on Quick Keys")
        XCTAssertEqual(DeckFlow.menuTap(onPage: 1, overlay: nil, profile: profile), .page(0), "the Quick Keys page")
        XCTAssertEqual(DeckFlow.menuTap(onPage: playbacks, overlay: nil, profile: profile), .page(0))
        XCTAssertEqual(DeckFlow.menuTap(onPage: 2, overlay: .colour(returnTo: 2), profile: profile), .page(0))

        // No keypad page: Menu just steps through the pages.
        let wall = DeckProfile.makePlaybackWall()
        XCTAssertEqual(DeckFlow.menuTap(onPage: 0, overlay: nil, profile: wall), .page(1))
    }

    func testMenuKeySaysWhereItGoes() {
        let profile = DeckProfile.makeDefault()
        XCTAssertEqual(DeckFlow.menuLabel(onPage: 0, overlay: nil, profile: profile, pageName: "Keypad"), "Quick Keys")
        XCTAssertNil(DeckFlow.menuLabel(onPage: 0, overlay: .selection(returnTo: 0), profile: profile, pageName: "Quick Keys"),
                     "keeps Return to Keypad")
        XCTAssertNil(DeckFlow.menuLabel(onPage: 1, overlay: nil, profile: profile, pageName: "Quick Keys"))
        XCTAssertNil(DeckFlow.menuLabel(onPage: 0, overlay: .colour(returnTo: 0), profile: profile, pageName: "Colour"))
        XCTAssertEqual(DeckFlow.menuLabel(onPage: 3, overlay: nil, profile: profile, pageName: "Playbacks"), "Playbacks")

        let back = DeckFlow.selectionPage(profile: profile, returnTo: 0).key(at: 14)
        XCTAssertEqual(DeckFlow.displayed(back, onPage: nil)?.label, "Return to Keypad")
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

final class DeckColourTests: XCTestCase {
    func testColourTemperatureLooksRight() {
        XCTAssertEqual(DeckFlow.colourHex(kelvin: 6600), "#FFFFFF", "6600K is the neutral point of the fit")
        let warm = HexColor(DeckFlow.colourHex(kelvin: 2700))!
        XCTAssertEqual(warm.red, 1)
        XCTAssertLessThan(warm.blue, 0.6, "tungsten is orange")
        let cool = HexColor(DeckFlow.colourHex(kelvin: 10000))!
        XCTAssertEqual(cool.blue, 1)
        XCTAssertLessThan(cool.red, 0.85, "10000K is blue-ish")
    }

    func testPaleKeysGetDarkText() {
        XCTAssertTrue(DeckFlow.wantsDarkText(on: DeckFlow.colourHex(kelvin: 4500)))
        XCTAssertFalse(DeckFlow.wantsDarkText(on: "#1E7D32"))
        XCTAssertFalse(DeckFlow.wantsDarkText(on: "#000000"))
        XCTAssertFalse(DeckFlow.wantsDarkText(on: "junk"))
    }

    func testSelectionOffersCCTAndColourPageComesBack() throws {
        let profile = DeckProfile.makeDefault()
        let selection = DeckFlow.selectionPage(profile: profile, returnTo: 0)
        let cct = try XCTUnwrap(selection.keys.first { $0.action == .colourPresets })
        XCTAssertEqual(cct.index, 10, "middle column, 4th row")

        var landscape = profile
        landscape.orientation = .landscape
        XCTAssertEqual(DeckFlow.selectionPage(profile: landscape, returnTo: 0).keys
            .first { $0.action == .colourPresets }?.index, 6, "5 wide: the first free spot")
        XCTAssertEqual(DeckFlow.keypadPageIndex(in: profile), 0)

        let colour = DeckFlow.colourPage(profile: profile, returnTo: 0)
        XCTAssertEqual(colour.key(at: 0)?.action, .colourTemperature(kelvin: 2700))
        XCTAssertEqual(colour.key(at: 8)?.action, .colourTemperature(kelvin: 10000))
        XCTAssertEqual(colour.key(at: 14)?.action, .mainMenu)
        XCTAssertEqual(colour.key(at: 14)?.label, "Return to Keypad")
        XCTAssertEqual(colour.key(at: 13)?.action, .deckChoice(.intensity), "straight back to the intensity keys")
        XCTAssertEqual(colour.key(at: 13)?.label, "INTENSITY")
        XCTAssertFalse(TitanAction.deckChoice(.intensity).isRemote)
        XCTAssertEqual(DeckFlow.cctKeys(keyCount: 6).count, 5, "leaves room for the way back")
    }

    func testColourActionsDraftAndDescribe() {
        XCTAssertEqual(ActionDraft(action: .colourTemperature(kelvin: 5600)).action, .colourTemperature(kelvin: 5600))
        XCTAssertEqual(ActionDraft(action: .colourPresets).action, .colourPresets)
        XCTAssertFalse(TitanAction.colourPresets.isRemote)
        XCTAssertTrue(TitanAction.colourTemperature(kelvin: 3200).isRemote)
        XCTAssertNil(TitanEndpoints.url(for: .colourTemperature(kelvin: 3200), host: "10.0.0.1"))
    }
}
