import XCTest
@testable import TitanDeck

final class RDPZoomTests: XCTestCase {
    func testAPhoneSizedScreenAsksForAnIPadSizedDesktop() {
        // iPhone Duo open, held sideways: the same shape, 834 pt on the short side.
        let duo = DesktopMapper.sessionSize(for: CGSize(width: 890, height: 626), choice: .automatic)
        XCTAssertEqual(duo.width, 1184)
        XCTAssertEqual(duo.height, 834)
        // An iPad keeps its own size unless asked.
        let iPad = DesktopMapper.sessionSize(for: CGSize(width: 1194, height: 834), choice: .automatic)
        XCTAssertEqual(iPad.width, 1194)
        XCTAssertEqual(iPad.height, 834)
        XCTAssertEqual(DesktopMapper.sessionSize(for: CGSize(width: 932, height: 430), choice: .screen).width, 932)
        let phone = DesktopMapper.sessionSize(for: CGSize(width: 932, height: 430), choice: .iPad)
        XCTAssertEqual(phone.width, 1806)
        XCTAssertEqual(phone.height, 834)
        XCTAssertEqual(DesktopMapper.sessionSize(for: CGSize(width: 1194, height: 834), choice: .iPad).width, 1194,
                       "already iPad-sized")
    }

    func testPinchKeepsWhatsUnderTheFingers() {
        let view = CGSize(width: 1000, height: 800)
        let centred = RDPZoom().pinched(by: 2, around: .zero, viewSize: view)
        XCTAssertEqual(centred.scale, 2)
        XCTAssertEqual(centred.offset, .zero)
        let offCentre = RDPZoom().pinched(by: 2, around: CGPoint(x: 100, y: 50), viewSize: view)
        XCTAssertEqual(offCentre.offset, CGPoint(x: -100, y: -50))
        XCTAssertEqual(RDPZoom().pinched(by: 10, around: .zero, viewSize: view).scale, RDPZoom.maxScale)
    }

    func testNeverZoomsOutPastFitOrPansOffTheEdge() {
        let view = CGSize(width: 1000, height: 800)
        let zoomed = RDPZoom(scale: 2, offset: .zero)
        XCTAssertEqual(zoomed.panned(by: CGPoint(x: 1000, y: -1000), viewSize: view).offset, CGPoint(x: 500, y: -400))
        let back = zoomed.panned(by: CGPoint(x: 300, y: 0), viewSize: view).pinched(by: 0.1, around: .zero, viewSize: view)
        XCTAssertEqual(back.scale, 1)
        XCTAssertEqual(back.offset, .zero)
        XCTAssertFalse(back.isZoomed)
    }

    func testATouchMapsBackThroughTheZoom() {
        let view = CGSize(width: 1000, height: 800)
        let zoom = RDPZoom(scale: 2, offset: CGPoint(x: -100, y: -50))
        // The view's centre shows the picture 50, 25 pt right of and below its centre.
        XCTAssertEqual(zoom.unzoomed(CGPoint(x: 500, y: 400), viewSize: view), CGPoint(x: 550, y: 425))
        XCTAssertEqual(RDPZoom().unzoomed(CGPoint(x: 12, y: 34), viewSize: view), CGPoint(x: 12, y: 34))
    }
}
