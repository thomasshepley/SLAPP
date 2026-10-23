import XCTest
@testable import TitanDeck

final class TitanHandlesTests: XCTestCase {
    func testParsesDocumentedShapeWithUserNumberProperty() throws {
        let json = """
        [{"handleLocation":{"group":"Playbacks","index":0,"page":0},
          "properties":[{"Key":"lockState","Value":"Unlocked"},{"Key":"UserNumber","Value":"3"}],
          "titanId":1689,"type":"playbackHandle","Active":true,"Legend":"Wash"},
         {"handleLocation":{"group":"Playbacks","index":1,"page":0},
          "properties":[],"titanId":1690,"userNumber":4,"type":"playbackHandle","Active":false,"Legend":""}]
        """
        let handles = try XCTUnwrap(TitanHandlesParser.parse(Data(json.utf8)))
        XCTAssertEqual(handles, [
            PlaybackHandleState(titanId: 1689, userNumber: 3, active: true, legend: "Wash"),
            PlaybackHandleState(titanId: 1690, userNumber: 4, active: false, legend: ""),
        ])
        XCTAssertEqual(TitanHandlesParser.activeUserNumbers(handles), [3])
    }

    func testNoUserNumbersMeansUnsupported() throws {
        let json = #"[{"titanId":1,"Active":true,"Legend":""}]"#
        let handles = try XCTUnwrap(TitanHandlesParser.parse(Data(json.utf8)))
        XCTAssertNil(TitanHandlesParser.activeUserNumbers(handles))
        XCTAssertEqual(TitanHandlesParser.activeUserNumbers([]), [])
    }

    func testGarbageIsNil() {
        XCTAssertNil(TitanHandlesParser.parse(Data("not json".utf8)))
        XCTAssertNil(TitanHandlesParser.parse(Data(#"{"a":1}"#.utf8)))
    }

    func testHandlesURL() {
        XCTAssertEqual(TitanEndpoints.handlesURL(group: "Playbacks", host: "10.0.0.1")?.absoluteString,
                       "http://10.0.0.1:4430/titan/handles/Playbacks")
        XCTAssertNil(TitanEndpoints.handlesURL(group: "Playbacks", host: " "))
    }
}
