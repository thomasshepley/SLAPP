import XCTest
@testable import TitanDeck

final class ProfileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testLoadReturnsNilWhenNothingSaved() {
        XCTAssertNil(ProfileStore(directory: directory).load())
    }

    func testSaveThenLoad() throws {
        let store = ProfileStore(directory: directory)
        var profile = DeckProfile.makeDefault()
        profile.name = "Show A"
        try store.save(profile)
        XCTAssertEqual(store.load(), profile)
    }

    func testCorruptFileFallsBackToNil() throws {
        let store = ProfileStore(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.activeProfileURL)
        XCTAssertNil(store.load())
    }
}
