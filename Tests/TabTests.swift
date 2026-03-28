import XCTest
@testable import MDMgr

final class TabTests: XCTestCase {
    func testNewTabIsCleanAndInReadMode() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let tab = Tab(fileURL: url, content: "# Hello")
        XCTAssertFalse(tab.isDirty)
        XCTAssertEqual(tab.mode, .read)
        XCTAssertEqual(tab.content, "# Hello")
        XCTAssertEqual(tab.fileURL, url)
    }

    func testMarkDirty() {
        let tab = Tab(fileURL: URL(fileURLWithPath: "/tmp/test.md"), content: "# Hello")
        tab.content = "# Changed"
        tab.isDirty = true
        XCTAssertTrue(tab.isDirty)
    }

    func testToggleMode() {
        let tab = Tab(fileURL: URL(fileURLWithPath: "/tmp/test.md"), content: "")
        XCTAssertEqual(tab.mode, .read)
        tab.mode = .edit
        XCTAssertEqual(tab.mode, .edit)
        tab.mode = .read
        XCTAssertEqual(tab.mode, .read)
    }

    func testDisplayName() {
        let tab = Tab(fileURL: URL(fileURLWithPath: "/Users/me/docs/README.md"), content: "")
        XCTAssertEqual(tab.displayName, "README.md")
    }
}
