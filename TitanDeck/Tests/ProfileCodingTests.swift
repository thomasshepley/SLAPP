import XCTest
@testable import TitanDeck

final class ProfileCodingTests: XCTestCase {
    func testRoundTripMarksProfileAsHandMade() throws {
        var profile = DeckProfile.makeDefault()
        profile.name = "Show A"
        let decoded = try ProfileCoding.decode(ProfileCoding.encode(profile))
        XCTAssertEqual(decoded.name, "Show A")
        XCTAssertEqual(decoded.pages, profile.pages)
        XCTAssertFalse(decoded.isBuiltInDefault)
    }

    func testRejectsGarbageAndEmptyProfiles() throws {
        XCTAssertThrowsError(try ProfileCoding.decode(Data("{}".utf8)))
        var profile = DeckProfile.makeDefault()
        profile.pages = []
        XCTAssertThrowsError(try ProfileCoding.decode(ProfileCoding.encode(profile)))
    }

    func testDropsKeysOutsideTheDeck() throws {
        var profile = DeckProfile.makeDefault(keyCount: 15)
        profile.pages[0].keys.append(KeyDefinition(index: 40, label: "Ghost"))
        let decoded = try ProfileCoding.decode(ProfileCoding.encode(profile))
        XCTAssertNil(decoded.pages[0].key(at: 40))
        XCTAssertEqual(decoded.pages[0].keys.count, 15)
    }

    func testPlaybackUserNumber() {
        XCTAssertEqual(TitanAction.playbackGo(userNumber: 3).playbackUserNumber, 3)
        XCTAssertEqual(TitanAction.setFaderLevel(userNumber: 7, level: 0.5).playbackUserNumber, 7)
        XCTAssertNil(TitanAction.runMacro(id: "x").playbackUserNumber)
    }
}
