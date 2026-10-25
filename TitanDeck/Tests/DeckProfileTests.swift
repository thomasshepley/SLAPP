import XCTest
@testable import TitanDeck

final class DeckProfileTests: XCTestCase {
    func testPlaybackWallFor32Keys() {
        let profile = DeckProfile.makePlaybackWall()
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

    func testPlaybackWallReflowsForSmallDeck() {
        let profile = DeckProfile.makePlaybackWall(keyCount: 15)
        XCTAssertEqual(profile.pages[0].keys.count, 15)
        XCTAssertEqual(profile.pages[0].key(at: 13)?.action, .playbackGo(userNumber: 14))
        XCTAssertEqual(profile.pages[0].key(at: 14)?.action, .switchPage(1))
    }

    func testKeyIndexesAreUniquePerPage() {
        for page in DeckProfile.makePlaybackWall().pages {
            XCTAssertEqual(Set(page.keys.map(\.index)).count, page.keys.count)
        }
    }

    func testCodableRoundTrip() throws {
        var profile = DeckProfile.makePlaybackWall()
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

    // MARK: - Shipped default (15-key portrait keypad)

    func testDefaultIsPortraitKeypad() {
        let profile = DeckProfile.makeDefault()
        XCTAssertEqual(profile.keyCount, 15)
        XCTAssertEqual(profile.orientation, .portraitClockwise)
        XCTAssertEqual(profile.gridColumns, 3)
        XCTAssertEqual(profile.pages.map(\.name), ["Keypad", "Quick Keys", "Colour", "Playbacks", "Layouts"])

        let keypad = profile.pages[0]
        let expected: [Int: TitanAction] = [
            0: .keypadDigit(1), 1: .keypadDigit(2), 2: .keypadDigit(3),
            3: .keypadDigit(4), 4: .keypadDigit(5), 5: .keypadDigit(6),
            6: .keypadDigit(7), 7: .keypadDigit(8), 8: .keypadDigit(9),
            9: .keypadExit, 10: .keypadDigit(0), 11: .keypadEnter,
            12: .keypadClear, 13: .mainMenu, 14: .keypadAt,
        ]
        for (index, action) in expected {
            XCTAssertEqual(keypad.key(at: index)?.action, action, "key \(index)")
        }
        XCTAssertEqual(keypad.key(at: 13)?.sfSymbol, DeckProfile.menuSymbol)
    }

    func testIntensityAndPlaybackPages() {
        let profile = DeckProfile.makeDefault()
        let intensity = profile.pages[1]
        XCTAssertEqual((0...5).map { intensity.key(at: $0)?.action },
                       [1, 5, 10, -1, -5, -10].map { TitanAction.adjustIntensity(percent: $0) })
        XCTAssertEqual(intensity.key(at: 13)?.action, .mainMenu)
        let colour = profile.pages[2]
        XCTAssertEqual((0...8).map { colour.key(at: $0)?.action },
                       DeckFlow.cctPresets.map { TitanAction.colourTemperature(kelvin: $0) })
        XCTAssertEqual(colour.key(at: 13)?.action, .mainMenu)
        let playbacks = profile.pages[3]
        XCTAssertEqual(playbacks.key(at: 0)?.action, .cueGo(slot: 0))
        XCTAssertEqual(playbacks.key(at: 5)?.action, .cueFade(slot: 2, fadeOut: false))
        XCTAssertEqual(playbacks.key(at: 6)?.action, .cueFade(slot: 0, fadeOut: true))
        XCTAssertEqual(playbacks.key(at: 10)?.action, .connectCue)
        XCTAssertEqual(playbacks.key(at: 13)?.action, .mainMenu)
    }

    func testEveryDefaultPageHasMenu() {
        for count in [6, 8, 15, 32] {
            for orientation in DeckOrientation.allCases {
                let profile = DeckProfile.makeDefault(keyCount: count, orientation: orientation)
                for page in profile.pages {
                    XCTAssertTrue(page.keys.contains { $0.action == .mainMenu }, "\(count) \(orientation) \(page.name)")
                    XCTAssertTrue(page.keys.allSatisfy { $0.index >= 0 && $0.index < count })
                    XCTAssertEqual(Set(page.keys.map(\.index)).count, page.keys.count)
                }
            }
        }
    }

    func testOldProfilesWithoutOrientationStillLoad() throws {
        let json = """
        {"id":"7B0E8C35-1D1B-4C61-9B0F-63E1B7D0F7C1","name":"Old","keyCount":15,"pages":[],"isBuiltInDefault":false}
        """
        let profile = try JSONDecoder().decode(DeckProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.orientation, .landscape)
        XCTAssertEqual(profile.name, "Old")
    }
}
