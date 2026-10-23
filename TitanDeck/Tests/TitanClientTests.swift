import XCTest
@testable import TitanDeck

final class TitanClientTests: XCTestCase {
    func testNoHostFailsWithoutNetwork() async {
        let result = await TitanClient(host: "").perform(.playbackGo(userNumber: 1))
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, "No Titan host set")
    }

    func testLocalActionIsNotSent() async {
        let result = await TitanClient(host: "10.0.0.1").perform(.switchPage(1))
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, "Local action")
    }

    func testDefaultTimeoutIsHalfASecond() async {
        let timeout = await TitanClient(host: "10.0.0.1").timeout
        XCTAssertEqual(timeout, 0.5)
    }

    /// Nothing listens on port 1, so this must fail rather than hang a key for
    /// URLSession's 60 s default. The bound is loose because shared CI
    /// simulators can take seconds to resume a finished request.
    func testUnreachableHostFailsWithoutHanging() async {
        let client = TitanClient(host: "127.0.0.1", port: 1)
        let result = await client.perform(.playbackGo(userNumber: 1))
        XCTAssertFalse(result.ok)
        XCTAssertLessThan(result.milliseconds, 15_000)
    }
}
