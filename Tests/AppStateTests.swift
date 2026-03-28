import XCTest
@testable import MDMgr

final class AppStateTests: XCTestCase {
    func testOpenTab() {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/test.md")
        state.openTab(fileURL: url, content: "# Hello")
        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.activeTabIndex, 0)
        XCTAssertEqual(state.activeTab?.content, "# Hello")
    }

    func testOpenDuplicateSwitchesToExisting() {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/test.md")
        state.openTab(fileURL: url, content: "# Hello")
        state.openTab(fileURL: url, content: "# Hello")
        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.activeTabIndex, 0)
    }

    func testCloseTab() {
        let state = AppState()
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/a.md"), content: "A")
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/b.md"), content: "B")
        XCTAssertEqual(state.activeTabIndex, 1)
        state.closeTab(at: 1)
        XCTAssertEqual(state.tabs.count, 1)
        XCTAssertEqual(state.activeTabIndex, 0)
    }

    func testCloseLastTabClampsIndex() {
        let state = AppState()
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/a.md"), content: "A")
        state.closeTab(at: 0)
        XCTAssertTrue(state.tabs.isEmpty)
        XCTAssertNil(state.activeTab)
    }

    func testSwitchTab() {
        let state = AppState()
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/a.md"), content: "A")
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/b.md"), content: "B")
        state.activeTabIndex = 0
        XCTAssertEqual(state.activeTab?.displayName, "a.md")
    }

    func testNewTabOpensAfterCurrent() {
        let state = AppState()
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/a.md"), content: "A")
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/b.md"), content: "B")
        state.activeTabIndex = 0
        state.openTab(fileURL: URL(fileURLWithPath: "/tmp/c.md"), content: "C")
        XCTAssertEqual(state.tabs[1].displayName, "c.md")
        XCTAssertEqual(state.activeTabIndex, 1)
    }
}
