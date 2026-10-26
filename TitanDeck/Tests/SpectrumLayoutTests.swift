import XCTest
@testable import TitanDeck

final class SpectrumLayoutTests: XCTestCase {
    func testOverlappingRadiosGetTheirOwnLanes() {
        // Two APs on the same channel, one further up the band.
        let lanes = SpectrumLayout.lanes([0 ... 100, 10 ... 90, 200 ... 260])
        XCTAssertEqual(lanes, [0, 1, 0], "the same channel goes underneath; one clear of both shares the top lane")
        XCTAssertEqual(SpectrumLayout.lanes([0 ... 50, 52 ... 80], gap: 6), [0, 1], "too close to share")
        XCTAssertEqual(SpectrumLayout.lanes([0 ... 50, 60 ... 80], gap: 6), [0, 0])
        XCTAssertEqual(SpectrumLayout.lanes([200 ... 260, 0 ... 100]), [0, 0], "placed left to right whatever the order")
        XCTAssertEqual(SpectrumLayout.lanes([]), [])
    }

    func testLabelsThatWouldTouchAreDropped() {
        // Channel 1, 6 and 11 matter most; 2-5 squeezed between them are dropped.
        let centres: [Double] = [10, 20, 30, 40, 50, 60]
        let widths = Array(repeating: 14.0, count: 6)
        let kept = SpectrumLayout.thinned(centres: centres, widths: widths, priority: [2, 0, 0, 0, 0, 2], gap: 4)
        XCTAssertTrue(kept.isSuperset(of: [0, 5]))
        for a in kept { for b in kept where a < b { XCTAssertGreaterThanOrEqual(abs(centres[a] - centres[b]), 14 + 4) } }
        XCTAssertEqual(SpectrumLayout.thinned(centres: [3], widths: [20], priority: [2], limit: 100), [], "would hang off the edge")
        XCTAssertEqual(SpectrumLayout.thinned(centres: [95], widths: [20], priority: [2], limit: 100), [])
    }

    func testTheAxisLeadsWithTheChannelsPeopleLookFor() {
        let two = SpectrumLayout.axisChannels(.ghz2)
        XCTAssertEqual(two.filter { $0.priority == 2 }.map(\.channel), [1, 6, 11])
        XCTAssertEqual(two.count, 13)
        let five = SpectrumLayout.axisChannels(.ghz5)
        XCTAssertEqual(five.filter { $0.priority == 2 }.map(\.channel), [36, 52, 100, 149])
        XCTAssertEqual(five.map(\.channel), WiFiBand.ghz5.candidateChannels)
    }

    func testOurRadiosThatShareAirtimeAreFlagged() {
        let stage = ChannelSpan.of(band: .ghz5, channel: 36, width: 80)
        let foh = ChannelSpan.of(band: .ghz5, channel: 44, width: 20)
        let dimmers = ChannelSpan.of(band: .ghz5, channel: 149, width: 80)
        let clashes = SpectrumLayout.clashes([("Stage", stage), ("FOH", foh), ("Dimmers", dimmers)])
        XCTAssertEqual(clashes.count, 1)
        XCTAssertEqual(clashes.first?.0, "Stage")
        XCTAssertEqual(clashes.first?.1, "FOH")
        XCTAssertTrue(SpectrumLayout.clashes([("Stage", stage), ("Stage", stage)]).isEmpty, "one AP's own radio isn't a clash")
    }

    func testPositionsAndLoudness() {
        let domain = SpectrumLayout.domain(.ghz2)
        XCTAssertEqual(SpectrumLayout.x(domain.lowerBound, in: domain, width: 300), 0)
        XCTAssertEqual(SpectrumLayout.x(domain.upperBound, in: domain, width: 300), 300)
        XCTAssertEqual(SpectrumLayout.loudness(dBm: -95), 0)
        XCTAssertEqual(SpectrumLayout.loudness(dBm: -20), 1)
        XCTAssertEqual(SpectrumLayout.loudness(dBm: -62), 0.5, accuracy: 0.01)
    }
}
