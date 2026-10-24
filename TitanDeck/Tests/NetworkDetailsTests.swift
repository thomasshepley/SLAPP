// Tests/NetworkDetailsTests.swift
import XCTest
@testable import TitanDeck

final class NetworkDetailsTests: XCTestCase {
    // MARK: InterfaceAddress

    func testParsesDottedQuads() {
        XCTAssertEqual(InterfaceAddress.parse("192.168.0.147"), 0xC0A8_0093)
        XCTAssertEqual(InterfaceAddress.parse(" 10.0.0.1 "), 0x0A00_0001)
        XCTAssertNil(InterfaceAddress.parse("titan-pc"))
        XCTAssertNil(InterfaceAddress.parse("192.168.0"))
        XCTAssertNil(InterfaceAddress.parse("192.168.0.256"))
        XCTAssertNil(InterfaceAddress.parse("192..0.1"))
    }

    func testSameSubnet() {
        let mask = "255.255.255.0"
        XCTAssertEqual(InterfaceAddress.sameSubnet(address: "192.168.0.23", netmask: mask, as: "192.168.0.147"), true)
        XCTAssertEqual(InterfaceAddress.sameSubnet(address: "192.168.1.23", netmask: mask, as: "192.168.0.147"), false)
        XCTAssertEqual(InterfaceAddress.sameSubnet(address: "10.0.1.5", netmask: "255.255.0.0", as: "10.0.200.9"), true)
        XCTAssertNil(InterfaceAddress.sameSubnet(address: "192.168.0.23", netmask: mask, as: "titan-pc"))
    }

    func testReadsLoopbackAddress() {
        #if canImport(Darwin)
        let loopback = "lo0"
        #else
        let loopback = "lo"
        #endif
        let address = InterfaceAddress.ipv4(interface: loopback)
        XCTAssertEqual(address?.address, "127.0.0.1")
        XCTAssertEqual(address?.netmask, "255.0.0.0")
        XCTAssertNil(InterfaceAddress.ipv4(interface: "no-such-interface"))
    }

    // MARK: LatencySummary

    func testLatencySummary() {
        let summary = LatencySummary(samples: [10, nil, 20, 14, nil])
        XCTAssertEqual(summary.replies, 3)
        XCTAssertEqual(summary.misses, 2)
        XCTAssertEqual(summary.fastest, 10)
        XCTAssertEqual(summary.slowest, 20)
        XCTAssertEqual(summary.average, 15)        // 44 / 3 = 14.67
        XCTAssertEqual(summary.jitter, 8)          // (10 + 6) / 2
        XCTAssertEqual(summary.lossPercent, 40)
    }

    func testLatencySummaryEdgeCases() {
        let empty = LatencySummary(samples: [])
        XCTAssertNil(empty.average)
        XCTAssertNil(empty.jitter)
        XCTAssertEqual(empty.lossPercent, 0)

        let allMissed = LatencySummary(samples: [nil, nil])
        XCTAssertEqual(allMissed.lossPercent, 100)
        XCTAssertNil(allMissed.fastest)

        let one = LatencySummary(samples: [7])
        XCTAssertEqual(one.average, 7)
        XCTAssertNil(one.jitter)
    }
}
