import XCTest
@testable import TitanDeck

final class ConnectionHealthTests: XCTestCase {
    func testBackoffSequence() {
        let policy = ReconnectPolicy()
        XCTAssertEqual((1...7).map { policy.delay(forAttempt: $0) }, [1, 2, 4, 8, 10, 10, 10])
        XCTAssertEqual(policy.delay(forAttempt: 0), 1)
        XCTAssertEqual(policy.delay(forAttempt: 500), 10)
    }

    func testHeartbeatNeedsTwoMissesToGoDown() {
        var tracker = HeartbeatTracker()
        XCTAssertEqual(tracker.health, .unknown)
        tracker.record(milliseconds: 12)
        XCTAssertEqual(tracker.health, .ok(milliseconds: 12))
        tracker.record(milliseconds: nil)
        XCTAssertEqual(tracker.health, .ok(milliseconds: 12), "one miss keeps the last good state")
        tracker.record(milliseconds: nil)
        XCTAssertEqual(tracker.health, .down)
        tracker.record(milliseconds: 300)
        XCTAssertEqual(tracker.health, .slow(milliseconds: 300))
        XCTAssertTrue(tracker.health.isReachable)
        tracker.reset()
        XCTAssertEqual(tracker.health, .unknown)
        XCTAssertFalse(tracker.health.isReachable)
    }
}
