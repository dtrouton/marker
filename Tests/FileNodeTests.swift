import XCTest
@testable import MDMgr

final class FileNodeTests: XCTestCase {
    func testFileNode() {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/readme.md"), isDirectory: false)
        XCTAssertEqual(node.name, "readme.md")
        XCTAssertFalse(node.isDirectory)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testDirectoryNode() {
        let child = FileNode(url: URL(fileURLWithPath: "/tmp/docs/file.md"), isDirectory: false)
        let dir = FileNode(url: URL(fileURLWithPath: "/tmp/docs"), isDirectory: true, children: [child])
        XCTAssertTrue(dir.isDirectory)
        XCTAssertEqual(dir.children.count, 1)
        XCTAssertEqual(dir.name, "docs")
    }

    func testChildrenSorted() {
        let b = FileNode(url: URL(fileURLWithPath: "/tmp/b.md"), isDirectory: false)
        let a = FileNode(url: URL(fileURLWithPath: "/tmp/a.md"), isDirectory: false)
        let dir = FileNode(url: URL(fileURLWithPath: "/tmp/docs"), isDirectory: true, children: [b, a])
        XCTAssertEqual(dir.sortedChildren.first?.name, "a.md")
    }

    func testIsMarkdown() {
        let md = FileNode(url: URL(fileURLWithPath: "/tmp/file.md"), isDirectory: false)
        let txt = FileNode(url: URL(fileURLWithPath: "/tmp/file.txt"), isDirectory: false)
        let mdown = FileNode(url: URL(fileURLWithPath: "/tmp/file.markdown"), isDirectory: false)
        XCTAssertTrue(md.isMarkdown)
        XCTAssertFalse(txt.isMarkdown)
        XCTAssertTrue(mdown.isMarkdown)
    }
}
