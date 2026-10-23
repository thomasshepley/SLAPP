import XCTest
@testable import TitanDeck

final class WatchCommandTests: XCTestCase {
    func testRoundTrip() {
        let command = WatchCommand(kind: .release, playback: 12)
        XCTAssertEqual(WatchCommand(message: command.message), command)
        XCTAssertEqual(command.action, .playbackRelease(userNumber: 12))
    }

    func testRejectsBadMessages() {
        XCTAssertNil(WatchCommand(message: [:]))
        XCTAssertNil(WatchCommand(message: ["command": "explode", "playback": 1]))
        XCTAssertNil(WatchCommand(message: ["command": "go", "playback": 0]))
        XCTAssertNil(WatchCommand(message: ["command": "go", "playback": "3"]))
    }

    func testReplyRoundTrip() {
        let reply = WatchReply(ok: false, milliseconds: 501, error: "timed out")
        XCTAssertEqual(WatchReply(message: reply.message), reply)
        XCTAssertEqual(WatchReply(message: [:]), WatchReply(ok: false, milliseconds: 0, error: nil))
    }
}
