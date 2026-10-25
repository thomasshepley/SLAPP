import XCTest
@testable import TitanDeck

/// The JSON here is what TitanDeck Host 0.1.0 actually sent (captured from
/// the service), so a change on the .NET side that breaks the iPad shows up.
final class HostAPITests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try HostAPI.decoder.decode(type, from: Data(json.utf8))
    }

    func testDecodesHello() throws {
        let hello = try decode(HostHello.self,
                               #"{"name":"TitanDeck Host","machineName":"TITAN-PC","hostVersion":"0.1.0","apiVersion":1,"paired":false}"#)
        XCTAssertEqual(hello.machineName, "TITAN-PC")
        XCTAssertEqual(hello.apiVersion, 1)
        XCTAssertFalse(hello.paired)
    }

    func testDecodesPairResponse() throws {
        let pair = try decode(HostPairResponse.self,
                              #"{"token":"cg8aFSX4sPhk7BjW_4pyfpLPN1X_LF5hfS2qhuZTR_0","hostName":"TITAN-PC","deviceId":"b9eb1b690e424863a0bb90dda2d3ba99"}"#)
        XCTAssertEqual(pair.hostName, "TITAN-PC")
        XCTAssertEqual(pair.token.count, 43)
    }

    func testDecodesStatusWithNullFixes() throws {
        let status = try decode(HostStatus.self, #"""
        {"overall":"problem","checks":[
          {"id":"allowed","title":"Remote Desktop allowed","state":"problem","detail":"Windows is set to refuse remote connections.","fix":"AllowRemoteDesktop","fixTitle":"Turn on"},
          {"id":"defender","title":"Windows Defender","state":"warning","detail":"No exclusion.","fix":"AddDefenderExclusion","fixTitle":"Add exclusion"},
          {"id":"titan","title":"Titan","state":"warning","detail":"Titan isn't running.","fix":null,"fixTitle":null}],
         "edition":"Core","windowsVersion":"Windows 11 Home 24H2","termsrvVersion":"10.0.26100.9549",
         "titanRunning":false,"filesWaitingForIPad":2,"hostVersion":"0.1.0"}
        """#)
        XCTAssertEqual(status.overall, .problem)
        XCTAssertEqual(status.checks.map(\.id), ["allowed", "defender", "titan"])
        XCTAssertEqual(status.filesWaitingForIPad, 2)
        XCTAssertTrue(status.checks[0].canFixFromIPad)
        XCTAssertFalse(status.checks[1].canFixFromIPad, "Defender has to be done on the PC")
        XCTAssertNil(status.checks[2].fix)
        XCTAssertFalse(status.checks[2].canFixFromIPad)
    }

    func testUnknownCheckStateCountsAsProblem() throws {
        let check = try decode(HostCheck.self,
                               #"{"id":"x","title":"X","state":"exploded","detail":"","fix":null,"fixTitle":null}"#)
        XCTAssertEqual(check.state, .problem)
    }

    func testDecodesOutboxWithDotNetDates() throws {
        let files = try decode([HostFileEntry].self,
                               #"[{"name":"cue sheet.txt","size":6,"modified":"2026-10-24T13:06:25.4867687+00:00"}]"#)
        XCTAssertEqual(files.first?.name, "cue sheet.txt")
        XCTAssertEqual(files.first?.size, 6)
        let expected = Date(timeIntervalSince1970: 1_792_847_185.486)
        XCTAssertLessThan(abs((files.first?.modified.timeIntervalSince1970 ?? 0) - expected.timeIntervalSince1970), 0.01)
    }

    func testParsesDatesInEveryShapeTheHostUses() {
        XCTAssertNotNil(HostAPI.parseDate("2026-10-24T13:06:25+00:00"))
        XCTAssertNotNil(HostAPI.parseDate("2026-10-24T13:06:25Z"))
        XCTAssertNotNil(HostAPI.parseDate("2026-10-24T13:06:25.123Z"))
        XCTAssertNotNil(HostAPI.parseDate("2026-10-24T13:06:25.4867687+01:00"))
        XCTAssertNil(HostAPI.parseDate("yesterday"))
    }

    func testDecodesUploadAndIniAndFixResults() throws {
        XCTAssertEqual(try decode(HostUploadResult.self, #"{"savedAs":"Plot v2 (2).pdf","size":3}"#).savedAs, "Plot v2 (2).pdf")
        let ini = try decode(HostIniResult.self, #"{"supportsThisPc":false,"build":"10.0.26100.9549","updated":"2026-10-07"}"#)
        XCTAssertFalse(ini.supportsThisPc)
        XCTAssertEqual(ini.updated, "2026-10-07")
        let fix = try decode(HostFixResult.self, #"{"success":false,"message":"That fix has to be done on the PC."}"#)
        XCTAssertFalse(fix.success)
    }

    func testErrorsFromStatusCodes() {
        XCTAssertEqual(HostError.from(status: 401, body: Data()), .notPaired)
        let refused = HostError.from(status: 403, body: Data(#"{"error":"That code has expired."}"#.utf8))
        XCTAssertEqual(refused, .refused("That code has expired."))
        let fixRefused = HostError.from(status: 403, body: Data(#"{"success":false,"message":"That fix has to be done on the PC."}"#.utf8))
        XCTAssertEqual(fixRefused, .refused("That fix has to be done on the PC."))
        XCTAssertEqual(HostError.from(status: 500, body: Data()), .server(500, nil))
    }

    func testBuildsURLs() {
        XCTAssertEqual(HostAPI.url(host: "192.168.0.147", path: "hello")?.absoluteString,
                       "http://192.168.0.147:4431/api/v1/hello")
        XCTAssertEqual(HostAPI.url(host: " titan-pc.local ", path: "status")?.absoluteString,
                       "http://titan-pc.local:4431/api/v1/status")
        XCTAssertEqual(HostAPI.url(host: "10.0.0.5:5000", path: "outbox")?.absoluteString,
                       "http://10.0.0.5:5000/api/v1/outbox")
        let upload = HostAPI.url(host: "10.0.0.5", path: "files",
                                 query: [URLQueryItem(name: "name", value: "Plot v2 & notes.pdf")])
        XCTAssertEqual(upload?.absoluteString, "http://10.0.0.5:4431/api/v1/files?name=Plot%20v2%20%26%20notes.pdf")
        XCTAssertNil(HostAPI.url(host: "  ", path: "hello"))
    }

    func testSplitsAddresses() {
        XCTAssertEqual(HostAPI.splitAddress("pc.local")?.0, "pc.local")
        XCTAssertEqual(HostAPI.splitAddress("pc.local")?.1, 4431)
        XCTAssertEqual(HostAPI.splitAddress("[fe80::1]:4431")?.0, "fe80::1")
        XCTAssertEqual(HostAPI.splitAddress("fe80::1")?.0, "fe80::1", "bare IPv6 keeps its colons")
        XCTAssertEqual(HostAPI.splitAddress("pc:99999")?.0, "pc:99999", "not a real port")
    }

    func testPairingCodeTyping() {
        XCTAssertEqual(HostAPI.normaliseCode("482 913"), "482913")
        XCTAssertEqual(HostAPI.normaliseCode("48-29-13-77"), "482913")
        XCTAssertEqual(HostAPI.normaliseCode("abc"), "")
        XCTAssertEqual(HostAPI.normaliseCode("٤٨٢٩١٣"), "", "only ASCII digits")
        XCTAssertEqual(HostAPI.displayCode("482913"), "482 913")
        XCTAssertEqual(HostAPI.displayCode("48"), "48")
    }

    func testFixAllowListMatchesTheHost() {
        // Must match Fixer.AllowedFromIPad in TitanDeckHost/src/Service/Fixer.cs.
        XCTAssertEqual(HostProtocol.fixesAllowedFromIPad, [
            "AllowRemoteDesktop", "StartRemoteDesktop", "RestartRemoteDesktop", "UpdateRdpWrapIni", "AddFirewallRules",
        ])
        XCTAssertFalse(HostProtocol.fixesAllowedFromIPad.contains("AddDefenderExclusion"))
        XCTAssertFalse(HostProtocol.fixesAllowedFromIPad.contains("InstallRdpWrapper"))
    }

    func testAddressesLoseTheirInterfaceEnding() {
        XCTAssertEqual(HostAPI.cleanAddress(" 192.168.1.20%en0 "), "192.168.1.20", "what discovery used to fill in")
        XCTAssertEqual(HostAPI.cleanAddress("192.168.1.20%en0:5000"), "192.168.1.20:5000")
        XCTAssertEqual(HostAPI.cleanAddress("[fe80::1%en0]:4431"), "[fe80::1]:4431")
        XCTAssertEqual(HostAPI.cleanAddress("titan-pc.local"), "titan-pc.local")
        XCTAssertEqual(HostAPI.url(host: HostAPI.cleanAddress("10.0.0.5%en0"), path: "hello")?.absoluteString,
                       "http://10.0.0.5:4431/api/v1/hello")
    }
}
