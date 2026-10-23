import XCTest
@testable import TitanDeck

final class DeckProfileTests: XCTestCase {
    func testDefaultProfileFor32Keys() {
        let profile = DeckProfile.makeDefault()
        XCTAssertEqual(profile.keyCount, 32)
        XCTAssertTrue(profile.isBuiltInDefault)
        XCTAssertEqual(profile.pages.count, 2)

        let go = profile.pages[0]
        XCTAssertEqual(go.keys.count, 17)
        XCTAssertEqual(go.key(at: 0)?.action, .playbackGo(userNumber: 1))
        XCTAssertEqual(go.key(at: 15)?.action, .playbackGo(userNumber: 16))
        XCTAssertNil(go.key(at: 16))
        XCTAssertEqual(go.key(at: 31)?.action, .switchPage(1))

        let release = profile.pages[1]
        XCTAssertEqual(release.key(at: 0)?.action, .playbackRelease(userNumber: 1))
        XCTAssertEqual(release.key(at: 15)?.action, .playbackRelease(userNumber: 16))
        XCTAssertEqual(release.key(at: 31)?.action, .switchPage(0))
    }

    func testDefaultProfileReflowsForSmallDeck() {
        let profile = DeckProfile.makeDefault(keyCount: 15)
        XCTAssertEqual(profile.pages[0].keys.count, 15)
        XCTAssertEqual(profile.pages[0].key(at: 13)?.action, .playbackGo(userNumber: 14))
        XCTAssertEqual(profile.pages[0].key(at: 14)?.action, .switchPage(1))
    }

    func testKeyIndexesAreUniquePerPage() {
        for page in DeckProfile.makeDefault().pages {
            XCTAssertEqual(Set(page.keys.map(\.index)).count, page.keys.count)
        }
    }

    func testCodableRoundTrip() throws {
        var profile = DeckProfile.makeDefault()
        profile.pages[0].keys[0].action = .setFaderLevel(userNumber: 4, level: 0.75)
        profile.pages[0].keys[1].action = .runMacro(id: "abc")
        profile.pages[0].keys[2].action = .raw(path: "Playbacks/KillAllPlaybacks")
        profile.pages[0].keys[3].action = .openSettings
        let data = try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(DeckProfile.self, from: data), profile)
    }

    func testHexColor() {
        XCTAssertEqual(HexColor("#FF8000"), HexColor("ff8000"))
        XCTAssertEqual(HexColor("#FF8000")?.red, 1)
        XCTAssertEqual(HexColor("#000080")?.blue ?? 0, 128.0 / 255, accuracy: 0.0001)
        XCTAssertNil(HexColor("#12345"))
        XCTAssertNil(HexColor("zzzzzz"))
    }
}
