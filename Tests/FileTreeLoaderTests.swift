import XCTest
@testable import MDMgr

final class FileTreeLoaderTests: XCTestCase {
    var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    func testLoadsMarkdownFiles() throws {
        FileManager.default.createFile(atPath: testDir.appendingPathComponent("readme.md").path, contents: Data("# Hi".utf8))
        FileManager.default.createFile(atPath: testDir.appendingPathComponent("notes.txt").path, contents: Data("text".utf8))

        let nodes = try FileTreeLoader.load(directory: testDir, markdownOnly: true)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.name, "readme.md")
    }

    func testLoadsRecursively() throws {
        let sub = testDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: sub.appendingPathComponent("deep.md").path, contents: Data("# Deep".utf8))

        let nodes = try FileTreeLoader.load(directory: testDir, markdownOnly: true)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertTrue(nodes.first!.isDirectory)
        XCTAssertEqual(nodes.first!.children.count, 1)
        XCTAssertEqual(nodes.first!.children.first?.name, "deep.md")
    }

    func testSkipsHiddenFiles() throws {
        FileManager.default.createFile(atPath: testDir.appendingPathComponent(".hidden.md").path, contents: Data("# Hidden".utf8))
        FileManager.default.createFile(atPath: testDir.appendingPathComponent("visible.md").path, contents: Data("# Visible".utf8))

        let nodes = try FileTreeLoader.load(directory: testDir, markdownOnly: true)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.name, "visible.md")
    }

    func testEmptyDirectoriesOmittedInMarkdownMode() throws {
        let emptyDir = testDir.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let nodes = try FileTreeLoader.load(directory: testDir, markdownOnly: true)
        XCTAssertTrue(nodes.isEmpty)
    }
}
