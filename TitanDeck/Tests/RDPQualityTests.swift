import XCTest
@testable import TitanDeck

final class RDPQualityTests: XCTestCase {
    func testPresetsRoundTrip() {
        for preset in RDPQuality.Preset.allCases {
            XCTAssertEqual(RDPQuality.preset(preset).preset, preset)
        }
        var custom = RDPQuality.preset(.best)
        custom.pcImageQuality = .lossless
        XCTAssertNil(custom.preset, "edited settings are custom")
    }

    func testPresetsMatchTheHost() {
        // Must match RdpServerQuality.For in TitanDeckHost/src/Core/Rdp/RdpQuality.cs.
        XCTAssertEqual(RDPQuality.preset(.best).pcSettings, .init(imageQuality: .high, profile: .automatic, frameRate: 60))
        XCTAssertEqual(RDPQuality.preset(.balanced).pcSettings, .init(imageQuality: .medium, profile: .automatic, frameRate: 30))
        XCTAssertEqual(RDPQuality.preset(.weakSignal).pcSettings, .init(imageQuality: .low, profile: .minimumBandwidth, frameRate: 30))
    }

    func testVisualsAreFreeRDPConnectionTypes() {
        XCTAssertEqual(RDPQuality.Visuals.full.connectionType, 6)      // CONNECTION_TYPE_LAN
        XCTAssertEqual(RDPQuality.Visuals.reduced.connectionType, 4)   // BROADBAND_HIGH
        XCTAssertEqual(RDPQuality.Visuals.minimal.connectionType, 2)   // BROADBAND_LOW
    }

    func testHostRequestAndReply() throws {
        let request = RDPQuality.preset(.weakSignal).hostRequest
        let json = String(data: try JSONEncoder().encode(request), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains(#""imageQuality":"low""#))
        XCTAssertTrue(json.contains(#""profile":"minimumBandwidth""#))
        let reply = try JSONDecoder().decode(HostRdpQuality.self, from: Data(
            #"{"imageQuality":"high","profile":"automatic","frameRate":60,"preset":"best"}"#.utf8))
        XCTAssertEqual(RDPQuality.pcSettings(from: reply), RDPQuality.preset(.best).pcSettings)
        XCTAssertNil(RDPQuality.pcSettings(from: HostRdpQuality(imageQuality: "ultra", profile: "automatic", frameRate: 30)))
    }

    func testOldSettingsLoadWithBestQuality() throws {
        let old = #"{"host":"10.0.0.5","port":3389,"username":"titan","domain":"","connectOnLaunch":false}"#
        let settings = try JSONDecoder().decode(RDPSettings.self, from: Data(old.utf8))
        XCTAssertEqual(settings.quality, .preset(.best))
        var changed = settings
        changed.quality = .preset(.weakSignal)
        let back = try JSONDecoder().decode(RDPSettings.self, from: JSONEncoder().encode(changed))
        XCTAssertEqual(back.quality.preset, .weakSignal)
    }

    func testSummaryReadsPlainly() {
        XCTAssertEqual(RDPQuality.preset(.best).summary, "High quality, 60 fps, all effects")
        XCTAssertEqual(RDPQuality.preset(.weakSignal).summary, "Low quality, 30 fps, lowest bandwidth, plain Windows")
    }
}
