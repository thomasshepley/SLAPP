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

    func testNoPasswordIsExplained() {
        let text = RDPFailure.describe("The connection was cancelled.", host: "10.0.0.5", port: 3389, answered: true,
                                       blankPassword: true)
        XCTAssertTrue(text.contains("no password"))
        XCTAssertTrue(text.contains("automatic sign-in"))
        XCTAssertTrue(text.contains("Accounts with no password > Allow"))
        // Nothing answering is still about the address, password or not.
        XCTAssertTrue(RDPFailure.describe("x", host: "10.0.0.5", port: 3389, answered: false, blankPassword: true)
            .hasPrefix("Nothing answered"))
    }
}
