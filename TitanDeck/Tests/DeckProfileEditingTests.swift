import XCTest
@testable import TitanDeck

final class DeckProfileEditingTests: XCTestCase {
    func testGridColumnsMatchDecks() {
        XCTAssertEqual(DeckProfile.gridColumns(forKeyCount: 32), 8)
        XCTAssertEqual(DeckProfile.gridColumns(forKeyCount: 15), 5)
        XCTAssertEqual(DeckProfile.gridColumns(forKeyCount: 8), 4)
        XCTAssertEqual(DeckProfile.gridColumns(forKeyCount: 6), 3)
        XCTAssertEqual(DeckProfile.gridColumns(forKeyCount: 10), 4)
    }

    func testAddPageHasNextPageKeyAndClearsDefaultFlag() {
        var profile = DeckProfile.makeDefault()
        let index = profile.addPage()
        XCTAssertEqual(index, 2)
        XCTAssertEqual(profile.pages[2].name, "Page 3")
        XCTAssertEqual(profile.pages[2].key(at: 31)?.action, .nextPage)
        XCTAssertFalse(profile.isBuiltInDefault)
    }

    func testRemovePageRemapsLinks() {
        var profile = DeckProfile.makeDefault()   // page 0 -> 1, page 1 -> 0
        profile.addPage()                          // page 2
        profile.setKey(KeyDefinition(index: 0, label: "To 3", action: .switchPage(2)), onPage: 0)
        profile.removePage(at: 1)

        XCTAssertEqual(profile.pages.count, 2)
        // Page 0's page key pointed at the removed page, so it falls back to next page.
        XCTAssertEqual(profile.pages[0].key(at: 31)?.action, .nextPage)
        // The link to old page 2 now points at its new index, 1.
        XCTAssertEqual(profile.pages[0].key(at: 0)?.action, .switchPage(1))
    }

    func testLastPageCannotBeRemoved() {
        var profile = DeckProfile.makeDefault()
        profile.removePage(at: 1)
        profile.removePage(at: 0)
        XCTAssertEqual(profile.pages.count, 1)
    }

    func testMovePageKeepsLinksPointingAtSamePages() {
        var profile = DeckProfile.makeDefault()
        profile.addPage(named: "Third")
        let releaseID = profile.pages[1].id
        profile.movePage(from: 1, to: 2)   // Go, Third, Release

        XCTAssertEqual(profile.pages.map(\.name), ["Go", "Third", "Release"])
        XCTAssertEqual(profile.pages[2].id, releaseID)
        // Go's page key still points at Release, now index 2.
        XCTAssertEqual(profile.pages[0].key(at: 31)?.action, .switchPage(2))
        // Release's page key still points at Go, index 0.
        XCTAssertEqual(profile.pages[2].key(at: 31)?.action, .switchPage(0))
    }

    func testDuplicatePageGetsFreshIDsAndShiftsLinks() {
        var profile = DeckProfile.makeDefault()
        let copyIndex = profile.duplicatePage(at: 0)
        XCTAssertEqual(copyIndex, 1)
        XCTAssertEqual(profile.pages.count, 3)
        XCTAssertEqual(profile.pages[1].name, "Go copy")
        XCTAssertNotEqual(profile.pages[1].id, profile.pages[0].id)
        XCTAssertNotEqual(profile.pages[1].keys[0].id, profile.pages[0].keys[0].id)
        // Release moved from 1 to 2; links to it follow.
        XCTAssertEqual(profile.pages[0].key(at: 31)?.action, .switchPage(2))
        XCTAssertEqual(profile.pages[1].key(at: 31)?.action, .switchPage(2))
    }

    func testSetKeyReplacesAndSorts() {
        var profile = DeckProfile.makeDefault()
        profile.setKey(KeyDefinition(index: 20, label: "New"), onPage: 0)
        profile.setKey(KeyDefinition(index: 0, label: "Replaced", action: .playbackGo(userNumber: 40)), onPage: 0)
        let keys = profile.pages[0].keys
        XCTAssertEqual(keys.map(\.index), keys.map(\.index).sorted())
        XCTAssertEqual(profile.pages[0].key(at: 0)?.label, "Replaced")
        XCTAssertEqual(profile.pages[0].keys.filter { $0.index == 0 }.count, 1)
        XCTAssertEqual(profile.pages[0].key(at: 20)?.label, "New")
    }

    func testSetKeyOutsideDeckIsIgnored() {
        var profile = DeckProfile.makeDefault()
        let before = profile
        profile.setKey(KeyDefinition(index: 32, label: "Off the edge"), onPage: 0)
        XCTAssertEqual(profile.pages, before.pages)
    }

    func testClearKey() {
        var profile = DeckProfile.makeDefault()
        profile.clearKey(at: 0, onPage: 0)
        XCTAssertNil(profile.pages[0].key(at: 0))
    }

    func testRenameIgnoresBlank() {
        var profile = DeckProfile.makeDefault()
        profile.renamePage(at: 0, to: "  Act 1 ")
        XCTAssertEqual(profile.pages[0].name, "Act 1")
        profile.renamePage(at: 0, to: "   ")
        XCTAssertEqual(profile.pages[0].name, "Act 1")
    }
}
