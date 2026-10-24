// Tests/ChangelogTests.swift
import XCTest
@testable import TitanDeck

final class ChangelogTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func testParsesEntries() {
        let changelog = Changelog(markdown: """
        # Title
        Intro - not a note.

        ## 1.2.0 - 2026-11-01 - Big - and bold
        - **One:** first
        - Two

        ## 1.1.0 - 2026-10-01
        - Older
        """)
        XCTAssertEqual(changelog.entries.count, 2)
        XCTAssertEqual(changelog.latest?.version, "1.2.0")
        XCTAssertEqual(changelog.latest?.date, "2026-11-01")
        XCTAssertEqual(changelog.latest?.title, "Big - and bold")
        XCTAssertEqual(changelog.latest?.notes, ["**One:** first", "Two"])
        XCTAssertEqual(changelog.entry(for: "1.1.0")?.title, "")
        XCTAssertEqual(Changelog.plainNotes(changelog.latest!), "1.2.0 - Big - and bold\n- One: first\n- Two")
    }

    /// The version in project.yml must have a changelog entry at the top, so
    /// every TestFlight build has notes and the right What's New.
    func testProjectVersionMatchesTopChangelogEntry() throws {
        let changelog = Changelog(markdown: try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8))
        let project = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let line = try XCTUnwrap(project.components(separatedBy: .newlines).first { $0.contains("MARKETING_VERSION:") })
        let version = line.components(separatedBy: "\"").dropFirst().first
        XCTAssertEqual(changelog.latest?.version, version)
        XCTAssertFalse(changelog.latest?.notes.isEmpty ?? true)
    }

    func testVersionsGoDown() throws {
        let changelog = Changelog(markdown: try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8))
        let versions = changelog.entries.map { $0.version.split(separator: ".").compactMap { Int($0) } }
        XCTAssertTrue(versions.allSatisfy { $0.count == 3 })
        for (newer, older) in zip(versions, versions.dropFirst()) {
            XCTAssertTrue(newer.lexicographicallyPrecedes(older) == false && newer != older, "\(newer) should be after \(older)")
        }
    }
}
