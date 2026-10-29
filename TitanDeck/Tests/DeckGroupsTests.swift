import XCTest
@testable import TitanDeck

final class DeckGroupsTests: XCTestCase {
    func testSetsStartOnGroupsPageTwo() {
        let settings = DeckGroups.Settings()
        XCTAssertEqual(settings.names.count, 3)
        XCTAssertEqual(settings.titanPage(0), 1)
        XCTAssertEqual(settings.titanPage(2), 3)
        var moved = settings
        moved.firstPage = 5
        XCTAssertEqual(moved.titanPage(1), 5)
    }

    func testChosenSetIsRememberedAndChecked() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "DeckGroupsTests"))
        defaults.removePersistentDomain(forName: "DeckGroupsTests")
        var settings = DeckGroups.Settings()
        settings.names = ["Rig", "Floor", "Audience", "Spare"]
        settings.chosen = 3
        settings.save(defaults)
        let loaded = DeckGroups.Settings.load(defaults)
        XCTAssertEqual(loaded, settings)
        XCTAssertEqual(loaded.current, 3)
        var fewer = loaded
        fewer.names = ["Rig"]
        XCTAssertNil(fewer.current)
    }

    func testBlankNamesFallBack() {
        var settings = DeckGroups.Settings()
        settings.names[1] = "  "
        XCTAssertEqual(settings.name(1), "Set 2")
        XCTAssertEqual(settings.name(7), "Set 8")
    }

    func testSetsPageLightsTheOneInUse() {
        var settings = DeckGroups.Settings()
        settings.chosen = 1
        let page = DeckGroups.setsPage(settings: settings, keyCount: 15)
        XCTAssertEqual(page.keys.count, 4)
        XCTAssertEqual(page.keys[1].colorHex, DeckProfile.goColor)
        XCTAssertEqual(page.keys[1].action, .deckChoice(.pickGroupSet(1)))
        XCTAssertEqual(page.keys.last?.index, 14)
        XCTAssertEqual(page.keys.last?.action, .deckChoice(.back))
    }

    func testGroupsPageHasGroupsThenSetAndBack() {
        let groups = (1 ... 20).map { DeckGroups.Group(titanId: 100 + $0, name: "G\($0)") }
        let page = DeckGroups.groupsPage(set: 0, settings: DeckGroups.Settings(), groups: groups, keyCount: 15)
        XCTAssertEqual(page.keys.count, 15)
        XCTAssertEqual(page.keys[0].action, .deckChoice(.pickGroup(titanId: 101)))
        XCTAssertEqual(page.keys[12].action, .deckChoice(.pickGroup(titanId: 113)))
        XCTAssertEqual(page.keys[13].action, .deckChoice(.changeGroupSet))
        XCTAssertEqual(page.keys[14].action, .deckChoice(.back))
    }

    func testGroupsPageWhileLoadingAndWhenEmpty() {
        let settings = DeckGroups.Settings()
        let loading = DeckGroups.groupsPage(set: 1, settings: settings, groups: nil, keyCount: 15)
        XCTAssertEqual(loading.keys[0].label, "Loading...")
        XCTAssertNil(loading.keys[0].action)
        let empty = DeckGroups.groupsPage(set: 1, settings: settings, groups: [], keyCount: 15)
        XCTAssertEqual(empty.keys[0].label, "No groups on\nGroups page 3")
    }

    func testGroupsFromHandles() {
        let groups = DeckGroups.groups([
            (titanId: 7, legend: " Front wash ", index: 0),
            (titanId: nil, legend: "Ghost", index: 1),
            (titanId: 9, legend: "", index: 4),
        ])
        XCTAssertEqual(groups, [DeckGroups.Group(titanId: 7, name: "Front wash"), DeckGroups.Group(titanId: 9, name: "Group 5")])
    }
}
