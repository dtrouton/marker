import XCTest
@testable import MDMgr

final class BridgeMessageTests: XCTestCase {
    func testLoadContentMessage() {
        let json = WebViewCoordinator.loadContentJSON(content: "# Hello\nWorld")
        XCTAssertTrue(json.contains("\"type\":\"loadContent\""))
        XCTAssertTrue(json.contains("# Hello"))
    }

    func testSetModeMessage() {
        let json = WebViewCoordinator.setModeJSON(mode: .edit)
        XCTAssertTrue(json.contains("\"type\":\"setMode\""))
        XCTAssertTrue(json.contains("\"mode\":\"edit\""))
    }

    func testSpecialCharactersEscaped() {
        let content = "Line 1\nLine 2\t\"Quoted\"\nBackslash: \\"
        let json = WebViewCoordinator.loadContentJSON(content: content)
        let data = json.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed, "JSON should be valid")
    }
}
