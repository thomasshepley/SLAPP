import XCTest
@testable import TitanDeck

/// Expected URLs are copied from the Avolites Titan v19.2 API docs examples.
final class TitanEndpointsTests: XCTestCase {
    private let host = "10.0.0.1"

    func testPlaybackGo() {
        XCTAssertEqual(TitanEndpoints.url(for: .playbackGo(userNumber: 6), host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Playbacks/FirePlaybackAtLevel?handle_userNumber=6&level_level=1&alwaysRefire=false")
    }

    func testPlaybackRelease() {
        XCTAssertEqual(TitanEndpoints.url(for: .playbackRelease(userNumber: 6), host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Playbacks/ReleasePlayback?handle_userNumber=6&fadeTime=0&useMasterReleaseTime=true")
    }

    func testFaderLevel() {
        XCTAssertEqual(TitanEndpoints.url(for: .setFaderLevel(userNumber: 3, level: 0.5), host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Playbacks/SetPlaybackLevel?srcHandle_userNumber=3&level_level=0.5")
    }

    func testMacroIdIsEscaped() {
        XCTAssertEqual(TitanEndpoints.url(for: .runMacro(id: "My Macro&1+="), host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Macros/Run?macroId=My%20Macro%261%2B%3D")
    }

    func testRawPath() {
        XCTAssertEqual(TitanEndpoints.url(for: .raw(path: "/Playbacks/KillPlayback?handle_userNumber=2"), host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Playbacks/KillPlayback?handle_userNumber=2")
    }

    func testLocalActionsHaveNoURL() {
        XCTAssertNil(TitanEndpoints.url(for: .switchPage(1), host: host))
        XCTAssertNil(TitanEndpoints.url(for: .openSettings, host: host))
    }

    func testEmptyHostHasNoURL() {
        XCTAssertNil(TitanEndpoints.url(for: .playbackGo(userNumber: 1), host: "  "))
    }

    func testHostIsTrimmed() {
        XCTAssertEqual(TitanEndpoints.url(for: .playbackGo(userNumber: 1), host: " 10.0.0.1 \n")?.host, "10.0.0.1")
    }

    func testSoftwareVersionURL() {
        XCTAssertEqual(TitanEndpoints.softwareVersionURL(host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/get/System/SoftwareVersion")
    }

    func testLevelFormatting() {
        XCTAssertEqual(TitanEndpoints.format(level: 1), "1")
        XCTAssertEqual(TitanEndpoints.format(level: 0), "0")
        XCTAssertEqual(TitanEndpoints.format(level: 0.5), "0.5")
        XCTAssertEqual(TitanEndpoints.format(level: 0.333333), "0.333")
        XCTAssertEqual(TitanEndpoints.format(level: 1.7), "1")
        XCTAssertEqual(TitanEndpoints.format(level: -0.2), "0")
    }
}
