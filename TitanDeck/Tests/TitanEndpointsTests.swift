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

    // MARK: - Keypad and intensity

    func testKeypadDigitsAndAt() {
        XCTAssertEqual(TitanEndpoints.url(for: .keypadDigit(7), host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Command/AppendStringAndPreview?text=7")
        XCTAssertEqual(TitanEndpoints.url(for: .keypadAt, host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Command/AppendStringAndPreview?text=%40")
    }

    func testKeypadExitHasNoQuery() {
        XCTAssertEqual(TitanEndpoints.url(for: .keypadExit, host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Menu/ExitRootOrLatched")
    }

    func testIntensityNudge() {
        XCTAssertEqual(TitanEndpoints.url(for: .adjustIntensity(percent: -5), host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Programmer/Editor/Fixtures/IncrementDimmer?value=-204.8&timeDelta=1&shiftEnabled=false")
        XCTAssertEqual(TitanEndpoints.url(for: .adjustIntensity(percent: 10), host: host)
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems?.first?.value, "409.6",
                       "10% of Titan's 4096-step wheel")
    }

    func testMultiStepAndLocalActionsHaveNoSingleURL() {
        XCTAssertNil(TitanEndpoints.url(for: .keypadEnter, host: host))
        XCTAssertNil(TitanEndpoints.url(for: .keypadClear, host: host))
        XCTAssertNil(TitanEndpoints.url(for: .mainMenu, host: host))
    }

    func testCommandLineURLs() {
        XCTAssertEqual(TitanEndpoints.commandLineTextURL(host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/get/2/Command/CommandLineText")
        XCTAssertEqual(TitanEndpoints.runCommandURL("1 @ 5", host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Command/RunCommand?command=1%20%40%205")
        XCTAssertEqual(TitanEndpoints.startNewCommandURL(host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Command/StartNewCommand")
        XCTAssertEqual(TitanEndpoints.clearProgrammerURL(host: host)?.absoluteString,
                       "http://10.0.0.1:4430/titan/script/2/Programmer/Editor/ClearAll?presets=false&allProgrammers=false")
    }

    func testLatchingGoReleasesByTitanId() throws {
        let url = try XCTUnwrap(TitanEndpoints.url(for: .releaseHandle(titanId: 1688), host: "10.0.0.5"))
        XCTAssertEqual(url.path, "/titan/script/2/Playbacks/ReleasePlayback")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "handle_titanId" }?.value, "1688")
        XCTAssertEqual(query.first { $0.name == "useMasterReleaseTime" }?.value, "true")
        XCTAssertTrue(TitanAction.releaseHandle(titanId: 1688).isRemote)
        XCTAssertEqual(TitanEndpoints.url(for: .releaseHandle(titanId: 1), host: "10.0.0.5", port: TitanEndpoints.viaHostPort)?.port, 4436)
    }

    func testTitansErrorTextIsKept() {
        XCTAssertNil(TitanClient.errorText(status: 200, body: Data("ok".utf8)))
        XCTAssertEqual(TitanClient.errorText(status: 500, body: Data("  Unknown function Command.AppendStringAndPreview \n".utf8)),
                       "HTTP 500: Unknown function Command.AppendStringAndPreview")
        XCTAssertEqual(TitanClient.errorText(status: 500, body: Data()), "HTTP 500")
        XCTAssertEqual(TitanClient.errorText(status: 404, body: Data("<html><body>Not found</body></html>".utf8)), "HTTP 404")
        XCTAssertEqual(TitanClient.errorText(status: 500, body: Data(String(repeating: "x", count: 1000).utf8))?.count, 310)
    }

    // MARK: Cue times (Titan 19's AcwTimeSpan)

    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    func testTimeSpanTextIsDotNets() {
        XCTAssertEqual(TitanTimeSpan.timeSpanText(0.3), "00:00:00.3000000")
        XCTAssertEqual(TitanTimeSpan.timeSpanText(2), "00:00:02")
        XCTAssertEqual(TitanTimeSpan.timeSpanText(90.25), "00:01:30.2500000")
    }

    func testTimesAreWrittenInTitansOwnShape() {
        func shaped(_ current: String) -> String? {
            TitanTimeSpan.shaped(seconds: 0.3, like: Data(current.utf8)).map(text)
        }
        XCTAssertEqual(shaped(#""00:00:02""#), #""00:00:00.3000000""#)
        XCTAssertEqual(shaped(#"{"Seconds":2,"Infinite":false}"#), #"{"Infinite":false,"Seconds":0.3}"#)
        XCTAssertEqual(shaped(#"{"Ticks":20000000}"#), #"{"Ticks":3000000}"#)
        XCTAssertEqual(shaped(#"{"Time":"00:00:02","IsDefault":true}"#), #"{"IsDefault":true,"Time":"00:00:00.3000000"}"#)
        XCTAssertEqual(shaped(#"{"Milliseconds":2000}"#), #"{"Milliseconds":300}"#)
        XCTAssertEqual(shaped("2"), "0.3")
        XCTAssertNil(shaped(#"{"Name":"Cue 1"}"#), "nothing time-like: no shape to copy")
        XCTAssertNil(shaped("not json"))
    }

    func testTitansShapeComesFirstThenTheLikelyOnes() {
        let bodies = TitanTimeSpan.bodies(seconds: 0.3, current: Data(#"{"Seconds":2}"#.utf8)).map(text)
        XCTAssertEqual(bodies, [#"{"Seconds":0.3}"#, #""00:00:00.3000000""#, "0.3"], "duplicates dropped")
        XCTAssertEqual(TitanTimeSpan.bodies(seconds: 1, current: nil).map(text),
                       [#""00:00:01""#, #"{"Seconds":1}"#, "1"])
    }
}
