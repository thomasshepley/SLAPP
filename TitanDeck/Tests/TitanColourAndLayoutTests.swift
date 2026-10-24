// Tests/TitanColourAndLayoutTests.swift
import XCTest
@testable import TitanDeck

final class TitanColourAndLayoutTests: XCTestCase {
    private func handle(_ legend: String, id: Int, number: Int? = nil) -> PlaybackHandleState {
        PlaybackHandleState(titanId: id, userNumber: number, active: false, legend: legend)
    }

    func testPaletteIsFoundByItsTemperature() {
        let palettes = [handle("13200K test", id: 1), handle("Tungsten 3200 K", id: 2), handle("5600K", id: 3),
                        handle("Warm 3200", id: 4), handle("2700K-ish", id: 5)]
        XCTAssertEqual(TitanPaletteMatch.palette(for: 3200, in: palettes)?.titanId, 2, "\"3200 K\" beats a bare 3200, and 13200 isn't 3200")
        XCTAssertEqual(TitanPaletteMatch.palette(for: 5600, in: palettes)?.titanId, 3)
        XCTAssertEqual(TitanPaletteMatch.palette(for: 2700, in: palettes)?.titanId, 5)
        XCTAssertNil(TitanPaletteMatch.palette(for: 4500, in: palettes))
        XCTAssertEqual(TitanPaletteMatch.palette(for: 3200, in: [handle("Warm 3200", id: 4)])?.titanId, 4, "a bare number still works")
    }

    func testHandlesCarryPageAndPositionAndOddUserNumbers() {
        let json = """
        [{"handleLocation":{"group":"Playbacks","index":4,"page":2},"titanId":1689,"Active":true,"Legend":"Fire",
          "userNumber":{"userNumbers":[12]}},
         {"handleLocation":{"group":"Playbacks","index":0,"page":0},"titanId":1700,"Active":false,"Legend":"",
          "properties":[{"Key":"userNumber","Value":{"hashCode":7}}]},
         {"handleLocation":{"group":"Playbacks","index":1,"page":0},"titanId":1701,"Active":false,"Legend":"x","userNumber":3}]
        """
        let handles = TitanHandlesParser.parse(Data(json.utf8)) ?? []
        XCTAssertEqual(handles.count, 3)
        XCTAssertEqual(handles[0].page, 2)
        XCTAssertEqual(handles[0].index, 4)
        XCTAssertEqual(handles[0].userNumber, 12)
        XCTAssertEqual(handles[1].userNumber, 7)
        XCTAssertEqual(handles[2].userNumber, 3)
        XCTAssertEqual(TitanHandlesParser.legendsByUserNumber(handles), [12: "Fire", 3: "x"])
    }

    func testWorkspaceAndPaletteURLs() {
        XCTAssertEqual(TitanEndpoints.url(for: .recallWorkspace(userNumber: 4), host: "10.0.0.5")?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Workspace/Apply?handle_userNumber=4")
        XCTAssertEqual(TitanEndpoints.applyPaletteURL(titanId: 88, host: "10.0.0.5")?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Palette/ApplyPalette?handle_titanId=88&usePaletteTimes=false")
        XCTAssertEqual(ActionDraft(action: .recallWorkspace(userNumber: 6)).action, .recallWorkspace(userNumber: 6))
    }

    func testWorkspaceKeysShowTitansNames() {
        let blank = KeyDefinition(index: 0, label: "", action: .recallWorkspace(userNumber: 2))
        XCTAssertEqual(DeckFlow.displayed(blank, onPage: "Layouts", workspaceNames: [2: "Programming"])?.label, "Programming")
        XCTAssertEqual(DeckFlow.displayed(blank, onPage: "Layouts")?.label, "VIEW\n2", "until Titan answers")
        let named = KeyDefinition(index: 0, label: "Mine", action: .recallWorkspace(userNumber: 2))
        XCTAssertEqual(DeckFlow.displayed(named, onPage: "Layouts", workspaceNames: [2: "Programming"])?.label, "Mine",
                       "your own label wins")
        let layouts = DeckProfile.makeDefault().pages.first { $0.name == "Layouts" }
        XCTAssertEqual(layouts?.key(at: 11)?.action, .recallWorkspace(userNumber: 12))
    }
}
