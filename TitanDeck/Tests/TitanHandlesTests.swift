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
            PlaybackHandleState(titanId: 1689, userNumber: 3, active: true, legend: "Wash", page: 0, index: 0,
                                type: "playbackHandle", group: "Playbacks"),
            PlaybackHandleState(titanId: 1690, userNumber: 4, active: false, legend: "", page: 0, index: 1,
                                type: "playbackHandle", group: "Playbacks"),
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
        XCTAssertEqual(TitanEndpoints.handlesURL(group: "Playbacks", page: 59, host: "10.0.0.1")?.absoluteString,
                       "http://10.0.0.1:4430/titan/handles/Playbacks/59")
        XCTAssertEqual(TitanEndpoints.handlesURL(group: "", host: "10.0.0.1")?.absoluteString,
                       "http://10.0.0.1:4430/titan/handles", "every handle")
    }

    func testFindsAGrandMasterOnPage60() throws {
        let json = """
        [{"handleLocation":{"group":"Playbacks","index":0,"page":59},"properties":[],
          "titanId":1895,"type":"masterHandle","Active":false,"Legend":"Grand Master"},
         {"handleLocation":{"group":"Playbacks","index":1,"page":59},"properties":[],
          "titanId":1896,"type":"playbackHandle","Active":false,"Legend":"Fronts"},
         {"handleLocation":{"group":"Colours","index":0,"page":59},"properties":[],
          "titanId":2000,"type":"paletteHandle","Active":false,"Legend":"Red"},
         {"handleLocation":{"group":"Playbacks","index":0,"page":0},"properties":[],
          "titanId":1700,"type":"playbackHandle","Active":false,"Legend":"Cue"}]
        """
        let handles = try XCTUnwrap(TitanHandlesParser.parse(Data(json.utf8)))
        XCTAssertEqual(handles[0].type, "masterHandle")
        XCTAssertEqual(handles[0].group, "Playbacks")
        let page = TitanHandlesParser.onPage(59, of: handles)
        XCTAssertEqual(page.map(\.titanId), [1895, 1896], "page 60's playback faders, not a palette page 60")
        XCTAssertEqual(TitanHandlesParser.pageNote(page, page: 59, from: "every handle"),
                       "Masters: page 60 (every handle) has 2: fader 1 Grand Master (masterHandle, id 1895); fader 2 Fronts (playbackHandle, id 1896)")
        XCTAssertEqual(TitanHandlesParser.pageNote([], page: 59, from: "handles/Playbacks/59"),
                       "Masters: Titan has nothing on page 60 (handles/Playbacks/59)")
    }

    func testReadsAFaderLevelWhenTitanGivesOne() throws {
        let json = """
        [{"handleLocation":{"group":"Playbacks","index":0,"page":59},"properties":[{"Key":"FaderLevel","Value":"0.45"}],
          "titanId":3001,"Active":true,"Legend":"Fronts"},
         {"handleLocation":{"group":"Playbacks","index":1,"page":59},"properties":[{"Key":"levelMatched","Value":true}],
          "titanId":3002,"level":75,"Active":false,"Legend":"Backs"},
         {"handleLocation":{"group":"Playbacks","index":2,"page":59},"properties":[],"titanId":3003,"Active":false,"Legend":""}]
        """
        let handles = try XCTUnwrap(TitanHandlesParser.parse(Data(json.utf8)))
        XCTAssertEqual(handles.map(\.level), [0.45, 0.75, nil], "a percentage is scaled; a level-match flag isn't a level")
        XCTAssertEqual(handles.first?.page, 59)
    }
}
