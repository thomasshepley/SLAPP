// Tests/DeskLinkTests.swift
import XCTest
@testable import TitanDeck

final class TitanSelectionParserTests: XCTestCase {
    private func ids(_ text: String) -> [Int]? { TitanSelectionParser.titanIds(from: Data(text.utf8)) }

    func testReadsEveryLikelyShapeOfTheSelection() {
        XCTAssertEqual(ids("[1689, 1690]"), [1689, 1690])
        XCTAssertEqual(ids(#"[{"titanId":1689},{"TitanId":1700}]"#), [1689, 1700])
        XCTAssertEqual(ids(#"{"value":[5,6]}"#), [5, 6])
        XCTAssertEqual(ids(#""1689,1690""#), [1689, 1690])
        XCTAssertEqual(ids("1689"), [1689])
        XCTAssertEqual(ids("[]"), [], "nothing selected")
        XCTAssertEqual(ids(""), [], "an empty answer is an empty selection")
        XCTAssertNil(ids("<html>error</html>"), "junk isn't an empty selection")
    }

    func testMapsTitanIdsToUserNumbers() {
        let handles = [PlaybackHandleState(titanId: 5001, userNumber: 1, active: false, legend: ""),
                       PlaybackHandleState(titanId: 5002, userNumber: nil, active: false, legend: ""),
                       PlaybackHandleState(titanId: nil, userNumber: 3, active: false, legend: "")]
        XCTAssertEqual(TitanSelectionParser.userNumbers(handles), [5001: 1])
    }

    func testReadsAnAddressHoweverTitanWritesIt() {
        func address(_ text: String) -> DmxAddress? { DmxAddress.parse(Data(text.utf8)) }
        XCTAssertEqual(address(#"{"Universe":2,"Address":101}"#), DmxAddress(universe: 2, address: 101))
        XCTAssertEqual(address(#"{"universe":"3","startAddress":"7"}"#), DmxAddress(universe: 3, address: 7))
        XCTAssertEqual(address(#"{"value":{"Universe":1,"Channel":12}}"#), DmxAddress(universe: 1, address: 12))
        XCTAssertEqual(address(#""2.101""#), DmxAddress(universe: 2, address: 101))
        XCTAssertEqual(address("2/101"), DmxAddress(universe: 2, address: 101))
        XCTAssertEqual(address("U4 1"), DmxAddress(universe: 4, address: 1))
        XCTAssertEqual(address("513"), DmxAddress(universe: 2, address: 1), "one absolute channel")
        XCTAssertEqual(address("12"), DmxAddress(universe: 1, address: 12))
        XCTAssertNil(address("2.600"), "past the end of a universe")
        XCTAssertEqual(address("2.101"), DmxAddress(universe: 2, address: 101), "unquoted: JSON would make it 2.101 the number")
        XCTAssertNil(address(""))
        XCTAssertNil(address(#"{"name":"Spot"}"#))
    }

    func testNewEndpoints() {
        let host = "10.0.0.5"
        XCTAssertEqual(TitanEndpoints.selectedFixtureIdsURL(host: host, port: 4434)?.absoluteString,
                       "http://10.0.0.5:4434/titan/script/2/Selection/Context/Global/GetAllSelectedFixtureIds")
        let select = TitanEndpoints.selectFixturesURL(userNumbers: [1, 2, 3], host: host)
        XCTAssertEqual(select?.path, "/titan/script/2/Selection/Context/Global/SelectFixturesFromHandles")
        XCTAssertEqual(select.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first { $0.name == "handleList_userNumberList" }?.value, "1,2,3")
        XCTAssertNil(TitanEndpoints.selectFixturesURL(userNumbers: [], host: host))
        XCTAssertEqual(TitanEndpoints.flashOutURL(host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Programmer/Editor/Fixtures/FlashOut")
        XCTAssertEqual(TitanEndpoints.clearFlashURL(host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Programmer/Editor/Fixtures/ClearFlash")
        XCTAssertEqual(TitanEndpoints.addressFromSelectionURL(host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Patch/Repatch/SetDmxAddressesFromSelectedFixture")
        XCTAssertEqual(TitanEndpoints.currentDmxAssignmentURL(host: host)?.absoluteString,
                       "http://10.0.0.5:4430/titan/get/2/Patch/CurrentDmxAssignment")
    }
}

final class IntensityLearningTests: XCTestCase {
    private func universe(_ set: [Int: Int]) -> [Int] {
        var levels = [Int](repeating: 0, count: 512)
        for (address, level) in set { levels[address - 1] = level }
        return levels
    }

    func testANudgeFindsTheDimmer() {
        // Fixture 4 (R, G, B, Dim at 13-16): only its dimmer moves.
        let before: IntensityLearning.Snapshot = [1: universe([13: 255, 14: 180, 15: 120, 16: 100]), 2: universe([1: 50])]
        let after: IntensityLearning.Snapshot = [1: universe([13: 255, 14: 180, 15: 120, 16: 113]), 2: universe([1: 50])]
        let slots = IntensityLearning.channels(before: before, after: after, rising: true)
        XCTAssertEqual(slots, [DmxSlot(universe: 1, address: 16)])
        XCTAssertEqual(IntensityLearning.level(of: slots!, in: after)!, 113.0 / 255, accuracy: 0.001)
    }

    func testAFlashDownFindsItToo() {
        let before: IntensityLearning.Snapshot = [1: universe([16: 200])]
        let after: IntensityLearning.Snapshot = [1: universe([16: 0])]
        XCTAssertEqual(IntensityLearning.channels(before: before, after: after, rising: false), [DmxSlot(universe: 1, address: 16)])
        XCTAssertNil(IntensityLearning.channels(before: before, after: after, rising: true), "it went the wrong way")
    }

    func testNothingOrTooMuchMovingLearnsNothing() {
        let still: IntensityLearning.Snapshot = [1: universe([16: 200])]
        XCTAssertNil(IntensityLearning.channels(before: still, after: still, rising: true), "already at 0, or not patched")
        XCTAssertNil(IntensityLearning.channels(before: still, after: [1: universe([16: 201])], rising: true), "jitter")
        // A cue fading 20 channels at the same time: can't tell which is ours.
        let busy = Dictionary(uniqueKeysWithValues: (1 ... 20).map { ($0, 100) })
        let busier = Dictionary(uniqueKeysWithValues: (1 ... 20).map { ($0, 150) })
        XCTAssertNil(IntensityLearning.channels(before: [1: universe(busy)], after: [1: universe(busier)], rising: true))
        // Two things going the other way: not just the deck's nudge.
        XCTAssertNil(IntensityLearning.channels(before: [1: universe([16: 100, 30: 90, 40: 90])],
                                                after: [1: universe([16: 120, 30: 10, 40: 10])], rising: true))
    }

    func testAPatchAddressNarrowsTheSearch() {
        let before: IntensityLearning.Snapshot = [1: universe([16: 100, 300: 100])]
        let after: IntensityLearning.Snapshot = [1: universe([16: 140, 300: 160])]
        XCTAssertEqual(IntensityLearning.channels(before: before, after: after, rising: true,
                                                  near: DmxAddress(universe: 1, address: 13)),
                       [DmxSlot(universe: 1, address: 16)], "channel 300 is another fixture's")
    }

    func testSixteenBitAndRGBFixtures() {
        // Coarse up, fine down: a 16-bit dimmer. The coarse channel is the level.
        let before: IntensityLearning.Snapshot = [1: universe([20: 100, 21: 200])]
        let after: IntensityLearning.Snapshot = [1: universe([20: 128, 21: 30])]
        let coarse = IntensityLearning.channels(before: before, after: after, rising: true)
        XCTAssertEqual(coarse, [DmxSlot(universe: 1, address: 20)], "one channel going the other way is allowed")
        let pair = [DmxSlot(universe: 1, address: 20), DmxSlot(universe: 1, address: 21)]
        XCTAssertEqual(IntensityLearning.level(of: pair, in: [1: universe([20: 128, 21: 255])])!, 128.0 / 255, accuracy: 0.001)
        // RGB with no dimmer: the brightest colour.
        let rgb = [DmxSlot(universe: 1, address: 1), DmxSlot(universe: 1, address: 2), DmxSlot(universe: 1, address: 3)]
        XCTAssertEqual(IntensityLearning.level(of: rgb, in: [1: universe([1: 40, 2: 200, 3: 90])])!, 200.0 / 255, accuracy: 0.001)
        XCTAssertNil(IntensityLearning.level(of: rgb, in: [2: universe([:])]), "universe not heard")
    }

    func testWhichActionsTeachIt() {
        XCTAssertEqual(IntensityLearning.direction(of: .adjustIntensity(percent: 5)), true)
        XCTAssertEqual(IntensityLearning.direction(of: .adjustIntensity(percent: -10)), false)
        XCTAssertEqual(IntensityLearning.direction(of: .dimmerFlash(down: true, seconds: nil)), false)
        XCTAssertEqual(IntensityLearning.direction(of: .dimmerFlash(down: false, seconds: 5)), true)
        XCTAssertNil(IntensityLearning.direction(of: .keypadEnter))
        XCTAssertNil(IntensityLearning.direction(of: .adjustIntensity(percent: 0)))
    }
}

final class DeskSelectionFlowTests: XCTestCase {
    func testTheDeskSelectionBringsUpAndPutsAwayTheIntensityKeys() {
        var follower = DeckFlow.SelectionFollower()
        XCTAssertEqual(follower.update([]), .none)
        XCTAssertEqual(follower.update([101]), .show, "selected in Layouts")
        XCTAssertEqual(follower.update([101]), .none, "the same selection, polled again")
        XCTAssertEqual(follower.update([101, 102]), .show, "added to it")
        XCTAssertEqual(follower.update([]), .hide, "cleared on the desk")
        XCTAssertEqual(follower.update([]), .none)
    }

    func testSelectionLabels() {
        XCTAssertNil(DeckFlow.selectionLabel([]))
        XCTAssertEqual(DeckFlow.selectionLabel([101]), "101")
        XCTAssertEqual(DeckFlow.selectionLabel(Array(101 ... 110)), "101-110")
        XCTAssertEqual(DeckFlow.selectionLabel([101, 105, 107]), "101, 105, 107")
        XCTAssertEqual(DeckFlow.selectionLabel([1, 2, 3, 7, 9, 11, 12]), "1-3, 7 +3", "9, 11 and 12 not shown")
    }

    func testTheFlashKeyShowsTheLevel() {
        XCTAssertEqual(DeckFlow.flashLabel(level: nil), "HOLD\nFOR 0%")
        XCTAssertEqual(DeckFlow.flashLabel(level: 0.754), "75%\nHOLD 0%")
        XCTAssertEqual(DeckFlow.flashLabel(level: 1.2), "100%\nHOLD 0%")
        let page = DeckFlow.selectionPage(profile: DeckProfile.makeDefault(), returnTo: 0)
        XCTAssertEqual(page.keys.first { $0.action == .flashSelection }?.label, DeckFlow.flashLabel(level: nil),
                       "the selection page's flash key is the one that gets the level")
    }
}
