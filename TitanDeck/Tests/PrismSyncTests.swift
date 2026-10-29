import XCTest
@testable import TitanDeck

final class PrismSyncTests: XCTestCase {
    private func clip(_ index: Int, _ name: String, _ path: String?, number: Int? = nil) -> HostPrismClip {
        HostPrismClip(index: index, number: number, name: name, path: path, bytes: nil, exists: true)
    }

    private func item(_ title: String, fileName: String = "", folder: Int? = nil, file: Int? = nil, path: String? = nil) -> FXItem {
        FXItem(id: UUID(), title: title, category: .other, fileName: fileName, kind: .video, notes: "mine",
               added: Date(timeIntervalSince1970: 0), prismFolder: folder, prismFile: file, prismPath: path)
    }

    func testAddsPrismClipsNumberedFromSettings() {
        let banks = [
            HostPrismBank(index: 0, number: nil, name: "Fire", clips: [clip(0, "Big_fire", "D:\\Media\\Big_fire.mov"), clip(1, "Glow", "D:\\Media\\glow.png")]),
            HostPrismBank(index: 1, number: nil, name: "Bank 2", clips: [clip(0, "Blue lights", "D:\\Media\\blue.mp4")]),
        ]
        var settings = PrismSync.Settings()
        settings.firstFile = 0
        let (items, report) = PrismSync.merge(banks, into: [], settings: settings)
        XCTAssertEqual(report, PrismSync.Report(clips: 3, added: 3))
        XCTAssertEqual(items.map(\.title), ["Big fire", "Glow", "Blue lights"])
        XCTAssertEqual(items.map(\.prismFolder), [1, 1, 2])
        XCTAssertEqual(items.map(\.prismFile), [0, 1, 0])
        XCTAssertEqual(items[0].category, .fire)
        XCTAssertEqual(items[1].category, .fire, "a clip without a telling name takes its bank's")
        XCTAssertEqual(items[1].kind, .image)
        XCTAssertFalse(items[0].isOnIPad)
        XCTAssertEqual(items[0].prismBank, "Fire")
        XCTAssertNotNil(items[0].deckItem, "Fire with both numbers is on the deck")
    }

    func testKeepsYourEditsAndFollowsPrismsNumbers() {
        var mine = item("Campfire", path: "D:/Media/fire.mov")
        mine.prismFolder = 1
        mine.prismFile = 1
        mine.category = .candle
        let banks = [HostPrismBank(index: 2, number: nil, name: "Moved", clips: [clip(4, "fire", "d:\\media\\FIRE.mov")])]
        let (items, report) = PrismSync.merge(banks, into: [mine], settings: .init())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Campfire")
        XCTAssertEqual(items[0].category, .candle)
        XCTAssertEqual(items[0].notes, "mine")
        XCTAssertEqual(items[0].prismFolder, 3)
        XCTAssertEqual(items[0].prismFile, 5)
        XCTAssertEqual(report.renumbered, 1)
        XCTAssertEqual(report.added, 0)
    }

    func testMatchesClipsYouSentByFileName() {
        let sent = item("Police v2", fileName: "Police_Lights_v2.mp4")
        let banks = [HostPrismBank(index: 0, number: 7, name: "007 Police", clips: [clip(0, "001 x", "E:\\Police_Lights_v2.mp4", number: 3)])]
        let (items, report) = PrismSync.merge(banks, into: [sent], settings: .init())
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].isOnIPad)
        XCTAssertEqual(items[0].prismFolder, 7, "numbers in the media folder's names win")
        XCTAssertEqual(items[0].prismFile, 3)
        XCTAssertEqual(report.linked, 1)
    }

    func testMarksClipsPrismNoLongerHas() {
        let old = item("Old", folder: 1, file: 1, path: "D:/old.mov")
        let kept = item("Not from Prism", fileName: "x.mov")
        let (items, report) = PrismSync.merge([], into: [old, kept], settings: .init())
        XCTAssertEqual(items[0].prismMissing, true)
        XCTAssertNil(items[1].prismMissing)
        XCTAssertEqual(report.gone, 1)
        XCTAssertEqual(PrismSync.merge([], into: items, settings: .init()).report.gone, 0, "only counted the first time")
    }

    func testReportText() {
        XCTAssertEqual(PrismSync.Report(clips: 2).text, "Prism has 2 clips, the library was up to date.")
        XCTAssertEqual(PrismSync.Report(clips: 1, added: 1, gone: 2).text, "Prism has 1 clip, 1 new, 2 no longer in Prism.")
    }

    func testDecodesTheHostsAnswer() throws {
        let json = #"{"ok":true,"source":"C:\\P\\show.json","modified":"2026-10-29T12:33:56.9667799+00:00","banks":[{"index":0,"number":null,"name":"Fire","clips":[{"index":0,"number":null,"name":"Big","path":"C:\\a.mov","bytes":10,"exists":true}]}],"message":"1 bank, 1 clip","steps":[]}"#
        let media = try HostAPI.decoder.decode(HostPrismMedia.self, from: Data(json.utf8))
        XCTAssertEqual(media.banks.first?.clips.first?.path, "C:\\a.mov")
    }
}
