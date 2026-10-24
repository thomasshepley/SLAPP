// Tests/FileDropTests.swift
import XCTest
@testable import TitanDeck

final class FileDropTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("FileDropTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testUniqueNames() {
        let taken: Set<String> = ["Plot.pdf", "Plot (2).pdf", "Notes"]
        XCTAssertEqual(FileDropCopier.uniqueName("Rig.pdf") { taken.contains($0) }, "Rig.pdf")
        XCTAssertEqual(FileDropCopier.uniqueName("Plot.pdf") { taken.contains($0) }, "Plot (3).pdf")
        XCTAssertEqual(FileDropCopier.uniqueName("Notes") { taken.contains($0) }, "Notes (2)")
        XCTAssertEqual(FileDropCopier.uniqueName("show.v2.json") { $0 == "show.v2.json" }, "show.v2 (2).json")
    }

    func testCopiesInChunksWithProgressAndNeverOverwrites() throws {
        let source = folder.appendingPathComponent("source.bin")
        let bytes = Data((0 ..< (FileDropCopier.chunkSize * 2 + 1234)).map { UInt8(truncatingIfNeeded: $0) })
        try bytes.write(to: source)
        let pc = folder.appendingPathComponent("pc", isDirectory: true)
        try FileManager.default.createDirectory(at: pc, withIntermediateDirectories: true)

        var updates: [Double] = []
        let first = try FileDropCopier.copy(source, into: pc) { updates.append($0) }
        XCTAssertEqual(first, "source.bin")
        XCTAssertEqual(try Data(contentsOf: pc.appendingPathComponent(first)), bytes)
        XCTAssertEqual(updates.first, 0)
        XCTAssertEqual(updates.last, 1)
        XCTAssertGreaterThanOrEqual(updates.count, 4)      // 0, three chunks, 1
        XCTAssertEqual(updates, updates.sorted())

        let second = try FileDropCopier.copy(source, into: pc) { _ in }
        XCTAssertEqual(second, "source (2).bin")
        XCTAssertEqual(try Data(contentsOf: pc.appendingPathComponent(first)), bytes)
    }

    func testCopyIntoAMissingFolderFailsCleanly() {
        let source = folder.appendingPathComponent("a.txt")
        try? Data("hi".utf8).write(to: source)
        XCTAssertThrowsError(try FileDropCopier.copy(source, into: folder.appendingPathComponent("gone")) { _ in })
    }

    func testStagingKeepsBothCopiesOfTheSameName() throws {
        let source = folder.appendingPathComponent("photo.heic")
        try Data([1, 2, 3]).write(to: source)
        let staging = folder.appendingPathComponent("staging")
        let a = try FileDropCopier.stage(source, in: staging)
        let b = try FileDropCopier.stage(source, in: staging)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(b.lastPathComponent, "photo (2).heic")
        XCTAssertEqual(try Data(contentsOf: b), Data([1, 2, 3]))
    }
}
