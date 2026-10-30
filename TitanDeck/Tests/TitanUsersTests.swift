import XCTest
@testable import TitanDeck

final class TitanUsersTests: XCTestCase {
    func testReadsUsersWhateverTheShape() {
        let menu = #"[{"Legend":"Operator","TitanId":1201,"Selected":true},{"legend":"Busking","titanId":"1202"},{"legend":"","titanId":1203}]"#
        XCTAssertEqual(TitanUsers.parse(Data(menu.utf8)), [.init(id: 1201, name: "Operator"), .init(id: 1202, name: "Busking")])
        let nested = #"{"items":[{"Value":{"Id":7,"Name":"Ops"}},{"Value":{"Id":7,"Name":"Ops"}}]}"#
        XCTAssertEqual(TitanUsers.parse(Data(nested.utf8)), [.init(id: 7, name: "Ops")])
        XCTAssertEqual(TitanUsers.parse(Data("not json".utf8)), [])
    }

    func testPlainValues() {
        XCTAssertEqual(TitanUsers.value(Data(#""Operator""#.utf8)), "Operator")
        XCTAssertEqual(TitanUsers.value(Data("1201".utf8)), "1201")
        XCTAssertNil(TitanUsers.value(Data()))
    }

    func testUserEndpoints() {
        XCTAssertEqual(TitanEndpoints.setUserURL(1201, host: "10.0.0.5")?.absoluteString,
                       "http://10.0.0.5:4430/titan/script/2/Users/SetUser?userId=1201")
        XCTAssertEqual(TitanEndpoints.currentUserURL(name: true, host: "10.0.0.5")?.absoluteString,
                       "http://10.0.0.5:4430/titan/get/2/Users/CurrentUserName")
    }
}
