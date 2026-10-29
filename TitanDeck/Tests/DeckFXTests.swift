import XCTest
@testable import TitanDeck

final class DeckFXTests: XCTestCase {
    private let fire = DeckFX.Item(id: UUID(), title: "Big Blaze", category: .fire, folder: 2, file: 5)
    private let candle = DeckFX.Item(id: UUID(), title: "Table candle flicker slow", category: .candle, folder: 3, file: 1)

    func testFXIsOnTheMenuOnlyInTestMode() {
        let profile = DeckProfile.makeDefault()
        XCTAssertFalse(DeckFlow.menuPage(profile: profile).keys.contains { $0.action == .deckChoice(.openFX) })
        let menu = DeckFlow.menuPage(profile: profile, fx: true)
        XCTAssertTrue(menu.keys.contains { $0.action == .deckChoice(.openFX) && $0.label == "FX" })
        XCTAssertTrue(menu.keys.contains { $0.action == .deckChoice(.openSlates) }, "Slates still there")
    }

    func testTheFXPageHasTheSixKindsAndBothLayers() {
        let profile = DeckProfile.makeDefault()
        let page = DeckFX.fxPage(profile: profile, layers: [2: DeckFX.LayerState(clip: "Big Blaze")], returnTo: 0)
        XCTAssertEqual(page.keys.prefix(6).map(\.label), ["FIRE", "CANDLE", "LIGHTNING", "POLICE", "FIREWORKS", "TV"])
        XCTAssertEqual(page.key(at: 0)?.action, .deckChoice(.fxCategory("fire")))
        XCTAssertEqual(page.key(at: 6)?.label, "LAYER 1\n-")
        XCTAssertEqual(page.key(at: 7)?.label, "LAYER 2\nBig Blaze")
        XCTAssertEqual(page.key(at: 8)?.action, .deckChoice(.fxReleaseAll))
        XCTAssertTrue(page.keys.contains { $0.action == .mainMenu }, "a way back")
    }

    func testVersionsAreTheKindsEffectsWithBack() {
        let page = DeckFX.versionsPage(category: .fire, items: [fire, candle], keyCount: 15)
        XCTAssertEqual(page.keys.count, 2)
        XCTAssertEqual(page.key(at: 0)?.label, "Big Blaze")
        XCTAssertEqual(page.key(at: 0)?.action, .deckChoice(.fxItem(fire.id.uuidString)))
        XCTAssertEqual(page.key(at: 14)?.action, .deckChoice(.back))
        let none = DeckFX.versionsPage(category: .tv, items: [fire], keyCount: 15)
        XCTAssertEqual(none.key(at: 0)?.label, "No TV\nin FX tab")
    }

    func testTheLayerPageShowsWhatTheDeckSet() {
        var state = DeckFX.LayerState(clip: "Table candle flicker slow")
        state.levels[.brightness] = 0.8
        let page = DeckFX.layerPage(layer: 1, state: state, keyCount: 15)
        XCTAssertEqual(page.key(at: 0)?.label, "L1\nTable candl.")
        XCTAssertEqual(page.key(at: 1)?.label, "BRIGHT\n80%")
        XCTAssertEqual(page.key(at: 2)?.label, "SPEED\n-")
        XCTAssertEqual(page.key(at: 2)?.action, .deckChoice(.fxControl("speed")))
        XCTAssertEqual(page.keys.map(\.action).compactMap { $0 }, [
            .deckChoice(.fxPickVideo), .deckChoice(.fxControl("brightness")), .deckChoice(.fxControl("speed")),
            .deckChoice(.fxControl("contrast")), .deckChoice(.fxControl("saturation")), .deckChoice(.fxGo),
            .deckChoice(.fxStop), .deckChoice(.fxFixtures), .deckChoice(.fxRelease), .deckChoice(.back),
        ])
        let level = DeckFX.levelPage(layer: 1, control: .brightness, current: 0.8, keyCount: 15)
        XCTAssertEqual(level.key(at: 8)?.colorHex, DeckProfile.goColor, "80% lit")
        XCTAssertEqual(level.key(at: 10)?.action, .deckChoice(.fxLevel(1)))
    }

    func testFixturesAndZones() {
        let zones = DeckFX.zones([(titanId: 10, legend: "FXZone Bar"), (titanId: 11, legend: "Backs"),
                                  (titanId: nil, legend: "FXZone lost"), (titanId: 12, legend: "fxzone-Window"),
                                  (titanId: 13, legend: "FXZone")])
        XCTAssertEqual(zones, [DeckFX.Zone(titanId: 10, name: "Bar"), DeckFX.Zone(titanId: 12, name: "Window"),
                               DeckFX.Zone(titanId: 13, name: "Zone")])
        let page = DeckFX.fixturesPage(layer: 2, zones: zones, keyCount: 15)
        XCTAssertEqual(page.keys.prefix(4).map(\.label), ["USE SEL", "ADD", "REMOVE", "Bar"])
        XCTAssertEqual(page.key(at: 3)?.action, .deckChoice(.fxZone(titanId: 10)))
    }

    func testSettings() {
        var settings = DeckFX.Settings()
        XCTAssertEqual(settings.value(0.55), 55)
        XCTAssertEqual(settings.value(1.4), 100, "never past full")
        settings.levelsAsPercent = false
        XCTAssertEqual(settings.value(0.5), 0.5)
        XCTAssertEqual(settings.controlName(.brightness), "Dimmer")
        XCTAssertEqual(settings.layer(3), DeckFX.Settings.Layer(), "no third layer")
        let defaults = UserDefaults(suiteName: "DeckFXTests")!
        defaults.removePersistentDomain(forName: "DeckFXTests")
        settings.layers[0].fixture = 901
        settings.save(defaults)
        XCTAssertEqual(DeckFX.Settings.load(defaults), settings)
    }
}
