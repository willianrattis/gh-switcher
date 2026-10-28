import XCTest
@testable import GHSwitcher

final class ParserTests: XCTestCase {
    private let fixture = """
    {"hosts":{"github.com":[
      {"state":"success","active":true,"host":"github.com","login":"willian-rattis_gcb","tokenSource":"keyring","scopes":"gist, read:org, repo, workflow","gitProtocol":"https","token":"REDACTED"},
      {"state":"success","active":false,"host":"github.com","login":"willianrattis","tokenSource":"keyring","scopes":"gist, read:org, repo, workflow","gitProtocol":"https"}
    ]}}
    """

    func testParsesAccounts() throws {
        let accounts = try GHAuthStatus.parse(Data(fixture.utf8))
        XCTAssertEqual(accounts.map(\.login), ["willian-rattis_gcb", "willianrattis"])
        XCTAssertEqual(accounts.filter(\.active).map(\.login), ["willian-rattis_gcb"])
        XCTAssertTrue(accounts.allSatisfy(\.isValid))
        XCTAssertEqual(accounts.first?.tokenSource, "keyring")
    }

    func testModelDoesNotKeepToken() throws {
        let accounts = try GHAuthStatus.parse(Data(fixture.utf8))
        let encoded = String(decoding: try JSONEncoder().encode(accounts), as: UTF8.self)
        XCTAssertFalse(encoded.contains("\"token\""))
        XCTAssertFalse(encoded.contains("REDACTED"))
    }

    func testInvalidAccount() throws {
        let json = """
        {"hosts":{"github.com":[{"state":"error","active":false,"host":"github.com","login":"x"}]}}
        """
        let accounts = try GHAuthStatus.parse(Data(json.utf8))
        XCTAssertFalse(accounts[0].isValid)
        XCTAssertNil(accounts[0].tokenSource)
    }

    func testMultipleHostsSorted() throws {
        let json = """
        {"hosts":{"z.example.com":[{"state":"success","active":true,"host":"z.example.com","login":"b"}],
                  "github.com":[{"state":"success","active":false,"host":"github.com","login":"a"}]}}
        """
        XCTAssertEqual(try GHAuthStatus.parse(Data(json.utf8)).map(\.host), ["github.com", "z.example.com"])
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try GHAuthStatus.parse(Data("not json".utf8)))
    }
}
