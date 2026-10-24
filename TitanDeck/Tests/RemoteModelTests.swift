import XCTest
@testable import TitanDeck

final class RemoteModelTests: XCTestCase {
    // MARK: DesktopMapper

    func testFitAddsLetterboxOnWideView() {
        let mapper = DesktopMapper(viewSize: CGSize(width: 2000, height: 1000), desktopSize: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(mapper.fittedRect, CGRect(x: 500, y: 0, width: 1000, height: 1000))
    }

    func testPointMapsThroughScaleAndOffset() {
        let mapper = DesktopMapper(viewSize: CGSize(width: 1376, height: 1032), desktopSize: CGSize(width: 2752, height: 2064))
        let point = mapper.desktopPoint(for: CGPoint(x: 100, y: 50))
        XCTAssertEqual(point?.x, 200)
        XCTAssertEqual(point?.y, 100)
    }

    func testPointsInLetterboxClampToEdge() {
        let mapper = DesktopMapper(viewSize: CGSize(width: 2000, height: 1000), desktopSize: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(mapper.desktopPoint(for: CGPoint(x: 10, y: 500))?.x, 0)
        XCTAssertEqual(mapper.desktopPoint(for: CGPoint(x: 1990, y: 2000))?.x, 999)
        XCTAssertEqual(mapper.desktopPoint(for: CGPoint(x: 1990, y: 2000))?.y, 999)
    }

    func testUnknownSizesGiveNoPoint() {
        XCTAssertNil(DesktopMapper(viewSize: .zero, desktopSize: CGSize(width: 10, height: 10)).desktopPoint(for: .zero))
        XCTAssertNil(DesktopMapper(viewSize: CGSize(width: 10, height: 10), desktopSize: .zero).desktopPoint(for: .zero))
    }

    func testSessionSizeIsEvenAndClamped() {
        let size = DesktopMapper.sessionSize(for: CGSize(width: 1375.5, height: 1031))
        XCTAssertEqual(size.width, 1374)
        XCTAssertEqual(size.height, 1030)
        XCTAssertEqual(DesktopMapper.sessionSize(for: CGSize(width: 9000, height: 10)).width, 4096)
        XCTAssertEqual(DesktopMapper.sessionSize(for: CGSize(width: 9000, height: 10)).height, 1024)
    }

    // MARK: ScrollAccumulator

    func testScrollCarriesRemainder() {
        var scroll = ScrollAccumulator(pointsPerNotch: 20)
        XCTAssertEqual(scroll.add(15), 0)
        XCTAssertEqual(scroll.add(15), 1)   // 30 -> one notch, 10 left
        XCTAssertEqual(scroll.add(35), 2)   // 45 -> two notches
        XCTAssertEqual(scroll.add(-50), -2)
        scroll.reset()
        XCTAssertEqual(scroll.add(19), 0)
    }

    // MARK: CertificateTrustStore

    private func freshDefaults() -> UserDefaults {
        let name = "RemoteModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testTrustOnFirstUseThenMismatch() {
        let store = CertificateTrustStore(defaults: freshDefaults())
        XCTAssertEqual(store.evaluate(host: "10.0.0.5", port: 3389, fingerprint: "AA:BB"), .trustedFirstUse)
        XCTAssertEqual(store.evaluate(host: "10.0.0.5", port: 3389, fingerprint: "aa:bb"), .trusted)
        XCTAssertEqual(store.evaluate(host: "10.0.0.5", port: 3389, fingerprint: "cc:dd"), .mismatch)
        XCTAssertEqual(store.evaluate(host: "10.0.0.5", port: 3390, fingerprint: "cc:dd"), .trustedFirstUse)
        store.forgetAll()
        XCTAssertEqual(store.evaluate(host: "10.0.0.5", port: 3389, fingerprint: "cc:dd"), .trustedFirstUse)
    }

    func testEmptyFingerprintIsNeverTrusted() {
        let store = CertificateTrustStore(defaults: freshDefaults())
        XCTAssertEqual(store.evaluate(host: "pc", port: 3389, fingerprint: ""), .mismatch)
    }

    // MARK: RDPSettings

    func testHostFallsBackToTitanHost() {
        var settings = RDPSettings()
        settings.username = "show"
        XCTAssertEqual(settings.effectiveHost(titanHost: " 10.0.0.9 "), "10.0.0.9")
        XCTAssertTrue(settings.isComplete(titanHost: "10.0.0.9"))
        XCTAssertFalse(settings.isComplete(titanHost: ""))
        settings.host = "10.0.0.20"
        XCTAssertEqual(settings.effectiveHost(titanHost: "10.0.0.9"), "10.0.0.20")
        settings.username = " "
        XCTAssertFalse(settings.isComplete(titanHost: "10.0.0.9"))
    }

    func testSettingsRoundTrip() {
        let defaults = freshDefaults()
        var settings = RDPSettings()
        settings.host = "titan-pc"
        settings.username = "Show"
        settings.connectOnLaunch = true
        settings.save(to: defaults)
        XCTAssertEqual(RDPSettings.load(from: defaults), settings)
        XCTAssertEqual(settings.keychainAccount, "show@rdp")
    }

    func testConnectOnLaunchIsOffByDefault() {
        XCTAssertFalse(RDPSettings().connectOnLaunch)
    }

    func testOlderSettingsKeepTheLoginButTurnConnectOnLaunchOff() throws {
        let defaults = freshDefaults()
        let old = #"{"host":"192.168.0.147","port":3389,"username":"Show","domain":"","autoConnect":true}"#
        defaults.set(Data(old.utf8), forKey: RDPSettings.defaultsKey)
        let settings = RDPSettings.load(from: defaults)
        XCTAssertEqual(settings.host, "192.168.0.147")
        XCTAssertEqual(settings.username, "Show")
        XCTAssertFalse(settings.connectOnLaunch)
    }
}
