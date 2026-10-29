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
        var running = DeckFX.LayerState(clip: "Big Blaze")
        running.running = true
        let page = DeckFX.fxPage(profile: profile, layers: [2: running], returnTo: 0)
        XCTAssertEqual(page.keys.prefix(6).map(\.label), ["FIRE", "CANDLE", "LIGHTNING", "POLICE", "FIREWORKS", "TV"])
        XCTAssertEqual(page.key(at: 0)?.action, .deckChoice(.fxCategory("fire")))
        XCTAssertEqual(page.key(at: 6)?.label, "LAYER 1\nfader clip")
        XCTAssertEqual(page.key(at: 7)?.label, "LAYER 2\nBig Blaze")
        XCTAssertEqual(page.key(at: 7)?.colorHex, DeckProfile.goColor, "running is green")
        XCTAssertNotEqual(page.key(at: 6)?.colorHex, DeckProfile.goColor)
        XCTAssertEqual(page.key(at: 8)?.action, .deckChoice(.fxStopAll))
        XCTAssertEqual(page.key(at: 9)?.action, .deckChoice(.fxReleaseAll))
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

    func testTheLayerPageRunsTheFaders() {
        var state = DeckFX.LayerState(clip: "Table candle flicker slow")
        state.level = 0.8
        let page = DeckFX.layerPage(layer: 1, state: state, keyCount: 15)
        XCTAssertEqual(page.key(at: 0)?.label, "CLIP\nTable candl.")
        XCTAssertEqual(page.key(at: 1)?.label, "RUN")
        XCTAssertEqual(page.key(at: 2)?.label, "LEVEL\n80%")
        XCTAssertEqual(page.keys.map(\.action).compactMap { $0 }, [
            .deckChoice(.fxPickVideo), .deckChoice(.fxRun), .deckChoice(.fxFaderLevel),
            .deckChoice(.fxFixtures), .deckChoice(.fxRelease), .deckChoice(.back),
        ])
        state.running = true
        XCTAssertEqual(DeckFX.layerPage(layer: 1, state: state, keyCount: 15).key(at: 1)?.label, "STOP")
        XCTAssertEqual(DeckFX.layerPage(layer: 1, state: DeckFX.LayerState(), keyCount: 15).key(at: 2)?.label,
                       "LEVEL\n100%", "full until a level is picked")
        let level = DeckFX.faderLevelPage(layer: 1, current: 0.8, keyCount: 15)
        XCTAssertEqual(level.key(at: 8)?.colorHex, DeckProfile.goColor, "80% lit")
        XCTAssertEqual(level.key(at: 10)?.action, .deckChoice(.fxLevel(1)))
    }

    func testZones() {
        let zones = DeckFX.zones([(titanId: 10, legend: "FXZone Bar"), (titanId: 11, legend: "Backs"),
                                  (titanId: nil, legend: "FXZone lost"), (titanId: 12, legend: "fxzone-Window"),
                                  (titanId: 13, legend: "FXZone")])
        XCTAssertEqual(zones, [DeckFX.Zone(titanId: 10, name: "Bar"), DeckFX.Zone(titanId: 12, name: "Window"),
                               DeckFX.Zone(titanId: 13, name: "Zone")])
        let page = DeckFX.zonesPage(layer: 2, zones: zones, keyCount: 15)
        XCTAssertEqual(page.keys.prefix(3).map(\.label), ["Bar", "Window", "Zone"])
        XCTAssertEqual(page.key(at: 0)?.action, .deckChoice(.fxZone(titanId: 10)))
        XCTAssertEqual(DeckFX.zonesPage(layer: 2, zones: [], keyCount: 15).key(at: 0)?.label, "No FXZone\ngroups")
    }

    func testSettings() {
        var settings = DeckFX.Settings()
        XCTAssertEqual(settings.controlNames, ["Folder", "File"])
        XCTAssertEqual(settings.layer(3), DeckFX.Settings.Layer(), "no third layer")
        XCTAssertEqual(settings.layer(1).faders, [])
        settings.layers[0].prismPage = 5
        settings.layers[0].prismFader = 1
        settings.layers[0].levelPage = 5
        settings.layers[0].levelFader = 3
        XCTAssertEqual(settings.layer(1).faders, [.prism, .level], "only the ones set, in RUN's order")
        XCTAssertEqual(settings.layer(1).spot(.level)?.fader, 3)
        let defaults = UserDefaults(suiteName: "DeckFXTests")!
        defaults.removePersistentDomain(forName: "DeckFXTests")
        settings.layers[0].fixture = 901
        settings.save(defaults)
        XCTAssertEqual(DeckFX.Settings.load(defaults), settings)
    }

    func testSettingsFromBeforeTheFadersStillLoad() throws {
        let old = #"{"layers":[{"fixture":901,"group":12,"playbackPage":4,"playbackFader":2},{"fixture":0,"group":0,"playbackPage":0,"playbackFader":0}],"dimmer":"Dimmer","folder":"Folder","file":"File","speed":"Speed","contrast":"Contrast","saturation":"Saturation","levelsAsPercent":true}"#
        let settings = try JSONDecoder().decode(DeckFX.Settings.self, from: Data(old.utf8))
        XCTAssertEqual(settings.layer(1).fixture, 901)
        XCTAssertEqual(settings.layer(1).faders, [.pixelMap])
        XCTAssertEqual(settings.layer(1).prismFader, 0)
    }

    func testRunningFollowsTitansFaders() {
        var layer = DeckFX.Settings.Layer()
        func cue(_ page: Int, _ index: Int, _ active: Bool) -> CueChoice {
            CueChoice(titanId: page * 100 + index, userNumber: nil, page: page, index: index, legend: "", isActive: active)
        }
        XCTAssertNil(DeckFX.running(layer, cues: [cue(4, 0, true)]), "no faders set")
        layer.playbackPage = 5
        layer.playbackFader = 1
        layer.levelPage = 5
        layer.levelFader = 3
        XCTAssertNil(DeckFX.running(layer, cues: []), "Titan didn't list them")
        XCTAssertEqual(DeckFX.running(layer, cues: [cue(4, 0, false), cue(4, 2, false)]), false)
        XCTAssertEqual(DeckFX.running(layer, cues: [cue(4, 0, false), cue(4, 2, true)]), true, "the level fader up counts")
    }
}
