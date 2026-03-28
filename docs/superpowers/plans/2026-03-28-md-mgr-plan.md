# MD Mgr Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native macOS markdown reader/editor that opens files rendered by default and supports rich text editing via an embedded web editor.

**Architecture:** SwiftUI app shell (sidebar, tabs, toolbar) with a WKWebView hosting a Milkdown-based markdown editor. Swift ↔ JS bridge for communication. Two modes: read (rendered HTML) and edit (WYSIWYG).

**Tech Stack:** Swift/SwiftUI (macOS 14+), WKWebView, Milkdown (ProseMirror), markdown-it, DOMPurify, highlight.js, Vite, xcodegen

---

## File Structure

```
md-mgr/
├── project.yml                         # xcodegen project definition
├── package.json                        # Node deps for web editor bundle
├── vite.config.js                      # Vite bundler config
├── web/                                # Web editor source (JS/CSS/HTML)
│   ├── index.html                      # Editor HTML shell
│   ├── src/
│   │   ├── main.js                     # Entry point — initializes bridge, modes
│   │   ├── bridge.js                   # Swift ↔ JS message passing
│   │   ├── reader.js                   # Read mode — markdown-it rendering
│   │   ├── editor.js                   # Edit mode — Milkdown WYSIWYG setup
│   │   ├── search.js                   # In-file find/replace
│   │   └── styles.css                  # All editor + reader styles
├── Sources/
│   ├── App/
│   │   ├── MDMgrApp.swift              # @main app entry, window + commands
│   │   └── Info.plist                  # UTI declarations, file associations
│   ├── Models/
│   │   ├── AppState.swift              # @Observable app-wide state
│   │   ├── Tab.swift                   # Tab model (file URL, content, dirty, mode)
│   │   └── FileNode.swift              # Recursive file tree node
│   ├── Views/
│   │   ├── ContentView.swift           # NavigationSplitView — sidebar + detail
│   │   ├── SidebarView.swift           # File tree with OutlineGroup
│   │   ├── TabBarView.swift            # Horizontal tab strip
│   │   ├── EditorWebView.swift         # NSViewRepresentable wrapping WKWebView
│   │   ├── SearchPanel.swift           # Folder-wide search results
│   │   └── ExportSheet.swift           # Export format picker
│   ├── Services/
│   │   ├── FileTreeLoader.swift        # Scan directory → [FileNode]
│   │   ├── FileWatcher.swift           # DispatchSource directory monitor
│   │   ├── FolderSearchService.swift   # Full-text search across .md files
│   │   └── ExportService.swift         # PDF + HTML export
│   └── Bridge/
│       └── WebViewCoordinator.swift    # WKScriptMessageHandler + JS evaluation
├── Tests/
│   ├── TabTests.swift                  # Tab model logic
│   ├── AppStateTests.swift             # Tab management, open/close/switch
│   ├── FileNodeTests.swift             # File tree building
│   ├── FileTreeLoaderTests.swift       # Directory scanning
│   └── BridgeMessageTests.swift        # JSON encode/decode for bridge
├── Resources/
│   ├── Assets.xcassets/                # App icon
│   │   └── AppIcon.appiconset/
│   │       └── Contents.json
│   └── WebEditor/                      # Built web bundle (vite output destination)
└── docs/
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `project.yml`
- Create: `Sources/App/MDMgrApp.swift`
- Create: `Sources/App/Info.plist`
- Create: `Sources/Views/ContentView.swift`
- Create: `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Install xcodegen if not present**

Run:
```bash
which xcodegen || brew install xcodegen
```
Expected: path to xcodegen binary

- [ ] **Step 2: Create project.yml**

```yaml
name: MDMgr
options:
  bundleIdPrefix: com.mdmgr
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  createIntermediateGroups: true

targets:
  MDMgr:
    type: application
    platform: macOS
    sources:
      - path: Sources
    resources:
      - path: Resources
    settings:
      base:
        PRODUCT_NAME: MD Mgr
        PRODUCT_BUNDLE_IDENTIFIER: com.mdmgr.app
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        INFOPLIST_FILE: Sources/App/Info.plist
        SWIFT_VERSION: "5.10"
        MACOSX_DEPLOYMENT_TARGET: "14.0"
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
        DEVELOPMENT_TEAM: ""

  MDMgrTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests
    dependencies:
      - target: MDMgr
    settings:
      base:
        SWIFT_VERSION: "5.10"
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MD Mgr.app/Contents/MacOS/MD Mgr"
```

- [ ] **Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MD Mgr</string>
    <key>CFBundleDisplayName</key>
    <string>MD Mgr</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Default</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.plain-text</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
                <string>mdown</string>
                <string>mkd</string>
            </array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key>
            <string>Markdown Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>md</string>
                    <string>markdown</string>
                    <string>mdown</string>
                    <string>mkd</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Create minimal MDMgrApp.swift**

```swift
import SwiftUI

@main
struct MDMgrApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 5: Create minimal ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
                .frame(minWidth: 200)
        } detail: {
            Text("Open a markdown file to get started")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
```

- [ ] **Step 6: Create Assets.xcassets**

`Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Resources/Assets.xcassets/Contents.json`:
```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 7: Create .gitignore**

```
MDMgr.xcodeproj/
build/
DerivedData/
.superpowers/
node_modules/
*.xcworkspace
.DS_Store
```

Note: `Resources/WebEditor/` is intentionally NOT ignored — the built web bundle is committed so the Xcode project builds without requiring Node.js.

- [ ] **Step 8: Generate Xcode project and verify build**

Run:
```bash
cd /Users/denver/src/md-mgr && xcodegen generate
```
Expected: `⚙  Generating plists...` then `Created project at ...`

Run:
```bash
xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add project.yml Sources/ Resources/ .gitignore
git commit -m "feat: scaffold macOS app with xcodegen"
```

---

### Task 2: Data Models

**Files:**
- Create: `Sources/Models/Tab.swift`
- Create: `Sources/Models/FileNode.swift`
- Create: `Sources/Models/AppState.swift`
- Create: `Tests/TabTests.swift`
- Create: `Tests/AppStateTests.swift`
- Create: `Tests/FileNodeTests.swift`

- [ ] **Step 1: Write failing tests for Tab**

```swift
// Tests/TabTests.swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|error:|BUILD)"
```
Expected: Compilation errors — `Tab` not defined

- [ ] **Step 3: Implement Tab model**

```swift
// Sources/Models/Tab.swift
import Foundation

enum TabMode: Equatable {
    case read
    case edit
}

@Observable
final class Tab: Identifiable {
    let id = UUID()
    let fileURL: URL
    var content: String
    var isDirty: Bool = false
    var mode: TabMode = .read
    var scrollPosition: CGFloat = 0

    var displayName: String {
        fileURL.lastPathComponent
    }

    init(fileURL: URL, content: String) {
        self.fileURL = fileURL
        self.content = content
    }
}
```

- [ ] **Step 4: Run Tab tests to verify they pass**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|BUILD)"
```
Expected: All TabTests pass, `** BUILD SUCCEEDED **`

- [ ] **Step 5: Write failing tests for FileNode**

```swift
// Tests/FileNodeTests.swift
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
```

- [ ] **Step 6: Implement FileNode**

```swift
// Sources/Models/FileNode.swift
import Foundation

struct FileNode: Identifiable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]

    var name: String { url.lastPathComponent }

    var isMarkdown: Bool {
        let ext = url.pathExtension.lowercased()
        return ["md", "markdown", "mdown", "mkd"].contains(ext)
    }

    var sortedChildren: [FileNode] {
        children.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    init(url: URL, isDirectory: Bool, children: [FileNode] = []) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }
}
```

- [ ] **Step 7: Run FileNode tests**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|BUILD)"
```
Expected: All FileNodeTests pass

- [ ] **Step 8: Write failing tests for AppState**

```swift
// Tests/AppStateTests.swift
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
```

- [ ] **Step 9: Implement AppState**

```swift
// Sources/Models/AppState.swift
import SwiftUI
import WebKit

@Observable
final class AppState {
    var tabs: [Tab] = []
    var activeTabIndex: Int = 0
    var folderURL: URL?
    var fileTree: [FileNode] = []
    var isSearching: Bool = false
    var searchQuery: String = ""
    var showExportSheet: Bool = false
    var activeWebView: WKWebView?

    @AppStorage("lastFolderPath") var lastFolderPath: String = ""

    var activeTab: Tab? {
        guard !tabs.isEmpty, activeTabIndex >= 0, activeTabIndex < tabs.count else {
            return nil
        }
        return tabs[activeTabIndex]
    }

    func openTab(fileURL: URL, content: String) {
        if let existingIndex = tabs.firstIndex(where: { $0.fileURL == fileURL }) {
            activeTabIndex = existingIndex
            return
        }
        let tab = Tab(fileURL: fileURL, content: content)
        let insertIndex = tabs.isEmpty ? 0 : activeTabIndex + 1
        tabs.insert(tab, at: insertIndex)
        activeTabIndex = insertIndex
    }

    func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            activeTabIndex = 0
        } else if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        }
    }

    func openFile(at url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            openTab(fileURL: url, content: content)
        } catch {
            // File read error — silently ignored for now
        }
    }

    func saveActiveTab() {
        guard let tab = activeTab else { return }
        saveTab(tab)
    }

    func saveTab(_ tab: Tab) {
        do {
            try tab.content.write(to: tab.fileURL, atomically: true, encoding: .utf8)
            tab.isDirty = false
        } catch {
            // Save error — could show alert in future
        }
    }

    func closeTabWithConfirmation(at index: Int) -> Bool {
        guard index >= 0, index < tabs.count else { return false }
        if tabs[index].isDirty {
            return false
        }
        closeTab(at: index)
        return true
    }
}
```

- [ ] **Step 10: Run all model tests**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|BUILD)"
```
Expected: All tests pass

- [ ] **Step 11: Commit**

```bash
git add Sources/Models/ Tests/
git commit -m "feat: add Tab, FileNode, and AppState models with tests"
```

---

### Task 3: File Tree Loader

**Files:**
- Create: `Sources/Services/FileTreeLoader.swift`
- Create: `Tests/FileTreeLoaderTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// Tests/FileTreeLoaderTests.swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|error:|BUILD)"
```
Expected: FAIL — `FileTreeLoader` not defined

- [ ] **Step 3: Implement FileTreeLoader**

```swift
// Sources/Services/FileTreeLoader.swift
import Foundation

enum FileTreeLoader {
    static func load(directory: URL, markdownOnly: Bool) throws -> [FileNode] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        )

        var nodes: [FileNode] = []

        for url in contents {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = resourceValues.isDirectory ?? false

            if isDir {
                let children = try load(directory: url, markdownOnly: markdownOnly)
                if !markdownOnly || !children.isEmpty {
                    nodes.append(FileNode(url: url, isDirectory: true, children: children))
                }
            } else {
                let node = FileNode(url: url, isDirectory: false)
                if !markdownOnly || node.isMarkdown {
                    nodes.append(node)
                }
            }
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|BUILD)"
```
Expected: All FileTreeLoaderTests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/FileTreeLoader.swift Tests/FileTreeLoaderTests.swift
git commit -m "feat: add FileTreeLoader service with recursive directory scanning"
```

---

### Task 4: Sidebar & Main Layout

**Files:**
- Modify: `Sources/Views/ContentView.swift`
- Create: `Sources/Views/SidebarView.swift`
- Modify: `Sources/App/MDMgrApp.swift`

- [ ] **Step 1: Create SidebarView**

```swift
// Sources/Views/SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.fileTree.isEmpty {
                ContentUnavailableView {
                    Label("No Folder Open", systemImage: "folder")
                } description: {
                    Text("Open a folder to browse markdown files")
                } actions: {
                    Button("Open Folder…") {
                        openFolder()
                    }
                }
            } else {
                List(selection: Binding<URL?>(
                    get: { appState.activeTab?.fileURL },
                    set: { url in
                        if let url { appState.openFile(at: url) }
                    }
                )) {
                    ForEach(appState.fileTree, id: \.id) { node in
                        FileNodeRow(node: node)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
            }
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.folderURL = url
            appState.lastFolderPath = url.path
            reloadTree()
        }
    }

    func reloadTree() {
        guard let folder = appState.folderURL else { return }
        do {
            appState.fileTree = try FileTreeLoader.load(directory: folder, markdownOnly: true)
        } catch {
            appState.fileTree = []
        }
    }
}

struct FileNodeRow: View {
    let node: FileNode

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                ForEach(node.sortedChildren, id: \.id) { child in
                    FileNodeRow(node: child)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else {
            Label(node.name, systemImage: "doc.text")
                .tag(node.url)
        }
    }
}
```

- [ ] **Step 2: Update ContentView**

```swift
// Sources/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
        } detail: {
            if appState.activeTab != nil {
                Text("Editor placeholder — \(appState.activeTab!.displayName)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("No File Open", systemImage: "doc.text")
                } description: {
                    Text("Open a file from the sidebar or Finder")
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            restoreLastFolder()
        }
    }

    private func restoreLastFolder() {
        let path = appState.lastFolderPath
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            appState.folderURL = url
            do {
                appState.fileTree = try FileTreeLoader.load(directory: url, markdownOnly: true)
            } catch {}
        }
    }
}
```

- [ ] **Step 3: Update MDMgrApp to own AppState and handle file URLs**

```swift
// Sources/App/MDMgrApp.swift
import SwiftUI

@main
struct MDMgrApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onOpenURL { url in
                    appState.openFile(at: url)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.plainText]
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK {
                        for url in panel.urls {
                            appState.openFile(at: url)
                        }
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
```

- [ ] **Step 4: Build and verify**

Run:
```bash
xcodegen generate && xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/Views/ Sources/App/MDMgrApp.swift
git commit -m "feat: add sidebar file tree and main layout"
```

---

### Task 5: Tab Bar

**Files:**
- Create: `Sources/Views/TabBarView.swift`
- Modify: `Sources/Views/ContentView.swift`
- Modify: `Sources/App/MDMgrApp.swift`

- [ ] **Step 1: Create TabBarView**

```swift
// Sources/Views/TabBarView.swift
import SwiftUI

struct TabBarView: View {
    @Bindable var appState: AppState
    var onClose: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(appState.tabs.enumerated()), id: \.element.id) { index, tab in
                    TabItemView(
                        tab: tab,
                        isActive: index == appState.activeTabIndex,
                        onSelect: { appState.activeTabIndex = index },
                        onClose: { onClose(index) }
                    )
                }
            }
        }
        .frame(height: 32)
        .background(.bar)
    }
}

struct TabItemView: View {
    let tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if tab.isDirty {
                Circle()
                    .fill(.primary)
                    .frame(width: 6, height: 6)
            }
            Text(tab.displayName)
                .font(.callout)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
    }
}
```

- [ ] **Step 2: Wire TabBarView into ContentView with unsaved changes handling**

```swift
// Sources/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var tabToClose: Int?
    @State private var showUnsavedAlert = false

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
        } detail: {
            VStack(spacing: 0) {
                if !appState.tabs.isEmpty {
                    TabBarView(appState: appState, onClose: handleTabClose)
                    Divider()
                    if let tab = appState.activeTab {
                        Text(tab.content)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding()
                            .font(.body.monospaced())
                    }
                } else {
                    ContentUnavailableView {
                        Label("No File Open", systemImage: "doc.text")
                    } description: {
                        Text("Open a file from the sidebar or Finder")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { restoreLastFolder() }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Save") {
                if let idx = tabToClose {
                    appState.saveTab(appState.tabs[idx])
                    appState.closeTab(at: idx)
                }
            }
            Button("Don't Save", role: .destructive) {
                if let idx = tabToClose { appState.closeTab(at: idx) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save changes before closing?")
        }
    }

    private func handleTabClose(at index: Int) {
        if !appState.closeTabWithConfirmation(at: index) {
            tabToClose = index
            showUnsavedAlert = true
        }
    }

    private func restoreLastFolder() {
        let path = appState.lastFolderPath
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            appState.folderURL = url
            do {
                appState.fileTree = try FileTreeLoader.load(directory: url, markdownOnly: true)
            } catch {}
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url") { data, _ in
                guard let data = data as? Data,
                      let urlString = String(data: data, encoding: .utf8),
                      let url = URL(string: urlString) else { return }
                let ext = url.pathExtension.lowercased()
                if ["md", "markdown", "mdown", "mkd"].contains(ext) {
                    DispatchQueue.main.async {
                        appState.openFile(at: url)
                    }
                }
            }
        }
        return true
    }
}
```

- [ ] **Step 3: Add tab switching and save keyboard shortcuts to MDMgrApp**

```swift
// Sources/App/MDMgrApp.swift
import SwiftUI

@main
struct MDMgrApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onOpenURL { url in
                    appState.openFile(at: url)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.plainText]
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK {
                        for url in panel.urls {
                            appState.openFile(at: url)
                        }
                    }
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        appState.folderURL = url
                        appState.lastFolderPath = url.path
                        do {
                            appState.fileTree = try FileTreeLoader.load(directory: url, markdownOnly: true)
                        } catch {}
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appState.saveActiveTab()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.activeTab == nil || !(appState.activeTab?.isDirty ?? false))
            }

            CommandGroup(after: .windowArrangement) {
                Button("Next Tab") {
                    if !appState.tabs.isEmpty {
                        appState.activeTabIndex = (appState.activeTabIndex + 1) % appState.tabs.count
                    }
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    if !appState.tabs.isEmpty {
                        appState.activeTabIndex = (appState.activeTabIndex - 1 + appState.tabs.count) % appState.tabs.count
                    }
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Close Tab") {
                    appState.closeTab(at: appState.activeTabIndex)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
    }
}
```

- [ ] **Step 4: Build and verify**

Run:
```bash
xcodegen generate && xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/Views/TabBarView.swift Sources/Views/ContentView.swift Sources/App/MDMgrApp.swift
git commit -m "feat: add tab bar with keyboard shortcuts, drag-and-drop, and unsaved changes"
```

---

### Task 6: Web Editor Bundle

**Files:**
- Create: `package.json`
- Create: `vite.config.js`
- Create: `web/index.html`
- Create: `web/src/main.js`
- Create: `web/src/bridge.js`
- Create: `web/src/reader.js`
- Create: `web/src/styles.css`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "md-mgr-web",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "dependencies": {
    "@milkdown/core": "^7.6.0",
    "@milkdown/ctx": "^7.6.0",
    "@milkdown/preset-commonmark": "^7.6.0",
    "@milkdown/preset-gfm": "^7.6.0",
    "@milkdown/plugin-listener": "^7.6.0",
    "@milkdown/theme-nord": "^7.6.0",
    "dompurify": "^3.1.0",
    "highlight.js": "^11.10.0",
    "markdown-it": "^14.1.0"
  },
  "devDependencies": {
    "vite": "^6.0.0"
  }
}
```

- [ ] **Step 2: Create vite.config.js**

```javascript
// vite.config.js
import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  root: 'web',
  build: {
    outDir: resolve(__dirname, 'Resources/WebEditor'),
    emptyOutDir: true,
    rollupOptions: {
      input: resolve(__dirname, 'web/index.html'),
    },
  },
  base: './',
});
```

- [ ] **Step 3: Create web/index.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MD Mgr Editor</title>
    <link rel="stylesheet" href="./src/styles.css">
</head>
<body>
    <div id="toolbar" class="toolbar hidden">
        <button data-action="bold" title="Bold (⌘B)"><b>B</b></button>
        <button data-action="italic" title="Italic (⌘I)"><i>I</i></button>
        <span class="separator"></span>
        <button data-action="h1" title="Heading 1">H1</button>
        <button data-action="h2" title="Heading 2">H2</button>
        <button data-action="h3" title="Heading 3">H3</button>
        <span class="separator"></span>
        <button data-action="bullet" title="Bullet List">&#8226;</button>
        <button data-action="ordered" title="Numbered List">1.</button>
        <button data-action="task" title="Task List">&#9744;</button>
        <span class="separator"></span>
        <button data-action="code" title="Code">&lt;/&gt;</button>
        <button data-action="codeBlock" title="Code Block">{ }</button>
        <button data-action="quote" title="Block Quote">&ldquo;</button>
        <button data-action="link" title="Link (⌘K)">Link</button>
        <button data-action="hr" title="Horizontal Rule">&mdash;</button>
    </div>
    <div id="reader" class="reader"></div>
    <div id="editor" class="editor hidden"></div>
    <script type="module" src="./src/main.js"></script>
</body>
</html>
```

- [ ] **Step 4: Create web/src/bridge.js**

```javascript
// web/src/bridge.js

export function sendToSwift(type, payload = {}) {
    if (window.webkit?.messageHandlers?.bridge) {
        window.webkit.messageHandlers.bridge.postMessage(
            JSON.stringify({ type, ...payload })
        );
    }
}

const handlers = {};

export function onSwiftMessage(type, handler) {
    handlers[type] = handler;
}

window.handleSwiftMessage = function(jsonString) {
    const msg = JSON.parse(jsonString);
    const handler = handlers[msg.type];
    if (handler) {
        handler(msg);
    }
};
```

- [ ] **Step 5: Create web/src/reader.js**

```javascript
// web/src/reader.js
import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';
import hljs from 'highlight.js';
import 'highlight.js/styles/github.css';

const md = new MarkdownIt({
    html: true,
    linkify: true,
    typographer: true,
    highlight(str, lang) {
        if (lang && hljs.getLanguage(lang)) {
            try {
                return hljs.highlight(str, { language: lang }).value;
            } catch (_) {}
        }
        return '';
    }
});

export function renderMarkdown(content) {
    const rawHTML = md.render(content);
    return DOMPurify.sanitize(rawHTML, {
        ADD_TAGS: ['input'],
        ADD_ATTR: ['type', 'checked', 'disabled']
    });
}

export function showReader(container, content) {
    container.textContent = '';
    const rendered = renderMarkdown(content);
    const wrapper = document.createElement('div');
    wrapper.innerHTML = DOMPurify.sanitize(rendered, {
        ADD_TAGS: ['input'],
        ADD_ATTR: ['type', 'checked', 'disabled']
    });
    container.appendChild(wrapper);
    container.classList.remove('hidden');
}
```

- [ ] **Step 6: Create web/src/styles.css**

```css
/* web/src/styles.css */
:root {
    --bg: #ffffff;
    --fg: #1d1d1f;
    --secondary: #86868b;
    --border: #d2d2d7;
    --code-bg: #f5f5f7;
    --accent: #007aff;
    --toolbar-bg: #f5f5f7;
}

@media (prefers-color-scheme: dark) {
    :root {
        --bg: #1d1d1f;
        --fg: #f5f5f7;
        --secondary: #86868b;
        --border: #424245;
        --code-bg: #2c2c2e;
        --accent: #0a84ff;
        --toolbar-bg: #2c2c2e;
    }
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
    font-size: 15px;
    line-height: 1.6;
    color: var(--fg);
    background: var(--bg);
}

.hidden { display: none !important; }

/* Toolbar */
.toolbar {
    position: sticky;
    top: 0;
    z-index: 10;
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 4px 8px;
    background: var(--toolbar-bg);
    border-bottom: 1px solid var(--border);
}

.toolbar button {
    background: none;
    border: 1px solid transparent;
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 13px;
    color: var(--fg);
    cursor: pointer;
    min-width: 28px;
    text-align: center;
}

.toolbar button:hover { background: var(--border); }

.toolbar .separator {
    width: 1px;
    height: 20px;
    background: var(--border);
    margin: 0 4px;
}

/* Reader */
.reader {
    padding: 24px 32px;
    max-width: 800px;
    margin: 0 auto;
}

.reader h1 { font-size: 2em; margin: 0.8em 0 0.4em; font-weight: 700; }
.reader h2 { font-size: 1.5em; margin: 0.8em 0 0.4em; font-weight: 600; }
.reader h3 { font-size: 1.2em; margin: 0.8em 0 0.4em; font-weight: 600; }
.reader h4 { font-size: 1em; margin: 0.8em 0 0.4em; font-weight: 600; }

.reader p { margin: 0.6em 0; }
.reader a { color: var(--accent); text-decoration: none; }
.reader a:hover { text-decoration: underline; }

.reader code {
    font-family: 'SF Mono', Menlo, monospace;
    font-size: 0.9em;
    background: var(--code-bg);
    padding: 2px 6px;
    border-radius: 4px;
}

.reader pre {
    background: var(--code-bg);
    border-radius: 8px;
    padding: 16px;
    overflow-x: auto;
    margin: 1em 0;
}

.reader pre code { background: none; padding: 0; font-size: 13px; line-height: 1.5; }

.reader blockquote {
    border-left: 3px solid var(--accent);
    padding-left: 16px;
    color: var(--secondary);
    margin: 1em 0;
}

.reader table { border-collapse: collapse; margin: 1em 0; width: 100%; }
.reader th, .reader td { border: 1px solid var(--border); padding: 8px 12px; text-align: left; }
.reader th { background: var(--code-bg); font-weight: 600; }
.reader ul, .reader ol { padding-left: 24px; margin: 0.6em 0; }
.reader li { margin: 0.3em 0; }
.reader hr { border: none; border-top: 1px solid var(--border); margin: 2em 0; }
.reader img { max-width: 100%; border-radius: 8px; margin: 1em 0; }

/* Editor (Milkdown) */
.editor {
    padding: 24px 32px;
    max-width: 800px;
    margin: 0 auto;
    min-height: 100vh;
}

.editor .milkdown { outline: none; }
.editor .milkdown p { margin: 0.6em 0; }
.editor .milkdown h1 { font-size: 2em; margin: 0.8em 0 0.4em; font-weight: 700; }
.editor .milkdown h2 { font-size: 1.5em; margin: 0.8em 0 0.4em; font-weight: 600; }
.editor .milkdown h3 { font-size: 1.2em; margin: 0.8em 0 0.4em; font-weight: 600; }

.editor .milkdown code {
    font-family: 'SF Mono', Menlo, monospace;
    font-size: 0.9em;
    background: var(--code-bg);
    padding: 2px 6px;
    border-radius: 4px;
}

.editor .milkdown pre {
    background: var(--code-bg);
    border-radius: 8px;
    padding: 16px;
    overflow-x: auto;
    margin: 1em 0;
}

.editor .milkdown blockquote {
    border-left: 3px solid var(--accent);
    padding-left: 16px;
    color: var(--secondary);
}

@media (prefers-color-scheme: dark) {
    .hljs { background: var(--code-bg) !important; color: var(--fg) !important; }
}
```

- [ ] **Step 7: Create web/src/main.js (read-mode only for now)**

```javascript
// web/src/main.js
import { sendToSwift, onSwiftMessage } from './bridge.js';
import { showReader } from './reader.js';
import './styles.css';

const readerEl = document.getElementById('reader');
const editorEl = document.getElementById('editor');
const toolbarEl = document.getElementById('toolbar');

let currentMode = 'read';
let currentContent = '';

onSwiftMessage('loadContent', (msg) => {
    currentContent = msg.content;
    if (currentMode === 'read') {
        showReader(readerEl, currentContent);
    }
});

onSwiftMessage('setMode', (msg) => {
    currentMode = msg.mode;
    if (currentMode === 'read') {
        showReader(readerEl, currentContent);
        readerEl.classList.remove('hidden');
        editorEl.classList.add('hidden');
        toolbarEl.classList.add('hidden');
    } else {
        readerEl.classList.add('hidden');
        editorEl.classList.remove('hidden');
        toolbarEl.classList.remove('hidden');
        // Milkdown editor activation added in Task 8
    }
});

onSwiftMessage('setBaseURL', (msg) => {
    document.querySelector('base')?.remove();
    const base = document.createElement('base');
    base.href = msg.url;
    document.head.prepend(base);
});

readerEl.addEventListener('dblclick', () => {
    sendToSwift('requestEdit');
});

sendToSwift('ready');
```

- [ ] **Step 8: Install dependencies and build**

Run:
```bash
cd /Users/denver/src/md-mgr && npm install && npm run build
```
Expected: Vite build completes, output in `Resources/WebEditor/`

Run:
```bash
ls Resources/WebEditor/
```
Expected: `index.html`, `assets/` directory with JS/CSS bundles

- [ ] **Step 9: Commit**

```bash
git add package.json vite.config.js web/ Resources/WebEditor/
git commit -m "feat: add web editor bundle with reader mode, bridge, and styles"
```

---

### Task 7: WKWebView Integration & Bridge

**Files:**
- Create: `Sources/Views/EditorWebView.swift`
- Create: `Sources/Bridge/WebViewCoordinator.swift`
- Modify: `Sources/Views/ContentView.swift`
- Create: `Tests/BridgeMessageTests.swift`

- [ ] **Step 1: Write failing test for bridge message encoding**

```swift
// Tests/BridgeMessageTests.swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|error:|BUILD)"
```
Expected: FAIL — `WebViewCoordinator` not defined

- [ ] **Step 3: Create WebViewCoordinator**

```swift
// Sources/Bridge/WebViewCoordinator.swift
import WebKit

final class WebViewCoordinator: NSObject, WKScriptMessageHandler {
    var onContentChanged: ((String) -> Void)?
    var onRequestEdit: (() -> Void)?
    var onRequestRead: (() -> Void)?
    var onReady: (() -> Void)?
    var lastSentContent: String?
    var lastSentMode: TabMode?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "contentChanged":
            if let content = json["content"] as? String {
                onContentChanged?(content)
            }
        case "requestEdit":
            onRequestEdit?()
        case "requestRead":
            onRequestRead?()
        case "ready":
            onReady?()
        default:
            break
        }
    }

    // MARK: - Message builders

    static func loadContentJSON(content: String) -> String {
        let payload: [String: Any] = ["type": "loadContent", "content": content]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8)!
    }

    static func setModeJSON(mode: TabMode) -> String {
        let modeStr = mode == .edit ? "edit" : "read"
        let payload: [String: Any] = ["type": "setMode", "mode": modeStr]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8)!
    }

    static func searchJSON(query: String) -> String {
        let payload: [String: Any] = ["type": "search", "query": query]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8)!
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|BUILD)"
```
Expected: All BridgeMessageTests pass

- [ ] **Step 5: Create EditorWebView**

```swift
// Sources/Views/EditorWebView.swift
import SwiftUI
import WebKit

struct EditorWebView: NSViewRepresentable {
    let tab: Tab
    let coordinator: WebViewCoordinator
    var onWebViewCreated: ((WKWebView) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(coordinator, name: "bridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("WebEditor") {
            let indexURL = resourceURL.appendingPathComponent("index.html")
            webView.loadFileURL(indexURL, allowingReadAccessTo: resourceURL)
        }

        coordinator.onReady = { [weak webView] in
            guard let webView else { return }
            let json = WebViewCoordinator.loadContentJSON(content: tab.content)
            webView.evaluateJavaScript("handleSwiftMessage('\(json.jsEscaped)')")

            let baseDir = tab.fileURL.deletingLastPathComponent().absoluteString
            let baseJSON = "{\"type\":\"setBaseURL\",\"url\":\"\(baseDir)\"}"
            webView.evaluateJavaScript("handleSwiftMessage('\(baseJSON.jsEscaped)')")
        }

        coordinator.onContentChanged = { content in
            DispatchQueue.main.async {
                tab.content = content
                tab.isDirty = true
            }
        }

        coordinator.onRequestEdit = {
            DispatchQueue.main.async { tab.mode = .edit }
        }

        coordinator.onRequestRead = {
            DispatchQueue.main.async { tab.mode = .read }
        }

        onWebViewCreated?(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if coordinator.lastSentMode != tab.mode {
            coordinator.lastSentMode = tab.mode
            let json = WebViewCoordinator.setModeJSON(mode: tab.mode)
            webView.evaluateJavaScript("handleSwiftMessage('\(json.jsEscaped)')")
        }
        if coordinator.lastSentContent != tab.content {
            coordinator.lastSentContent = tab.content
            let json = WebViewCoordinator.loadContentJSON(content: tab.content)
            webView.evaluateJavaScript("handleSwiftMessage('\(json.jsEscaped)')")
        }
    }
}

extension String {
    var jsEscaped: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
```

- [ ] **Step 6: Wire EditorWebView into ContentView**

Replace the text placeholder in ContentView's detail section:

```swift
// In ContentView, replace the Text(tab.content) placeholder with:
if let tab = appState.activeTab {
    HStack {
        Spacer()
        Button(tab.mode == .read ? "Edit" : "Done") {
            tab.mode = tab.mode == .read ? .edit : .read
        }
        .controlSize(.small)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)

    EditorWebView(tab: tab, coordinator: coordinatorForTab(tab)) { webView in
        appState.activeWebView = webView
    }
}
```

Add coordinator management:

```swift
@State private var coordinators: [UUID: WebViewCoordinator] = [:]

private func coordinatorForTab(_ tab: Tab) -> WebViewCoordinator {
    if let existing = coordinators[tab.id] {
        return existing
    }
    let coordinator = WebViewCoordinator()
    coordinators[tab.id] = coordinator
    return coordinator
}
```

- [ ] **Step 7: Build and verify**

Run:
```bash
xcodegen generate && xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add Sources/Views/EditorWebView.swift Sources/Bridge/ Sources/Views/ContentView.swift Tests/BridgeMessageTests.swift
git commit -m "feat: integrate WKWebView with Swift-JS bridge for read mode"
```

---

### Task 8: Edit Mode (Milkdown WYSIWYG)

**Files:**
- Create: `web/src/editor.js`
- Modify: `web/src/main.js`

- [ ] **Step 1: Create web/src/editor.js**

```javascript
// web/src/editor.js
import { Editor, rootCtx, defaultValueCtx } from '@milkdown/core';
import { commonmark } from '@milkdown/preset-commonmark';
import { gfm } from '@milkdown/preset-gfm';
import { listener, listenerCtx } from '@milkdown/plugin-listener';
import { nord } from '@milkdown/theme-nord';

let editorInstance = null;

export async function createEditor(container, content, onChange) {
    if (editorInstance) {
        await editorInstance.destroy();
    }

    editorInstance = await Editor.make()
        .config((ctx) => {
            ctx.set(rootCtx, container);
            ctx.set(defaultValueCtx, content);
            ctx.set(listenerCtx, {
                markdown: [(getMarkdown) => {
                    onChange(getMarkdown());
                }]
            });
        })
        .config(nord)
        .use(commonmark)
        .use(gfm)
        .use(listener)
        .create();

    return editorInstance;
}

export async function destroyEditor() {
    if (editorInstance) {
        await editorInstance.destroy();
        editorInstance = null;
    }
}

export function setupToolbar(toolbarEl) {
    toolbarEl.addEventListener('click', (e) => {
        const btn = e.target.closest('button');
        if (!btn || !editorInstance) return;
        const action = btn.dataset.action;
        if (action) {
            editorInstance.action((ctx) => {
                const commands = ctx.get('commandManager');
                const commandMap = {
                    bold: 'ToggleBold',
                    italic: 'ToggleItalic',
                    h1: 'TurnIntoHeading',
                    h2: 'TurnIntoHeading',
                    h3: 'TurnIntoHeading',
                    bullet: 'WrapInBulletList',
                    ordered: 'WrapInOrderedList',
                    task: 'TurnIntoTaskList',
                    code: 'ToggleInlineCode',
                    codeBlock: 'TurnIntoCodeBlock',
                    quote: 'WrapInBlockquote',
                    hr: 'InsertHr',
                };
                const cmd = commandMap[action];
                if (cmd) {
                    if (action.startsWith('h')) {
                        commands.call(cmd, parseInt(action.charAt(1)));
                    } else {
                        commands.call(cmd);
                    }
                }
            });
        }
    });
}
```

- [ ] **Step 2: Update main.js to wire up edit mode and Escape key**

```javascript
// web/src/main.js
import { sendToSwift, onSwiftMessage } from './bridge.js';
import { showReader } from './reader.js';
import { createEditor, destroyEditor, setupToolbar } from './editor.js';
import './styles.css';

const readerEl = document.getElementById('reader');
const editorEl = document.getElementById('editor');
const toolbarEl = document.getElementById('toolbar');

let currentMode = 'read';
let currentContent = '';

setupToolbar(toolbarEl);

onSwiftMessage('loadContent', (msg) => {
    currentContent = msg.content;
    if (currentMode === 'read') {
        showReader(readerEl, currentContent);
    }
});

onSwiftMessage('setMode', async (msg) => {
    currentMode = msg.mode;
    if (currentMode === 'read') {
        await destroyEditor();
        showReader(readerEl, currentContent);
        readerEl.classList.remove('hidden');
        editorEl.classList.add('hidden');
        toolbarEl.classList.add('hidden');
    } else {
        readerEl.classList.add('hidden');
        editorEl.classList.remove('hidden');
        toolbarEl.classList.remove('hidden');
        await createEditor(editorEl, currentContent, (markdown) => {
            currentContent = markdown;
            sendToSwift('contentChanged', { content: markdown });
        });
    }
});

onSwiftMessage('getContent', () => {
    sendToSwift('contentResult', { content: currentContent });
});

onSwiftMessage('setBaseURL', (msg) => {
    document.querySelector('base')?.remove();
    const base = document.createElement('base');
    base.href = msg.url;
    document.head.prepend(base);
});

readerEl.addEventListener('dblclick', () => {
    sendToSwift('requestEdit');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && currentMode === 'edit') {
        sendToSwift('requestRead');
    }
});

sendToSwift('ready');
```

- [ ] **Step 3: Rebuild web bundle**

Run:
```bash
cd /Users/denver/src/md-mgr && npm run build
```
Expected: Build succeeds

- [ ] **Step 4: Build Xcode project and verify**

Run:
```bash
xcodegen generate && xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add web/src/ Resources/WebEditor/
git commit -m "feat: add Milkdown WYSIWYG editor with toolbar and mode switching"
```

---

### Task 9: File System Watcher

**Files:**
- Create: `Sources/Services/FileWatcher.swift`
- Modify: `Sources/Views/SidebarView.swift`

- [ ] **Step 1: Create FileWatcher**

```swift
// Sources/Services/FileWatcher.swift
import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let url: URL
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.onChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 2: Wire FileWatcher into SidebarView**

Add to SidebarView:

```swift
@State private var watcher: FileWatcher?
```

Add modifiers to the body:

```swift
.onChange(of: appState.folderURL) { _, newURL in
    watcher?.stop()
    guard let url = newURL else { return }
    let state = appState
    watcher = FileWatcher(url: url) {
        do {
            state.fileTree = try FileTreeLoader.load(directory: url, markdownOnly: true)
        } catch {}
    }
    watcher?.start()
}
.onDisappear {
    watcher?.stop()
}
```

- [ ] **Step 3: Build and verify**

Run:
```bash
xcodegen generate && xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Sources/Services/FileWatcher.swift Sources/Views/SidebarView.swift
git commit -m "feat: add file system watcher for live sidebar updates"
```

---

### Task 10: Folder-Wide Search

**Files:**
- Create: `Sources/Services/FolderSearchService.swift`
- Create: `Sources/Views/SearchPanel.swift`
- Modify: `Sources/Views/ContentView.swift`
- Modify: `Sources/App/MDMgrApp.swift`

- [ ] **Step 1: Create FolderSearchService**

```swift
// Sources/Services/FolderSearchService.swift
import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let lineNumber: Int
    let lineContent: String

    var fileName: String { fileURL.lastPathComponent }
}

enum FolderSearchService {
    static func search(query: String, in folderURL: URL) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        var results: [SearchResult] = []

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let extensions = Set(["md", "markdown", "mdown", "mkd"])

        for case let fileURL as URL in enumerator {
            guard extensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.range(of: query, options: .caseInsensitive) != nil {
                    results.append(SearchResult(
                        fileURL: fileURL,
                        lineNumber: index + 1,
                        lineContent: line
                    ))
                }
            }
        }

        return results
    }
}
```

- [ ] **Step 2: Create SearchPanel**

```swift
// Sources/Views/SearchPanel.swift
import SwiftUI

struct SearchPanel: View {
    @Bindable var appState: AppState
    @State private var results: [SearchResult] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search in folder…", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit { performSearch() }
                if !appState.searchQuery.isEmpty {
                    Button(action: {
                        appState.searchQuery = ""
                        results = []
                        appState.isSearching = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)

            Divider()

            if results.isEmpty && !appState.searchQuery.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass")
                    .frame(maxHeight: .infinity)
            } else {
                List(results) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.fileName)
                            .font(.callout.bold())
                        Text("Line \(result.lineNumber): \(result.lineContent)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.openFile(at: result.fileURL)
                        appState.isSearching = false
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func performSearch() {
        guard let folder = appState.folderURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let found = FolderSearchService.search(query: appState.searchQuery, in: folder)
            DispatchQueue.main.async {
                results = found
            }
        }
    }
}
```

- [ ] **Step 3: Wire search into ContentView sidebar**

In ContentView's NavigationSplitView, replace the sidebar:

```swift
NavigationSplitView {
    if appState.isSearching {
        SearchPanel(appState: appState)
    } else {
        SidebarView(appState: appState)
    }
}
```

- [ ] **Step 4: Add search commands to MDMgrApp**

Add to the commands block:

```swift
CommandGroup(after: .textEditing) {
    Button("Find in Folder") {
        appState.isSearching = true
    }
    .keyboardShortcut("f", modifiers: [.command, .shift])
}
```

- [ ] **Step 5: Add in-file search to web layer**

Create `web/src/search.js`:

```javascript
// web/src/search.js

let currentHighlights = [];
let currentIndex = -1;

export function findInDocument(query) {
    clearHighlights();
    if (!query) return 0;

    const container = document.getElementById('reader');
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT);
    const matches = [];

    while (walker.nextNode()) {
        const node = walker.currentNode;
        const text = node.textContent;
        let idx = text.toLowerCase().indexOf(query.toLowerCase());
        while (idx !== -1) {
            matches.push({ node, index: idx, length: query.length });
            idx = text.toLowerCase().indexOf(query.toLowerCase(), idx + 1);
        }
    }

    for (let i = matches.length - 1; i >= 0; i--) {
        const { node, index, length } = matches[i];
        const range = document.createRange();
        range.setStart(node, index);
        range.setEnd(node, index + length);
        const mark = document.createElement('mark');
        mark.style.background = 'rgba(255, 200, 0, 0.4)';
        mark.style.borderRadius = '2px';
        range.surroundContents(mark);
        currentHighlights.unshift(mark);
    }

    if (currentHighlights.length > 0) {
        currentIndex = 0;
        updateHighlight();
    }

    return currentHighlights.length;
}

function updateHighlight() {
    currentHighlights.forEach((m, i) => {
        m.style.background = i === currentIndex
            ? 'rgba(255, 150, 0, 0.6)'
            : 'rgba(255, 200, 0, 0.4)';
    });
    currentHighlights[currentIndex]?.scrollIntoView({ block: 'center' });
}

export function findNext() {
    if (currentHighlights.length === 0) return;
    currentIndex = (currentIndex + 1) % currentHighlights.length;
    updateHighlight();
}

export function findPrevious() {
    if (currentHighlights.length === 0) return;
    currentIndex = (currentIndex - 1 + currentHighlights.length) % currentHighlights.length;
    updateHighlight();
}

export function clearHighlights() {
    for (const mark of currentHighlights) {
        const parent = mark.parentNode;
        if (parent) {
            parent.replaceChild(document.createTextNode(mark.textContent), mark);
            parent.normalize();
        }
    }
    currentHighlights = [];
    currentIndex = -1;
}
```

Add to `main.js` imports and handlers:

```javascript
import { findInDocument, findNext, findPrevious, clearHighlights } from './search.js';

onSwiftMessage('search', (msg) => {
    const count = findInDocument(msg.query);
    sendToSwift('searchResult', { count });
});

onSwiftMessage('searchNext', () => findNext());
onSwiftMessage('searchPrevious', () => findPrevious());
onSwiftMessage('clearSearch', () => clearHighlights());
```

- [ ] **Step 6: Rebuild web bundle**

Run:
```bash
cd /Users/denver/src/md-mgr && npm run build
```

- [ ] **Step 7: Build and verify**

Run:
```bash
xcodegen generate && xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add Sources/Services/FolderSearchService.swift Sources/Views/SearchPanel.swift Sources/Views/ContentView.swift Sources/App/MDMgrApp.swift web/src/ Resources/WebEditor/
git commit -m "feat: add folder-wide search and in-file find"
```

---

### Task 11: Export (PDF & HTML)

**Files:**
- Create: `Sources/Services/ExportService.swift`
- Create: `Sources/Views/ExportSheet.swift`
- Modify: `Sources/App/MDMgrApp.swift`
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Create ExportService**

```swift
// Sources/Services/ExportService.swift
import WebKit

enum ExportFormat: String, CaseIterable {
    case pdf = "PDF"
    case html = "HTML"
}

enum ExportService {
    static func exportPDF(from webView: WKWebView, to url: URL) async throws {
        let config = WKPDFConfiguration()
        let data = try await webView.pdf(configuration: config)
        try data.write(to: url)
    }

    static func exportHTML(content: String, to url: URL) throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
                    font-size: 15px; line-height: 1.6;
                    max-width: 800px; margin: 0 auto; padding: 24px 32px;
                }
                h1 { font-size: 2em; margin: 0.8em 0 0.4em; }
                h2 { font-size: 1.5em; margin: 0.8em 0 0.4em; }
                h3 { font-size: 1.2em; margin: 0.8em 0 0.4em; }
                code { font-family: 'SF Mono', Menlo, monospace; background: #f5f5f7; padding: 2px 6px; border-radius: 4px; }
                pre { background: #f5f5f7; border-radius: 8px; padding: 16px; overflow-x: auto; }
                pre code { background: none; padding: 0; }
                blockquote { border-left: 3px solid #007aff; padding-left: 16px; color: #86868b; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #d2d2d7; padding: 8px 12px; }
                th { background: #f5f5f7; }
                img { max-width: 100%; }
            </style>
        </head>
        <body>\(content)</body>
        </html>
        """
        try html.write(to: url, atomically: true, encoding: .utf8)
    }
}
```

- [ ] **Step 2: Create ExportSheet**

```swift
// Sources/Views/ExportSheet.swift
import SwiftUI
import WebKit

struct ExportSheet: View {
    let tab: Tab
    let webView: WKWebView?
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Export \(tab.displayName)")
                .font(.headline)

            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Export…") { export() }
                    .keyboardShortcut(.return)
                    .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = selectedFormat == .pdf ? [.pdf] : [.html]
        panel.nameFieldStringValue = tab.fileURL
            .deletingPathExtension()
            .lastPathComponent + (selectedFormat == .pdf ? ".pdf" : ".html")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        Task {
            do {
                switch selectedFormat {
                case .pdf:
                    if let webView {
                        try await ExportService.exportPDF(from: webView, to: url)
                    }
                case .html:
                    try ExportService.exportHTML(content: tab.content, to: url)
                }
            } catch {}
            isExporting = false
            dismiss()
        }
    }
}
```

- [ ] **Step 3: Add export command and wire sheet**

Add to MDMgrApp commands (in the `CommandGroup(replacing: .saveItem)` block, after the Save button):

```swift
Button("Export…") {
    appState.showExportSheet = true
}
.keyboardShortcut("e", modifiers: .command)
.disabled(appState.activeTab == nil)
```

Add sheet modifier to ContentView:

```swift
.sheet(isPresented: $appState.showExportSheet) {
    if let tab = appState.activeTab {
        ExportSheet(tab: tab, webView: appState.activeWebView)
    }
}
```

- [ ] **Step 4: Build and verify**

Run:
```bash
xcodegen generate && xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Debug build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/ExportService.swift Sources/Views/ExportSheet.swift Sources/Views/ContentView.swift Sources/App/MDMgrApp.swift
git commit -m "feat: add PDF and HTML export with Cmd+E shortcut"
```

---

### Task 12: Final Polish & Verification

**Files:**
- Modify: `Sources/App/MDMgrApp.swift`
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Add Toggle Edit Mode command**

Add to MDMgrApp commands:

```swift
CommandGroup(after: .windowArrangement) {
    // ... existing tab switching commands ...

    Divider()

    Button("Toggle Edit Mode") {
        if let tab = appState.activeTab {
            tab.mode = tab.mode == .read ? .edit : .read
        }
    }
    .keyboardShortcut(.return, modifiers: .command)
    .disabled(appState.activeTab == nil)
}
```

- [ ] **Step 2: Run full test suite**

Run:
```bash
xcodegen generate && xcodebuild test -project MDMgr.xcodeproj -scheme MDMgr 2>&1 | grep -E "(Test Case|Executed|BUILD)"
```
Expected: All tests pass, `** BUILD SUCCEEDED **`

- [ ] **Step 3: Build release**

Run:
```bash
xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Release build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Launch and smoke test**

Run:
```bash
open "$(xcodebuild -project MDMgr.xcodeproj -scheme MDMgr -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/MD Mgr.app"
```

Manual verification:
1. App launches — empty state shows "No Folder Open" / "No File Open"
2. Open Folder → sidebar populates with `.md` files
3. Click file → renders as styled HTML
4. Double-click or Edit button → WYSIWYG editor with toolbar
5. Make edit → dirty dot appears on tab
6. Cmd+S → saves, dot disappears
7. Escape → back to read mode
8. Cmd+Shift+F → search panel
9. Cmd+E → export dialog
10. Toggle dark mode in System Settings → app follows

- [ ] **Step 5: Commit**

```bash
git add Sources/
git commit -m "feat: final polish — edit toggle command and full menu bar"
```
