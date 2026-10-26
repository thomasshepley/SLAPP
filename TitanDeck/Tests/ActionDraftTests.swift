import XCTest
@testable import TitanDeck

final class ActionDraftTests: XCTestCase {
    func testRoundTripsEveryAction() {
        let actions: [TitanAction] = [
            .playbackGo(userNumber: 3),
            .playbackRelease(userNumber: 4),
            .setFaderLevel(userNumber: 5, level: 0.25),
            .runMacro(id: "abc"),
            .switchPage(2),
            .nextPage,
            .previousPage,
            .openSettings,
            .raw(path: "Playbacks/KillAllPlaybacks"),
            .keypadDigit(7),
            .keypadAt,
            .keypadEnter,
            .keypadExit,
            .keypadClear,
            .keypadThro,
            .adjustIntensity(percent: -10),
            .mainMenu,
        ]
        for action in actions {
            XCTAssertEqual(ActionDraft(action: action).action, action)
        }
        XCTAssertNil(ActionDraft(action: nil).action)
    }

    func testSwitchingKindKeepsPlaybackNumber() {
        var draft = ActionDraft(action: .playbackGo(userNumber: 12))
        draft.kind = .release
        XCTAssertEqual(draft.action, .playbackRelease(userNumber: 12))
    }

    func testIncompleteDraftsHaveNoAction() {
        var draft = ActionDraft(action: nil)
        draft.kind = .macro
        draft.macroId = "   "
        XCTAssertNil(draft.action)
        draft.kind = .raw
        XCTAssertNil(draft.action)
    }

    func testValuesAreClamped() {
        var draft = ActionDraft(action: nil)
        draft.kind = .fader
        draft.playback = 0
        draft.level = 1.4
        XCTAssertEqual(draft.action, .setFaderLevel(userNumber: 1, level: 1))
    }

    func testHexStringRoundTrip() {
        XCTAssertEqual(HexColor("#1e7d32")?.hexString, "#1E7D32")
        XCTAssertEqual(HexColor(red: 1, green: 0.5, blue: 0).hexString, "#FF8000")
        XCTAssertEqual(HexColor(red: 2, green: -1, blue: 0).hexString, "#FF0000")
    }
}
