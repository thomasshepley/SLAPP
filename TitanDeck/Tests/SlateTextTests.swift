import XCTest
@testable import TitanDeck

final class SlateTextTests: XCTestCase {
    private func entry(_ id: Int, _ kind: String, _ slate: String, _ take: Int, changes: [HostLookChange] = [],
                       night: Bool = false) -> HostSlateEntry {
        HostSlateEntry(id: id, time: Date(timeIntervalSince1970: Double(id) * 60), kind: kind, slate: slate, take: take,
                       night: night, fx: false, changes: changes, note: nil)
    }

    func testTheDayGroupsBySlateThenTakeNewestFirst() {
        let dim = HostLookChange(fixture: 101, what: "Dimmer", before: 60, after: 45)
        let day = [
            entry(1, "slate", "112", 1),
            entry(2, "change", "112", 1, changes: [dim]),
            entry(3, "take", "112", 2),
            entry(4, "change", "112", 2, changes: [dim]),
            entry(5, "change", "112", 2, changes: [dim]),
            entry(6, "slate", "112A", 1, night: true),
        ]
        let slates = SlateText.grouped(day)
        XCTAssertEqual(slates.map(\.slate), ["112A", "112"])
        XCTAssertTrue(slates[0].night)
        XCTAssertEqual(slates[1].takes.map(\.take), [2, 1])
        XCTAssertEqual(slates[1].takes[0].changes.map(\.id), [4, 5])
        XCTAssertEqual(slates[1].takes[0].start?.id, 3)
        XCTAssertEqual(slates[1].takes[1].all.map(\.id), [1, 2])
    }

    func testADayStartedMidSlateStillGroups() {
        let slates = SlateText.grouped([entry(7, "change", "90", 3)])
        XCTAssertEqual(slates.count, 1)
        XCTAssertNil(slates[0].takes[0].start)
        XCTAssertEqual(slates[0].takes[0].changes.count, 1)
    }

    func testChangesReadPlainly() {
        XCTAssertEqual(SlateText.describe(HostLookChange(fixture: 101, what: "Dimmer", before: 60, after: 45.1)), "101 Dimmer 60 → 45.1%")
        XCTAssertEqual(SlateText.describe(HostLookChange(fixture: nil, what: "U1.40", before: 19.6, after: 0)), "U1.40 19.6 → 0%")
        let worst = SlateText.worstFirst([
            HostLookChange(fixture: 2, what: "Dimmer", before: 50, after: 52),
            HostLookChange(fixture: 1, what: "Dimmer", before: 0, after: 100),
        ])
        XCTAssertEqual(worst.map(\.fixture), [1, 2])
        XCTAssertEqual(SlateText.slateKey(HostSlateState(slate: "112A", take: 3, night: true, fx: false)), "SL\n112A")
        XCTAssertEqual(SlateText.takeKey(nil), "TK\n-")
        XCTAssertEqual(SlateText.summary(HostSlateState(slate: "112A", take: 3, night: true, fx: true)), "Slate 112A · Take 3 · Night · FX")
    }

    func testTheHostsSlateBookDecodes() throws {
        let json = """
        {"day":"2026-10-27","state":{"slate":"112A","take":1,"night":true,"fx":true},
         "entries":[{"id":1,"time":"2026-10-27T09:12:29.5488532+00:00","kind":"slate","slate":"112","take":1,"night":false,"fx":false,"changes":[],"note":null},
                    {"id":2,"time":"2026-10-27T09:20:01+00:00","kind":"change","slate":"112","take":1,"night":false,"fx":false,
                     "changes":[{"fixture":null,"what":"U1.1","before":60,"after":45.1}],"note":"less"}],
         "days":["2026-10-27"],"listening":true,"patched":0,"problem":null}
        """
        let book = try HostAPI.decoder.decode(HostSlateBook.self, from: Data(json.utf8))
        XCTAssertEqual(book.state.slate, "112A")
        XCTAssertEqual(book.entries.count, 2)
        XCTAssertEqual(book.entries[1].changes.first?.after, 45.1)
        XCTAssertEqual(book.entries[1].note, "less")
    }

    func testTheMainMenuLeadsToTheSlatePage() {
        let profile = DeckProfile.makeDefault()
        let menu = DeckFlow.menuPage(profile: profile)
        XCTAssertTrue(menu.keys.contains { $0.action == .deckChoice(.openSlates) })
        XCTAssertEqual(Set(menu.keys.map(\.index)).count, menu.keys.count, "no two keys on one spot")
        let slate = DeckFlow.slatePage(profile: profile, returnTo: 0)
        let choices = slate.keys.compactMap { key -> DeckChoice? in
            if case .deckChoice(let choice)? = key.action { choice } else { nil }
        }
        XCTAssertEqual(choices, [.slateShow(0), .slateShow(1), .slateNight, .slateNew, .slateTake, .slateFx, .slateLetter])
        XCTAssertTrue(slate.keys.contains { $0.action == .mainMenu && $0.index == 13 }, "Return to Keypad where Menu is")
    }

    func testSlateKeysShowWhatsShowing() {
        let page = DeckFlow.slatePage(profile: DeckProfile.makeDefault(), returnTo: 0)
        let state = HostSlateState(slate: "112A", take: 3, night: true, fx: true)
        let shown = page.keys.map { DeckFlow.slateKey($0, state: state) }
        XCTAssertEqual(shown.first { $0.action == .deckChoice(.slateShow(0)) }?.label, "SL\n112A")
        XCTAssertEqual(shown.first { $0.action == .deckChoice(.slateShow(1)) }?.label, "TK\n3")
        XCTAssertEqual(shown.first { $0.action == .deckChoice(.slateNight) }?.label, "NIGHT")
        XCTAssertEqual(shown.first { $0.action == .deckChoice(.slateFx) }?.label, "FX ON")
    }
}
