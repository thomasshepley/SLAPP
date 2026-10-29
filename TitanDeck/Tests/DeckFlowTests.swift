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

    func testThruSelectsARange() {
        var keypad = DeckFlow.KeypadBuffer()
        for action: TitanAction in [.keypadDigit(1), .keypadThro, .keypadDigit(1), .keypadDigit(0)] {
            XCTAssertEqual(keypad.apply(action), .none)
        }
        XCTAssertEqual(keypad.text, "1>10")
        XCTAssertEqual(keypad.apply(.keypadEnter), .selected, "1 THRU 10 Enter selects 1-10")
        XCTAssertEqual(keypad.selected, Array(1...10))
        XCTAssertEqual(keypad.selection, 1)

        for action: TitanAction in [.keypadDigit(5), .keypadThro, .keypadDigit(3), .keypadAt, .keypadDigit(5), .keypadDigit(0)] {
            _ = keypad.apply(action)
        }
        XCTAssertEqual(keypad.apply(.keypadEnter), .none, "5 THRU 3 @ 50 sets a level")
        XCTAssertEqual(keypad.selected, [5, 4, 3], "but leaves 5-3 selected, in typed order")

        _ = keypad.apply(.keypadThro)
        XCTAssertEqual(keypad.apply(.keypadEnter), .none, "THRU on its own isn't a selection")
        XCTAssertEqual(keypad.selected, [5, 4, 3])
        XCTAssertEqual(keypad.apply(.keypadClear), .clearedProgrammer)
        XCTAssertEqual(keypad.selected, [])
    }

    func testThruTextIsChecked() {
        XCTAssertEqual(DeckFlow.KeypadBuffer.fixtures(in: "102"), [102])
        XCTAssertEqual(DeckFlow.KeypadBuffer.fixtures(in: "7>9"), [7, 8, 9])
        XCTAssertNil(DeckFlow.KeypadBuffer.fixtures(in: ""))
        XCTAssertNil(DeckFlow.KeypadBuffer.fixtures(in: "7>"))
        XCTAssertNil(DeckFlow.KeypadBuffer.fixtures(in: ">7"))
        XCTAssertNil(DeckFlow.KeypadBuffer.fixtures(in: "1>2>3"))
        XCTAssertNil(DeckFlow.KeypadBuffer.fixtures(in: "1>99999"), "too many to list")
    }

    func testClearIsThruWhileNothingIsSelected() {
        let clear = KeyDefinition(index: 12, label: "CLEAR", colorHex: DeckProfile.releaseColor, action: .keypadClear)
        let thru = DeckFlow.keypadKey(clear, onKeypad: true, hasSelection: false)
        XCTAssertEqual(thru?.action, .keypadThro)
        XCTAssertEqual(thru?.label, "THRU")
        XCTAssertEqual(thru?.index, 12)
        XCTAssertEqual(DeckFlow.keypadKey(clear, onKeypad: true, hasSelection: true), clear, "something selected: Clear")
        XCTAssertEqual(DeckFlow.keypadKey(clear, onKeypad: false, hasSelection: false), clear, "only on the keypad")
        let enter = KeyDefinition(index: 11, label: "ENTER", action: .keypadEnter)
        XCTAssertEqual(DeckFlow.keypadKey(enter, onKeypad: true, hasSelection: false), enter)
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
        let back = try XCTUnwrap(page.key(at: 13), "bottom middle, where Menu is on the keypad")
        XCTAssertEqual(back.label, "Return to Keypad")
        XCTAssertEqual(back.action, .mainMenu, "tap for the keypad, hold for the menu")
        XCTAssertEqual(back.sfSymbol, DeckFlow.returnSymbol)
        XCTAssertEqual(page.key(at: 14)?.action, .colourPresets, "CCT bottom right")
        XCTAssertEqual(page.key(at: 12)?.action, .keypadClear)
        XCTAssertEqual(page.key(at: 0)?.action, .adjustIntensity(percent: 1))
        XCTAssertEqual(page.key(at: 7)?.action, .flashSelection)
        XCTAssertEqual(page.key(at: 10)?.action, .deckChoice(.selectionStrip(1)), "the selection strip, row 4")
        XCTAssertEqual(page.keys.filter { $0.action == .mainMenu }.count, 1)
        XCTAssertEqual(Set(page.keys.map(\.index)).count, page.keys.count, "one key per position")

        // A profile without an Intensity page still gets the nudges.
        var bare = profile
        bare.pages = [profile.pages[0]]
        let fallback = DeckFlow.selectionPage(profile: bare, returnTo: 0)
        XCTAssertTrue(fallback.keys.contains { $0.action == .adjustIntensity(percent: -10) })
        XCTAssertEqual(fallback.key(at: 13)?.action, .mainMenu, "a way back, where Menu is")

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
        XCTAssertEqual(DeckFlow.menuTap(onPage: 0, overlay: nil, profile: profile, hasSelection: true), .quickKeys(returnTo: 0))
        XCTAssertEqual(DeckFlow.menuTap(onPage: 0, overlay: .selection(returnTo: 0), profile: profile, hasSelection: true), .page(0),
                       "Return to Keypad on Quick Keys")
        XCTAssertEqual(DeckFlow.menuTap(onPage: 1, overlay: nil, profile: profile, hasSelection: true), .page(0), "the Quick Keys page")
        XCTAssertEqual(DeckFlow.menuTap(onPage: playbacks, overlay: nil, profile: profile, hasSelection: true), .page(0))
        XCTAssertEqual(DeckFlow.menuTap(onPage: 2, overlay: .colour(returnTo: 2), profile: profile, hasSelection: true), .page(0))

        // No keypad page: Menu just steps through the pages.
        let wall = DeckProfile.makePlaybackWall()
        XCTAssertEqual(DeckFlow.menuTap(onPage: 0, overlay: nil, profile: wall, hasSelection: true), .page(1))
    }

    func testMenuKeySaysWhereItGoes() {
        let profile = DeckProfile.makeDefault()
        XCTAssertEqual(DeckFlow.menuLabel(onPage: 0, overlay: nil, profile: profile, pageName: "Keypad", hasSelection: true), "Quick Keys")
        XCTAssertNil(DeckFlow.menuLabel(onPage: 0, overlay: .selection(returnTo: 0), profile: profile, pageName: "Quick Keys", hasSelection: true),
                     "keeps Return to Keypad")
        XCTAssertNil(DeckFlow.menuLabel(onPage: 1, overlay: nil, profile: profile, pageName: "Quick Keys", hasSelection: true))
        XCTAssertNil(DeckFlow.menuLabel(onPage: 0, overlay: .colour(returnTo: 0), profile: profile, pageName: "Colour", hasSelection: true))
        XCTAssertEqual(DeckFlow.menuLabel(onPage: 3, overlay: nil, profile: profile, pageName: "Playbacks", hasSelection: true), "Playbacks")

        XCTAssertEqual(DeckFlow.menuLabel(onPage: 0, overlay: nil, profile: profile, pageName: "Keypad", hasSelection: false),
                       "Nothing Selected")
        XCTAssertEqual(DeckFlow.menuTap(onPage: 0, overlay: nil, profile: profile, hasSelection: false), .groups(returnTo: 0),
                       "nothing selected: a tap opens the Groups page")
        XCTAssertEqual(DeckFlow.menuTap(onPage: 3, overlay: nil, profile: profile, hasSelection: false), .page(0),
                       "elsewhere a tap still goes back to the keypad")

        let back = DeckFlow.selectionPage(profile: profile, returnTo: 0).key(at: 13)
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
        XCTAssertEqual(menu.keys.map(\.label), profile.pages.map(\.name) + ["RIG", "MASTERS", "SLATES"],
                       "every page, then Rig, Masters and the Slate Book")
        XCTAssertEqual(menu.keys.dropLast(3).last?.action, .switchPage(profile.pages.count - 1))
        XCTAssertEqual(menu.keys.suffix(3).map(\.action), [.deckChoice(.openRig), .deckChoice(.openMasters), .deckChoice(.openSlates)])
        XCTAssertEqual(Set(menu.keys.map(\.index)).count, menu.keys.count, "no two keys in one spot")
    }

    func testMenuKeepsRigMastersAndSlatesWhenThePagesFillTheDeck() {
        var profile = DeckProfile.makeDefault(keyCount: 6)
        while profile.pages.count < 8 { profile.pages.append(DeckPage(name: "P\(profile.pages.count)", keys: [])) }
        let menu = DeckFlow.menuPage(profile: profile)
        XCTAssertEqual(menu.keys.count, 6)
        XCTAssertEqual(menu.keys.suffix(3).map(\.label), ["RIG", "MASTERS", "SLATES"])
        XCTAssertEqual(menu.keys.map(\.index), Array(0 ..< 6))
    }

    func testRigPageIsPrevHighlightNext() {
        let profile = DeckProfile.makeDefault()
        let page = DeckFlow.rigPage(profile: profile, returnTo: 0, highlightOn: false)
        XCTAssertEqual(page.key(at: 0)?.action, .previousFixture)
        XCTAssertEqual(page.key(at: 1)?.action, .toggleHighlight)
        XCTAssertEqual(page.key(at: 2)?.action, .nextFixture)
        XCTAssertEqual(page.key(at: 0)?.label, "FIX -1")
        XCTAssertEqual(page.key(at: 2)?.label, "FIX +1")
        XCTAssertEqual(page.key(at: 3)?.action, .allFixtures, "ALL under them, back to the whole selection")
        XCTAssertTrue(page.keys.contains { $0.action == .mainMenu }, "a way back to the keypad")
        let lit = DeckFlow.rigPage(profile: profile, returnTo: 0, highlightOn: true)
        XCTAssertEqual(lit.key(at: 1)?.label, "HI LIGHT\nON")
    }

    func testGroupMastersAreFaders1To10OfPage60() {
        let cues = [
            CueChoice(titanId: 9, userNumber: nil, page: 59, index: 1, legend: "Backs", isActive: false),
            CueChoice(titanId: 8, userNumber: nil, page: 59, index: 0, legend: " Fronts ", isActive: false, level: 0.8),
            CueChoice(titanId: 7, userNumber: nil, page: 59, index: 2, legend: "", isActive: false),
            CueChoice(titanId: 6, userNumber: nil, page: 59, index: 10, legend: "Fader 11", isActive: false),
            CueChoice(titanId: 5, userNumber: nil, page: 0, index: 0, legend: "Cue", isActive: false),
        ]
        let masters = DeckFlow.groupMasters(cues, levels: [9: 0.4, 8: 0.1])
        XCTAssertEqual(masters.map(\.titanId), [8, 9, 7], "page 60 faders 1-10 only, in fader order")
        XCTAssertEqual(masters.map(\.name), ["Fronts", "Backs", "Fader 3"])
        XCTAssertEqual(masters.map(\.fader), [1, 2, 3])
        XCTAssertEqual(masters.map(\.level), [0.8, 0.4, nil], "Titan's own level first, else the one the deck set")

        let profile = DeckProfile.makeDefault()
        let page = DeckFlow.mastersPage(profile: profile, masters: masters)
        XCTAssertEqual(page.key(at: 0)?.label, "Fronts\n80%")
        XCTAssertEqual(page.key(at: 2)?.label, "Fader 3\n-")
        XCTAssertEqual(page.key(at: 1)?.action, .deckChoice(.pickMaster(titanId: 9)))
        XCTAssertTrue(page.keys.contains { $0.action == .mainMenu })
        let empty = DeckFlow.mastersPage(profile: profile, masters: [])
        XCTAssertEqual(empty.key(at: 0)?.label, "No masters\non page 60")
    }

    func testTheCurrentCCTShowsOnItsKeys() {
        let preset = KeyDefinition(index: 0, label: "3200K", colorHex: "#FFFFFF", action: .colourTemperature(kelvin: 3200))
        let other = KeyDefinition(index: 1, label: "5600K", colorHex: "#FFFFFF", action: .colourTemperature(kelvin: 5600))
        let cct = KeyDefinition(index: 2, label: "CCT", colorHex: "#FFFFFF", action: .colourPresets)
        XCTAssertEqual(DeckFlow.cctKey(preset, current: 3200).label, "3200K\nNOW")
        XCTAssertEqual(DeckFlow.cctKey(other, current: 3200).label, "5600K")
        XCTAssertEqual(DeckFlow.cctKey(cct, current: 3200).label, "CCT\n3200K")
        XCTAssertEqual(DeckFlow.cctKey(cct, current: nil).label, "CCT", "unknown: the key as it was")
        XCTAssertEqual(DeckFlow.cctKey(DeckFlow.cctKey(cct, current: 5600), current: 3200).label, "CCT\n3200K")
        XCTAssertEqual(DeckFlow.kelvin(inLegend: "Tungsten 3200K"), 3200)
        XCTAssertEqual(DeckFlow.kelvin(inLegend: "5600 k"), 5600)
        XCTAssertEqual(DeckFlow.kelvin(inLegend: "10000K"), 10000)
        XCTAssertNil(DeckFlow.kelvin(inLegend: "Red"))
        XCTAssertNil(DeckFlow.kelvin(inLegend: "Kiss 2"))
    }

    func testMasterLevelsGoUpInTens() {
        let master = DeckFlow.GroupMaster(titanId: 8, fader: 1, name: "Fronts", level: 0.3)
        let page = DeckFlow.masterLevelPage(master: master, keyCount: 15)
        XCTAssertEqual(page.keys.prefix(11).map(\.label), ["0%", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"])
        XCTAssertEqual(page.key(at: 3)?.colorHex, DeckProfile.goColor, "the current level is lit")
        XCTAssertEqual(page.key(at: 10)?.action, .deckChoice(.masterLevel(1)))
        XCTAssertEqual(page.key(at: 14)?.action, .deckChoice(.back))
        XCTAssertEqual(page.name, "Fronts 30%")
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
        XCTAssertEqual(cct.index, 14, "bottom right")

        var landscape = profile
        landscape.orientation = .landscape
        XCTAssertEqual(DeckFlow.selectionPage(profile: landscape, returnTo: 0).keys
            .first { $0.action == .colourPresets }?.index, 6, "5 wide: the first free spot")
        XCTAssertEqual(DeckFlow.keypadPageIndex(in: profile), 0)

        let colour = DeckFlow.colourPage(profile: profile, returnTo: 0)
        XCTAssertEqual(colour.key(at: 0)?.action, .colourTemperature(kelvin: 2700))
        XCTAssertEqual(colour.key(at: 8)?.action, .colourTemperature(kelvin: 10000))
        XCTAssertEqual(colour.key(at: 13)?.action, .mainMenu)
        XCTAssertEqual(colour.key(at: 13)?.label, "Return to Keypad")
        XCTAssertEqual(colour.key(at: 14)?.action, .deckChoice(.intensity), "bottom right: swaps with CCT on Quick Keys")
        XCTAssertEqual(colour.key(at: 14)?.label, "INTENSITY")
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

final class DeckSplashTests: XCTestCase {
    func testSplashIsTheIconWithAShineAcrossIt() {
        let still = DeckFlow.splashPage(columns: 4, keyCount: 16, frame: DeckFlow.splashPeriod - 1)
        XCTAssertEqual(still.keys.count, 16)
        XCTAssertTrue(still.keys.allSatisfy { $0.action == nil && $0.label.isEmpty }, "keys do nothing")
        // Between shines (end of the sweep), the keys are the icon's own colours.
        XCTAssertEqual(still.keys.map(\.colorHex), DeckFlow.iconColours.flatMap { $0 })

        // Mid-sweep, the diagonal through the middle is brighter than the icon.
        let shining = (0 ..< DeckFlow.splashPeriod).map { DeckFlow.splashPage(columns: 4, keyCount: 16, frame: $0) }
        let brightest = shining.map { page in page.keys.map { HexColor($0.colorHex)!.red }.reduce(0, +) }.max()!
        let plain = still.keys.map { HexColor($0.colorHex)!.red }.reduce(0, +)
        XCTAssertGreaterThan(brightest, plain + 0.5)

        // The 15-key deck in portrait (3 wide) gets every key, one colour each.
        let deck = DeckFlow.splashPage(columns: 3, keyCount: 15, frame: 5)
        XCTAssertEqual(deck.keys.map(\.index), Array(0 ..< 15))
        XCTAssertNotNil(HexColor(deck.keys[14].colorHex))
        XCTAssertEqual(DeckFlow.splashPage(columns: 3, keyCount: 15, frame: -3).keys.count, 15, "any frame number")
    }

    func testBlend() {
        XCTAssertEqual(DeckFlow.blend("#000000", toward: "#FFFFFF", by: 0.5), "#808080")
        XCTAssertEqual(DeckFlow.blend("#207C33", toward: "#FFFFFF", by: 0), "#207C33")
        XCTAssertEqual(DeckFlow.blend("#207C33", toward: "#FFFFFF", by: 2), "#FFFFFF")
        XCTAssertEqual(DeckFlow.blend("junk", toward: "#FFFFFF", by: 1), "junk")
    }

    // MARK: Selection strip

    func testSelectionRunsAndTheTextsThatMightFit() {
        let fixtures = [901, 933, 934, 935, 936, 940, 950, 951]
        XCTAssertEqual(DeckFlow.selectionRuns(fixtures), ["901", "933-936", "940", "950-951"])
        let texts = DeckFlow.selectionTexts(fixtures)
        XCTAssertEqual(texts.first, "901, 933-936, 940, 950-951", "everything, if it fits")
        XCTAssertEqual(texts[1], "901, 933-936, 940 +2 more")
        XCTAssertEqual(texts.last, "901 +7 more")
        XCTAssertEqual(DeckFlow.selectionTexts([5]), ["5"])
        XCTAssertTrue(DeckFlow.selectionTexts([]).isEmpty)
        XCTAssertEqual(DeckFlow.selectionTexts(Array(stride(from: 1, to: 400, by: 2))).count, 40, "capped")
    }

    func testDeckStripPagesThroughTheSelection() {
        let fixtures = [901, 933, 934, 935, 936, 940, 950, 951, 960]
        let first = DeckFlow.selectionStrip(fixtures, offset: 0, slots: 3)
        XCTAssertEqual(first.labels, ["901", "933-936", "+4\nmore"])
        let second = DeckFlow.selectionStrip(fixtures, offset: first.next, slots: 3)
        XCTAssertEqual(second.labels, ["940", "950-951", "960"])
        XCTAssertEqual(second.next, 0, "back to the start")
        XCTAssertEqual(DeckFlow.selectionStrip([7], offset: 0, slots: 3).labels, ["7", "", ""])
        XCTAssertEqual(DeckFlow.selectionStrip([], offset: 0, slots: 3).labels, ["", "", ""])
        XCTAssertEqual(DeckFlow.compactSelection(fixtures), "901 +8")
        XCTAssertEqual(DeckFlow.compactSelection([3, 4, 5]), "3-5")
        XCTAssertNil(DeckFlow.compactSelection([]))
    }

    func testQuickKeysHasTheStripAndTheMenuKeyShowsTheSelection() {
        let profile = DeckProfile.makeDefault()
        let page = DeckFlow.selectionPage(profile: profile, returnTo: 0)
        XCTAssertEqual([9, 10, 11].map { page.key(at: $0)?.action },
                       [.deckChoice(.selectionStrip(0)), .deckChoice(.selectionStrip(1)), .deckChoice(.selectionStrip(2))])
        let keypad = DeckFlow.keypadPageIndex(in: profile)!
        XCTAssertEqual(DeckFlow.menuLabel(onPage: keypad, overlay: nil, profile: profile, pageName: "Keypad",
                                          hasSelection: true, selectionText: "901 +8"), "901 +8\nQuick Keys")
    }
}
