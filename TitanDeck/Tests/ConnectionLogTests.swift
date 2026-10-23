import XCTest
@testable import TitanDeck

final class ConnectionLogTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func event(_ seconds: TimeInterval, _ source: ConnectionEvent.Source, _ status: ConnectionEvent.Status,
                       _ detail: String = "") -> ConnectionEvent {
        ConnectionEvent(date: start.addingTimeInterval(seconds), source: source, status: status, detail: detail)
    }

    func testRepeatedStatesAreSkipped() {
        var log = ConnectionLog()
        XCTAssertTrue(log.record(event(0, .titan, .up)))
        XCTAssertFalse(log.record(event(2, .titan, .up)))
        XCTAssertTrue(log.record(event(4, .titan, .down)))
        XCTAssertTrue(log.record(event(5, .titan, .info, "note")))
        XCTAssertTrue(log.record(event(6, .titan, .info, "note")))
        XCTAssertFalse(log.record(event(7, .titan, .down)))
        XCTAssertTrue(log.record(event(8, .rdp, .down)), "other sources are independent")
        XCTAssertEqual(log.events.count, 5)
    }

    func testSummaryCountsDropoutsAndDowntime() {
        var log = ConnectionLog()
        log.record(event(0, .rdp, .up))
        log.record(event(100, .rdp, .down))
        log.record(event(110, .rdp, .up))      // 10 s outage
        log.record(event(200, .rdp, .down))
        log.record(event(230, .rdp, .up))      // 30 s outage
        log.record(event(0, .titan, .up))
        log.record(event(300, .titan, .down))  // still down
        let summaries = log.summaries(now: start.addingTimeInterval(320))

        let rdp = summaries.first { $0.source == .rdp }
        XCTAssertEqual(rdp?.dropouts, 2)
        XCTAssertEqual(rdp?.totalDowntime, 40)
        XCTAssertEqual(rdp?.longestOutage, 30)
        XCTAssertEqual(rdp?.stillDown, false)

        let titan = summaries.first { $0.source == .titan }
        XCTAssertEqual(titan?.dropouts, 1)
        XCTAssertEqual(titan?.totalDowntime, 20)
        XCTAssertEqual(titan?.stillDown, true)

        XCTAssertNil(summaries.first { $0.source == .deck }, "no history, no row")
    }

    func testCSVEscapingAndFormulaGuard() {
        XCTAssertEqual(ConnectionLog.csvField("plain"), "plain")
        XCTAssertEqual(ConnectionLog.csvField("a,b"), "\"a,b\"")
        XCTAssertEqual(ConnectionLog.csvField("say \"hi\", ok"), "\"say \"\"hi\"\", ok\"")
        XCTAssertEqual(ConnectionLog.csvField("=SUM(A1)"), "'=SUM(A1)")
        XCTAssertEqual(ConnectionLog.csvField("-1"), "'-1")
    }

    func testCSVLayout() {
        var log = ConnectionLog()
        log.record(event(0, .network, .up, "Ethernet"))
        let csv = log.csv(timeZone: TimeZone(identifier: "Europe/London")!)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.first, "time,source,status,detail")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].hasSuffix(",Network,up,Ethernet"))
    }

    func testCapacityKeepsNewest() {
        var log = ConnectionLog()
        for i in 0..<(ConnectionLog.capacity + 10) {
            log.record(event(TimeInterval(i), .key, .info, "\(i)"))
        }
        XCTAssertEqual(log.events.count, ConnectionLog.capacity)
        XCTAssertEqual(log.events.first?.detail, "10")
    }
}
