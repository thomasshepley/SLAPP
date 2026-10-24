// Tests/DeckCuesTests.swift
import XCTest
@testable import TitanDeck

final class DeckCuesTests: XCTestCase {
    private func cue(_ id: Int, page: Int, index: Int, _ legend: String = "", active: Bool = false) -> CueChoice {
        CueChoice(titanId: id, userNumber: nil, page: page, index: index, legend: legend, isActive: active)
    }

    func testGoAndFadeKeysReadTheirCue() {
        var profile = DeckProfile.makeDefault()
        let go = KeyDefinition(index: 0, label: "", action: .cueGo(slot: 0))
        let fadeIn = KeyDefinition(index: 3, label: "", action: .cueFade(slot: 0, fadeOut: false))
        XCTAssertEqual(DeckCues.displayed(go, slots: profile.cueSlots).label, "GO 1\n-")
        XCTAssertEqual(DeckCues.displayed(fadeIn, slots: profile.cueSlots).label, "FADE IN\n-")

        profile.assign(cue(501, page: 2, index: 4, "Sunset").ref, toSlot: 0)
        XCTAssertEqual(DeckCues.displayed(go, slots: profile.cueSlots).label, "GO\nSunset")
        XCTAssertEqual(DeckCues.displayed(fadeIn, slots: profile.cueSlots).label, "FADE IN\n?", "not set from the deck yet")
        profile.recordFade(2.5, fadeOut: false, onSlot: 0)
        XCTAssertEqual(DeckCues.displayed(fadeIn, slots: profile.cueSlots).label, "FADE IN\n2.5s")

        profile.assign(cue(502, page: 0, index: 0).ref, toSlot: 0)
        XCTAssertEqual(profile.cueSlots.count, 1, "a slot holds one cue")
        XCTAssertEqual(profile.cue(onSlot: 0)?.title, "P1 / 1", "no legend: page and position")
        profile.unassignSlot(0)
        XCTAssertNil(profile.cue(onSlot: 0))
    }

    func testConnectPageTurnsGOsRedAndOffersUnassign() throws {
        var profile = DeckProfile.makeDefault()
        profile.assign(cue(501, page: 0, index: 0, "Fire").ref, toSlot: 1)
        let playbacks = try XCTUnwrap(profile.pages.first { $0.name == "Playbacks" })
        let connect = DeckCues.connectPage(from: playbacks, slots: profile.cueSlots)
        XCTAssertEqual(connect.key(at: 0)?.action, .deckChoice(.assignSlot(0)))
        XCTAssertEqual(connect.key(at: 0)?.colorHex, DeckCues.assignColour)
        XCTAssertEqual(connect.key(at: 1)?.label, "PICK\nFire")
        XCTAssertNil(connect.key(at: 3), "slot 1 is empty, nothing to unassign")
        XCTAssertEqual(connect.key(at: 4)?.action, .deckChoice(.unassignSlot(1)))
        XCTAssertEqual(connect.key(at: 10)?.action, .deckChoice(.done), "Connect Cue becomes Done")
    }

    func testPagesThenCues() {
        let cues = [cue(1, page: 0, index: 1), cue(2, page: 0, index: 0, "Wash"), cue(3, page: 5, index: 9, active: true)]
        let pages = DeckCues.pagesPage(cues: cues, keyCount: 15, first: 0)
        XCTAssertEqual(pages.keys.map(\.label), ["PAGE 1\n2 cues", "PAGE 6\n1 cue", "BACK"])
        XCTAssertEqual(pages.key(at: 1)?.action, .deckChoice(.titanPage(5)))
        XCTAssertEqual(pages.key(at: 14)?.action, .deckChoice(.back))

        let onPage = DeckCues.cuesPage(cues: cues, page: 0, keyCount: 15)
        XCTAssertEqual(onPage.key(at: 0)?.label, "Wash", "in position order")
        XCTAssertEqual(onPage.key(at: 1)?.action, .deckChoice(.pickCue(titanId: 1)))
        XCTAssertEqual(DeckCues.cuesPage(cues: cues, page: 5, keyCount: 15).key(at: 0)?.colorHex, DeckProfile.goColor,
                       "live cues are green")
    }

    func testSixtyPagesScrollWithMore() {
        let cues = (0 ..< 60).map { cue($0 + 1, page: $0, index: 0) }
        let first = DeckCues.pagesPage(cues: cues, keyCount: 15, first: 0)
        XCTAssertEqual(first.keys.filter { if case .deckChoice(.titanPage) = $0.action { true } else { false } }.count, 13)
        XCTAssertEqual(first.key(at: 13)?.action, .deckChoice(.morePages(from: 13)))
        let last = DeckCues.pagesPage(cues: cues, keyCount: 15, first: 52)
        XCTAssertEqual(last.key(at: 0)?.label, "PAGE 53\n1 cue")
        XCTAssertEqual(last.key(at: 13)?.action, .deckChoice(.morePages(from: 0)), "wraps back to the start")
        XCTAssertEqual(DeckCues.pagesPage(cues: [], keyCount: 15, first: 0).name, "No cues from Titan")
    }

    func testFadePicker() {
        let page = DeckCues.fadePage(current: 5, fadeOut: false, keyCount: 15)
        XCTAssertEqual(page.keys.count, 13, "12 times and Back")
        XCTAssertEqual(page.key(at: 5)?.label, "5s")
        XCTAssertEqual(page.key(at: 5)?.colorHex, DeckProfile.goColor, "the current time stands out")
        XCTAssertEqual(page.key(at: 1)?.action, .deckChoice(.fadeTime(0.5)))
    }

    func testFlashFadeRules() {
        let rules = [FlashFadeRule(from: 1, to: 99, seconds: 5), FlashFadeRule(from: 300, to: 200, seconds: 2)]
        XCTAssertEqual(DeckCues.flashFade(forFixture: 45, rules: rules), 5)
        XCTAssertEqual(DeckCues.flashFade(forFixture: 250, rules: rules), 2, "a backwards range still works")
        XCTAssertNil(DeckCues.flashFade(forFixture: 102, rules: rules), "no rule: snap")
        XCTAssertNil(DeckCues.flashFade(forFixture: nil, rules: rules), "nothing selected on the deck")
        let data = try? JSONEncoder().encode(rules)
        XCTAssertEqual(DeckCues.decodeRules(data), rules)
        XCTAssertEqual(DeckCues.decodeRules(nil), [])

        var keypad = DeckFlow.KeypadBuffer()
        for action: TitanAction in [.keypadDigit(4), .keypadDigit(5)] { _ = keypad.apply(action) }
        XCTAssertEqual(keypad.apply(.keypadEnter), .selected)
        XCTAssertEqual(keypad.selection, 45)
    }

    func testSelectionOffersFlash() {
        let page = DeckFlow.selectionPage(profile: DeckProfile.makeDefault(), returnTo: 0)
        XCTAssertEqual(page.keys.first { $0.action == .flashSelection }?.index, 7, "after CCT")
    }

    func testProfilesKeepTheirCuesAndOldOnesLoad() throws {
        var profile = DeckProfile.makeDefault()
        profile.assign(cue(9, page: 1, index: 2, "Rain").ref, toSlot: 2)
        let again = try JSONDecoder().decode(DeckProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(again.cue(onSlot: 2)?.legend, "Rain")
        XCTAssertEqual(DeckProfile.starting(from: profile).cue(onSlot: 2)?.titanId, 9,
                       "refreshing the default keeps connected cues")

        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(DeckProfile.makeDefault())) as! [String: Any]
        json.removeValue(forKey: "cueSlots")
        let old = try JSONDecoder().decode(DeckProfile.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.cueSlots, [])
    }

    func testNewTitanCalls() {
        let host = "10.0.0.5"
        XCTAssertEqual(TitanEndpoints.url(for: .fireHandle(titanId: 77), host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Playbacks/FirePlaybackAtLevel?handle_titanId=77&level_level=1&alwaysRefire=false")
        XCTAssertEqual(TitanEndpoints.selectFirstCueURL(titanId: 77, host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Playbacks/Editor/CueSelection/SelectCueByNumber?handle_titanId=77&cueNumber=1")
        XCTAssertEqual(TitanEndpoints.cueFadePropertyURL(fadeOut: true, write: true, host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/set/2/Playbacks/Editor/Times/CueFadeOutTime")
        XCTAssertEqual(TitanEndpoints.setDimmerLevelURL(percent: 0, host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Programmer/Editor/Fixtures/SetDimmerLevel?level=0")
        XCTAssertEqual(TitanEndpoints.releaseSelectionURL(seconds: 5, host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Programmer/Editor/Fixtures/ClearSelectedControls?release=true&releaseTime=5")
        for action: TitanAction in [.cueGo(slot: 0), .cueFade(slot: 1, fadeOut: true), .connectCue, .flashSelection,
                                    .deckChoice(.done)] {
            XCTAssertFalse(action.isRemote, action.summary)
            XCTAssertNil(TitanEndpoints.url(for: action, host: host))
        }
        for action: TitanAction in [.cueGo(slot: 2), .cueFade(slot: 0, fadeOut: true), .connectCue, .flashSelection] {
            XCTAssertEqual(ActionDraft(action: action).action, action)
        }
    }
}
