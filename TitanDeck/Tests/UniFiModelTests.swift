import XCTest
@testable import TitanDeck

final class UniFiModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> [T] {
        try UniFiAPI.decoder.decode(UniFiAPI.Envelope<T>.self, from: Data(json.utf8)).data
    }

    private let deviceJSON = #"""
    {"meta":{"rc":"ok"},"data":[
      {"mac":"74:ac:b9:00:00:01","name":"Stage Left","model":"U7PROMAX","type":"uap","state":1,"version":"8.0.19",
       "ip":"192.168.1.20","num_sta":7,"spectrum_scanning":false,
       "radio_table":[{"name":"wifi0","radio":"ng","channel":"auto","ht":"20"},
                      {"name":"wifi1","radio":"na","channel":36,"ht":"80"},
                      {"name":"wifi2","radio":"6e","channel":37,"ht":160}],
       "radio_table_stats":[{"name":"wifi0","radio":"ng","channel":6,"tx_power":17,"cu_total":42,"num_sta":2,"satisfaction":-1},
                            {"name":"wifi1","radio":"na","channel":36,"tx_power":23,"cu_total":18,"num_sta":5,"satisfaction":97}],
       "vap_table":[{"essid":"SHOW","bssid":"76:ac:b9:00:00:02","radio":"na","num_sta":5}]},
      {"mac":"74:ac:b9:00:00:09","type":"usw","model":"USW24","state":1},
      {"broken": true}
    ]}
    """#

    func testDecodesDevicesAndSkipsOddOnes() throws {
        let devices = try decode(UniFiDevice.self, deviceJSON)
        XCTAssertEqual(devices.count, 2, "the entry with no mac is skipped, not fatal")
        let ap = devices[0]
        XCTAssertTrue(ap.isAccessPoint)
        XCTAssertFalse(devices[1].isAccessPoint, "a switch isn't an AP")
        XCTAssertTrue(ap.isOnline)
        XCTAssertEqual(ap.displayName, "Stage Left")
    }

    func testRadioSummaryMergesTheThreeTables() throws {
        let radios = try decode(UniFiDevice.self, deviceJSON)[0].radios
        XCTAssertEqual(radios.map(\.band), [.ghz2, .ghz5, .ghz6])
        XCTAssertEqual(radios[0].channel, 6, "'auto' in the config, 6 actually in use")
        XCTAssertEqual(radios[0].utilisation, 42)
        XCTAssertNil(radios[0].satisfaction, "-1 means unknown")
        XCTAssertEqual(radios[1].width, 80)
        XCTAssertEqual(radios[1].bssids, ["76:AC:B9:00:00:02"])
        XCTAssertEqual(radios[2].width, 160)
        XCTAssertEqual(radios[2].channel, 37)
    }

    func testStationsAndNeighbours() throws {
        let stations = try decode(UniFiStation.self, #"""
        {"data":[{"mac":"aa:bb:cc:00:00:01","hostname":"Tom-iPad","ip":"192.168.1.50","ap_mac":"74:ac:b9:00:00:01",
                  "channel":36,"radio":"na","radio_proto":"ax","signal":-58,"tx_rate":864000,"is_wired":false}]}
        """#)
        XCTAssertEqual(stations.first?.displayName, "Tom-iPad")
        XCTAssertEqual(stations.first?.band, .ghz5)

        let neighbours = try decode(UniFiNeighbour.self, #"""
        {"data":[{"bssid":"00:11:22:33:44:55","essid":"Catering","channel":11,"radio":"ng","rssi":30,"ap_mac":"x"},
                 {"bssid":"00:11:22:33:44:66","essid":"OB Truck","channel":44,"freq":5220,"signal":-71},
                 {"bssid":"00:11:22:33:44:77","channel":37,"freq":6135,"rssi":12}]}
        """#)
        XCTAssertEqual(neighbours[0].dBm, -65, "rssi is above a -95 floor")
        XCTAssertEqual(neighbours[0].wifiBand, .ghz2)
        XCTAssertEqual(neighbours[1].dBm, -71)
        XCTAssertEqual(neighbours[1].wifiBand, .ghz5, "band from frequency when radio is missing")
        XCTAssertEqual(neighbours[2].wifiBand, .ghz6)
    }

    func testSpectrumScanBothLayouts() throws {
        let modern = try decode(UniFiSpectrumScan.self, #"""
        {"data":[{"mac":"74:ac:b9:00:00:01","spectrum_scanning":false,
                  "scans":[{"radio":"na","spectrum_table_time":1792847185000,
                            "spectrum_table":[{"channel":36,"width":20,"utilization":12,"interference":3},
                                              {"channel":40,"width":"20","utilization":55.5,"interference":0}]}]}]}
        """#)
        let scan = try XCTUnwrap(modern.first)
        XCTAssertEqual(scan.entriesByBand[.ghz5]?.count, 2)
        XCTAssertEqual(scan.entriesByBand[.ghz5]?[1].utilization, 55.5)
        XCTAssertEqual(scan.lastScanned?.timeIntervalSince1970 ?? 0, 1_792_847_185, accuracy: 1, "milliseconds handled")

        let older = try decode(UniFiSpectrumScan.self, #"""
        {"data":[{"spectrum_table":[{"channel":1,"freq":2412,"utilization":30},{"channel":149,"freq":5745,"utilization":4}]}]}
        """#)
        XCTAssertEqual(older.first?.entriesByBand[.ghz2]?.first?.channel, 1)
        XCTAssertEqual(older.first?.entriesByBand[.ghz5]?.first?.channel, 149)
    }

    func testHealth() throws {
        let health = try decode(UniFiHealth.self, #"{"data":[{"subsystem":"wlan","status":"ok","num_ap":3,"num_user":14}]}"#)
        XCTAssertEqual(health.first?.numAp, 3)
    }

    // MARK: Paths

    func testPathsForBothKindsOfController() {
        XCTAssertEqual(UniFiAPI.loginPath(.unifiOS), "/api/auth/login")
        XCTAssertEqual(UniFiAPI.loginPath(.legacy), "/api/login")
        XCTAssertEqual(UniFiAPI.sitePath(.unifiOS, site: "default", "stat/device"), "/proxy/network/api/s/default/stat/device")
        XCTAssertEqual(UniFiAPI.sitePath(.legacy, site: " ", "stat/sta"), "/api/s/default/stat/sta")
        XCTAssertEqual(UniFiAPI.baseURL("192.168.1.1")?.absoluteString, "https://192.168.1.1")
        XCTAssertEqual(UniFiAPI.baseURL("http://unifi.local:8443/manage")?.absoluteString, "https://unifi.local:8443")
        XCTAssertNil(UniFiAPI.baseURL("  "))
    }

    // MARK: Channels

    func testFrequencies() {
        XCTAssertEqual(WiFiBand.ghz2.frequency(channel: 6), 2437)
        XCTAssertEqual(WiFiBand.ghz5.frequency(channel: 36), 5180)
        XCTAssertEqual(WiFiBand.ghz6.frequency(channel: 37), 6135)
    }

    func testChannelSpans() {
        XCTAssertTrue(ChannelSpan.of(band: .ghz2, channel: 1, width: 20).overlaps(ChannelSpan.of(band: .ghz2, channel: 3, width: 20)))
        XCTAssertFalse(ChannelSpan.of(band: .ghz2, channel: 1, width: 20).overlaps(ChannelSpan.of(band: .ghz2, channel: 6, width: 20)))
        XCTAssertEqual(ChannelSpan.of(band: .ghz5, channel: 44, width: 80), ChannelSpan(low: 5170, high: 5250), "36-48 block")
        XCTAssertEqual(ChannelSpan.of(band: .ghz5, channel: 157, width: 80), ChannelSpan(low: 5735, high: 5815), "149-161 block")
        XCTAssertEqual(ChannelSpan.of(band: .ghz6, channel: 37, width: 160), ChannelSpan(low: 6105, high: 6265))
        XCTAssertTrue(WiFiBand.isDFS(100))
        XCTAssertFalse(WiFiBand.isDFS(36))
    }

    func testAdvisorAvoidsLoudNeighboursAndOurOwnAPs() throws {
        let neighbours = try decode(UniFiNeighbour.self, #"""
        {"data":[{"bssid":"a","channel":1,"radio":"ng","signal":-60},{"bssid":"b","channel":11,"radio":"ng","signal":-80}]}
        """#)
        let ours = try decode(UniFiDevice.self, deviceJSON)[0].radios   // ours is on 6
        let scores = ChannelAdvisor.scores(band: .ghz2, neighbours: neighbours, ourRadios: ours)
        XCTAssertEqual(scores.map(\.channel), [11, 1, 6], "faint neighbour, then a moderate one, then sharing with our own AP")
        XCTAssertEqual(scores.first?.neighbours, 1)
    }

    func testAdvisorPrefersNonDFSWhenEquallyQuiet() {
        let scores = ChannelAdvisor.scores(band: .ghz5, neighbours: [], ourRadios: [])
        XCTAssertEqual(scores.first?.channel, 36)
        XCTAssertFalse(scores.prefix(8).contains { $0.isDFS })
    }
}
