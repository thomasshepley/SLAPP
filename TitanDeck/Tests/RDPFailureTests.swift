import XCTest
@testable import TitanDeck

final class RDPFailureTests: XCTestCase {
    func testNothingAnsweringPointsAtTheAddressAndFirewall() {
        let text = RDPFailure.describe("The connection was cancelled.", host: "192.168.1.20", port: 3389, answered: false)
        XCTAssertTrue(text.hasPrefix("Nothing answered at 192.168.1.20 on the remote desktop port (3389)."))
        XCTAssertTrue(text.contains("show network"))
        XCTAssertTrue(text.contains("Public"))
    }

    func testAnsweringPointsAtTheLogin() {
        let text = RDPFailure.describe("The connection was cancelled.", host: "10.0.0.5", port: 3390, answered: true)
        XCTAssertTrue(text.hasPrefix("The PC answered at 10.0.0.5:3390, but the remote desktop didn't open (The connection was cancelled)."))
        XCTAssertTrue(text.contains("username and password"))
    }
}
