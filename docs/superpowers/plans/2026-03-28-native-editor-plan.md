# Native Editor Rearchitecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace WKWebView + HTML/JS/bridge with a fully native NSTextView for both markdown rendering (read mode) and editing (edit mode with syntax highlighting).

**Architecture:** A single `MarkdownTextView` (NSViewRepresentable wrapping NSTextView) handles both modes. `MarkdownRenderer` converts markdown → styled NSAttributedString for read mode. `MarkdownSyntaxHighlighter` colors raw markdown in edit mode. All web-layer code is deleted.

**Tech Stack:** Swift/SwiftUI (macOS 14+), AppKit (NSTextView, NSAttributedString), NSTextStorageDelegate

---

## File Structure

After this plan is complete:

```
Sources/
├── App/
│   └── MDMgrApp.swift              # (modified — no changes needed)
├── Models/
│   ├── AppState.swift              # (modified — remove WebKit, activeWebView)
│   ├── Tab.swift                   # (unchanged)
│   └── FileNode.swift              # (unchanged)
├── Views/
│   ├── ContentView.swift           # (modified — MarkdownTextView replaces EditorWebView)
│   ├── SidebarView.swift           # (unchanged)
│   ├── TabBarView.swift            # (unchanged)
│   ├── MarkdownTextView.swift      # NEW — NSViewRepresentable wrapping NSTextView
│   ├── SearchPanel.swift           # (unchanged)
│   └── ExportSheet.swift           # (modified — remove WKWebView param)
├── Services/
│   ├── MarkdownRenderer.swift      # NEW — markdown → NSAttributedString (read mode)
│   ├── MarkdownSyntaxHighlighter.swift  # NEW — edit mode syntax coloring
│   ├── ExportService.swift         # (modified — PDF via attributed string, not WebView)
│   ├── FileTreeLoader.swift        # (unchanged)
│   ├── FileWatcher.swift           # (unchanged)
│   └── FolderSearchService.swift   # (unchanged)
Tests/
├── MarkdownRendererTests.swift     # NEW
├── AppStateTests.swift             # (unchanged)
├── FileNodeTests.swift             # (unchanged)
├── FileTreeLoaderTests.swift       # (unchanged)
└── TabTests.swift                  # (unchanged)

DELETED:
├── Sources/Views/EditorWebView.swift
├── Sources/Bridge/WebViewCoordinator.swift
├── Tests/BridgeMessageTests.swift
├── Resources/WebEditor/  (entire directory)
├── web/  (entire directory)
├── package.json
├── package-lock.json
├── vite.config.js
```

---

### Task 1: Delete Web Layer

**Files:**
- Delete: `Sources/Views/EditorWebView.swift`
- Delete: `Sources/Bridge/WebViewCoordinator.swift`
- Delete: `Tests/BridgeMessageTests.swift`
- Delete: `Resources/WebEditor/` (entire directory)
- Delete: `web/` (entire directory)
- Delete: `package.json`
- Delete: `package-lock.json`
- Delete: `vite.config.js`
- Modify: `Package.swift` — remove resource declaration

- [ ] **Step 1: Delete all web-layer files**

```bash
rm -rf Sources/Views/EditorWebView.swift
rm -rf Sources/Bridge/WebViewCoordinator.swift
rm -rf Sources/Bridge/
rm -rf Tests/BridgeMessageTests.swift
rm -rf Resources/WebEditor/
rm -rf web/
rm -f package.json package-lock.json vite.config.js
```

- [ ] **Step 2: Update Package.swift — remove resource reference**

Replace the entire file with:
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MDMgr",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MDMgr",
            path: "Sources"
        ),
        .testTarget(
            name: "MDMgrTests",
            dependencies: ["MDMgr"],
            path: "Tests"
        )
    ]
)
```

- [ ] **Step 3: Update AppState.swift — remove WebKit dependency**

Replace the entire file with:
```swift
import SwiftUI

@Observable
final class AppState {
    var tabs: [Tab] = []
    var activeTabIndex: Int = 0
    var folderURL: URL?
    var fileTree: [FileNode] = []
    var isSearching: Bool = false
    var searchQuery: String = ""
    var showExportSheet: Bool = false

    @ObservationIgnored
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
        } catch {}
    }

    func saveActiveTab() {
        guard let tab = activeTab else { return }
        saveTab(tab)
    }

    func saveTab(_ tab: Tab) {
        do {
            try tab.content.write(to: tab.fileURL, atomically: true, encoding: .utf8)
            tab.isDirty = false
        } catch {}
    }

    func closeTabWithConfirmation(at index: Int) -> Bool {
        guard index >= 0, index < tabs.count else { return false }
        if tabs[index].isDirty { return false }
        closeTab(at: index)
        return true
    }
}
```

- [ ] **Step 4: Stub ContentView to compile without EditorWebView**

Replace ContentView.swift temporarily (will be properly updated in Task 5):
```swift
import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var tabToClose: Int?
    @State private var showUnsavedAlert = false

    var body: some View {
        NavigationSplitView {
            if appState.isSearching {
                SearchPanel(appState: appState)
            } else {
                SidebarView(appState: appState)
            }
        } detail: {
            VStack(spacing: 0) {
                if !appState.tabs.isEmpty {
                    TabBarView(appState: appState, onClose: handleTabClose)
                    Divider()
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

                        // Placeholder — replaced in Task 5
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
        .sheet(isPresented: $appState.showExportSheet) {
            if let tab = appState.activeTab {
                ExportSheet(tab: tab)
            }
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

- [ ] **Step 5: Stub ExportSheet and ExportService to remove WebKit**

Replace `Sources/Services/ExportService.swift`:
```swift
import AppKit

enum ExportFormat: String, CaseIterable {
    case pdf = "PDF"
    case html = "HTML"
}

enum ExportService {
    static func exportPDF(content: NSAttributedString, to url: URL) throws {
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792) // US Letter
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        textView.textStorage?.setAttributedString(content)
        textView.sizeToFit()

        let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false

        let pdfData = printOp.view?.dataWithPDF(inside: printOp.view!.bounds)
        if let data = pdfData {
            try data.write(to: url)
        }
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

Replace `Sources/Views/ExportSheet.swift`:
```swift
import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    let tab: Tab
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
                    let rendered = MarkdownRenderer.render(tab.content)
                    try ExportService.exportPDF(content: rendered, to: url)
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

- [ ] **Step 6: Verify build and tests**

Run:
```bash
swift build
```
Expected: Build succeeds (BridgeMessageTests deleted, all WebKit refs removed)

Run:
```bash
swift test
```
Expected: 18 tests pass (was 21, minus 3 bridge tests)

Note: The build will fail until `MarkdownRenderer` exists. Create a minimal stub:
```swift
// Sources/Services/MarkdownRenderer.swift
import AppKit

enum MarkdownRenderer {
    static func render(_ markdown: String) -> NSAttributedString {
        NSAttributedString(string: markdown)
    }
}
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove WKWebView/HTML/JS layer, stub native replacements"
```

---

### Task 2: MarkdownRenderer — Core Rendering

**Files:**
- Modify: `Sources/Services/MarkdownRenderer.swift` (replace stub)
- Create: `Tests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write failing tests for MarkdownRenderer**

```swift
// Tests/MarkdownRendererTests.swift
import XCTest
import AppKit
@testable import MDMgr

final class MarkdownRendererTests: XCTestCase {

    // Helper: extract plain text from attributed string
    func text(_ as: NSAttributedString) -> String {
        `as`.string
    }

    // Helper: get font at position
    func font(_ as: NSAttributedString, at pos: Int) -> NSFont? {
        `as`.attribute(.font, at: pos, effectiveRange: nil) as? NSFont
    }

    // Helper: get color at position
    func color(_ as: NSAttributedString, at pos: Int) -> NSColor? {
        `as`.attribute(.foregroundColor, at: pos, effectiveRange: nil) as? NSColor
    }

    func testHeading1() {
        let result = MarkdownRenderer.render("# Hello World")
        XCTAssertTrue(text(result).contains("Hello World"))
        let f = font(result, at: 0)
        XCTAssertNotNil(f)
        XCTAssertGreaterThan(f!.pointSize, 20)
    }

    func testHeading2() {
        let result = MarkdownRenderer.render("## Subtitle")
        XCTAssertTrue(text(result).contains("Subtitle"))
        let f = font(result, at: 0)
        XCTAssertNotNil(f)
        XCTAssertGreaterThan(f!.pointSize, 16)
    }

    func testBold() {
        let result = MarkdownRenderer.render("This is **bold** text")
        XCTAssertTrue(text(result).contains("bold"))
        // Find the position of "bold" in the plain text
        let range = (text(result) as NSString).range(of: "bold")
        let f = font(result, at: range.location)
        XCTAssertNotNil(f)
        let traits = NSFontManager.shared.traits(of: f!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    func testItalic() {
        let result = MarkdownRenderer.render("This is *italic* text")
        let range = (text(result) as NSString).range(of: "italic")
        let f = font(result, at: range.location)
        XCTAssertNotNil(f)
        let traits = NSFontManager.shared.traits(of: f!)
        XCTAssertTrue(traits.contains(.italicFontMask))
    }

    func testInlineCode() {
        let result = MarkdownRenderer.render("Use `print()` here")
        let range = (text(result) as NSString).range(of: "print()")
        let f = font(result, at: range.location)
        XCTAssertNotNil(f)
        XCTAssertTrue(f!.isFixedPitch || f!.fontName.contains("Mono") || f!.familyName?.contains("Mono") == true)
    }

    func testCodeBlock() {
        let result = MarkdownRenderer.render("```\nlet x = 1\n```")
        XCTAssertTrue(text(result).contains("let x = 1"))
        let range = (text(result) as NSString).range(of: "let x = 1")
        let f = font(result, at: range.location)
        XCTAssertNotNil(f)
        XCTAssertTrue(f!.isFixedPitch || f!.fontName.contains("Mono") || f!.familyName?.contains("Mono") == true)
    }

    func testLink() {
        let result = MarkdownRenderer.render("Click [here](https://example.com)")
        let range = (text(result) as NSString).range(of: "here")
        let link = result.attribute(.link, at: range.location, effectiveRange: nil)
        XCTAssertNotNil(link)
    }

    func testUnorderedList() {
        let result = MarkdownRenderer.render("- Item one\n- Item two")
        let t = text(result)
        XCTAssertTrue(t.contains("•") || t.contains("Item one"))
    }

    func testBlockquote() {
        let result = MarkdownRenderer.render("> This is quoted")
        XCTAssertTrue(text(result).contains("This is quoted"))
    }

    func testHorizontalRule() {
        let result = MarkdownRenderer.render("Above\n\n---\n\nBelow")
        XCTAssertTrue(text(result).contains("Above"))
        XCTAssertTrue(text(result).contains("Below"))
    }

    func testEmptyInput() {
        let result = MarkdownRenderer.render("")
        XCTAssertEqual(text(result), "")
    }

    func testPlainText() {
        let result = MarkdownRenderer.render("Just plain text")
        XCTAssertTrue(text(result).contains("Just plain text"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
swift test 2>&1 | grep -E "(Test Case|error:|BUILD)"
```
Expected: Failures — MarkdownRenderer.render returns plain unformatted text (stub)

- [ ] **Step 3: Implement MarkdownRenderer**

Replace `Sources/Services/MarkdownRenderer.swift` with:
```swift
import AppKit

enum MarkdownRenderer {
    // MARK: - Fonts

    private static let bodyFont = NSFont.systemFont(ofSize: 15)
    private static let bodyBoldFont = NSFont.boldSystemFont(ofSize: 15)
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private static let h1Font = NSFont.systemFont(ofSize: 28, weight: .bold)
    private static let h2Font = NSFont.systemFont(ofSize: 22, weight: .semibold)
    private static let h3Font = NSFont.systemFont(ofSize: 18, weight: .semibold)
    private static let h4Font = NSFont.systemFont(ofSize: 16, weight: .semibold)
    private static let h5Font = NSFont.systemFont(ofSize: 15, weight: .semibold)
    private static let h6Font = NSFont.systemFont(ofSize: 14, weight: .semibold)

    private static let headingFonts: [NSFont] = [h1Font, h2Font, h3Font, h4Font, h5Font, h6Font]

    // MARK: - Colors

    private static let linkColor = NSColor.linkColor
    private static let codeBackground = NSColor.quaternaryLabelColor
    private static let quoteColor = NSColor.secondaryLabelColor
    private static let hrColor = NSColor.separatorColor

    // MARK: - Paragraph Styles

    private static let bodyParagraph: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacing = 8
        ps.lineSpacing = 4
        return ps
    }()

    private static func listParagraph(indent: CGFloat = 24) -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.headIndent = indent
        ps.firstLineHeadIndent = indent - 16
        ps.paragraphSpacing = 4
        return ps
    }

    private static func quoteParagraph() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.headIndent = 20
        ps.firstLineHeadIndent = 20
        ps.paragraphSpacing = 4
        return ps
    }

    private static func codeParagraph() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.headIndent = 12
        ps.firstLineHeadIndent = 12
        ps.paragraphSpacing = 2
        return ps
    }

    // MARK: - Render

    static func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var i = 0
        var isFirstBlock = true

        while i < lines.count {
            let line = lines[i]

            // Code block (``` ... ```)
            if line.hasPrefix("```") {
                if !isFirstBlock { result.append(newline()) }
                isFirstBlock = false
                i += 1
                var codeLines: [String] = []
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // skip closing ```
                let code = codeLines.joined(separator: "\n")
                result.append(renderCodeBlock(code))
                continue
            }

            // Heading
            if let match = line.firstMatch(of: /^(#{1,6})\s+(.+)$/) {
                if !isFirstBlock { result.append(newline()) }
                isFirstBlock = false
                let level = match.1.count
                let text = String(match.2)
                result.append(renderHeading(text, level: level))
                i += 1
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces).matches(of: /^(---+|\*\*\*+|___+)$/).count > 0 {
                if !isFirstBlock { result.append(newline()) }
                isFirstBlock = false
                result.append(renderHorizontalRule())
                i += 1
                continue
            }

            // Blockquote
            if let match = line.firstMatch(of: /^>\s?(.*)$/) {
                if !isFirstBlock { result.append(newline()) }
                isFirstBlock = false
                let text = String(match.1)
                result.append(renderBlockquote(text))
                i += 1
                continue
            }

            // Table: accumulate rows
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") && line.trimmingCharacters(in: .whitespaces).hasSuffix("|") {
                if !isFirstBlock { result.append(newline()) }
                isFirstBlock = false
                var tableLines: [String] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    if tl.hasPrefix("|") && tl.hasSuffix("|") {
                        tableLines.append(tl)
                        i += 1
                    } else { break }
                }
                result.append(renderTable(tableLines))
                continue
            }

            // Unordered list
            if let match = line.firstMatch(of: /^(\s*)[-*+]\s+(.+)$/) {
                if !isFirstBlock { result.append(newline()) }
                isFirstBlock = false
                let text = String(match.2)
                // Check task list
                if let taskMatch = text.firstMatch(of: /^\[([ x])\]\s+(.+)$/) {
                    let checked = String(taskMatch.1) == "x"
                    let taskText = String(taskMatch.2)
                    result.append(renderTaskItem(taskText, checked: checked))
                } else {
                    result.append(renderBulletItem(text))
                }
                i += 1
                continue
            }

            // Ordered list
            if let match = line.firstMatch(of: /^(\s*)\d+\.\s+(.+)$/) {
                if !isFirstBlock { result.append(newline()) }
                isFirstBlock = false
                let text = String(match.2)
                // Extract the number for display
                let numMatch = line.firstMatch(of: /^(\s*)(\d+)\.\s/)!
                let num = String(numMatch.2)
                result.append(renderOrderedItem(text, number: num))
                i += 1
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            // Paragraph
            if !isFirstBlock { result.append(newline()) }
            isFirstBlock = false
            result.append(renderParagraph(line))
            i += 1
        }

        return result
    }

    // MARK: - Block Renderers

    private static func renderHeading(_ text: String, level: Int) -> NSAttributedString {
        let font = headingFonts[min(level - 1, 5)]
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = level <= 2 ? 16 : 12
        ps.paragraphSpacing = 8
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: ps]
        return applyInlineFormatting(text, baseAttributes: attrs)
    }

    private static func renderParagraph(_ text: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .paragraphStyle: bodyParagraph]
        return applyInlineFormatting(text, baseAttributes: attrs)
    }

    private static func renderCodeBlock(_ code: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: monoFont,
            .backgroundColor: codeBackground,
            .paragraphStyle: codeParagraph()
        ]
        return NSAttributedString(string: code, attributes: attrs)
    }

    private static func renderBlockquote(_ text: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: quoteColor,
            .paragraphStyle: quoteParagraph()
        ]
        let bar = NSAttributedString(string: "┃ ", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.controlAccentColor,
            .paragraphStyle: quoteParagraph()
        ])
        let result = NSMutableAttributedString()
        result.append(bar)
        result.append(applyInlineFormatting(text, baseAttributes: attrs))
        return result
    }

    private static func renderBulletItem(_ text: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .paragraphStyle: listParagraph()]
        let result = NSMutableAttributedString(string: "•  ", attributes: [
            .font: bodyFont, .paragraphStyle: listParagraph()
        ])
        result.append(applyInlineFormatting(text, baseAttributes: attrs))
        return result
    }

    private static func renderOrderedItem(_ text: String, number: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .paragraphStyle: listParagraph()]
        let result = NSMutableAttributedString(string: "\(number).  ", attributes: [
            .font: bodyFont, .paragraphStyle: listParagraph()
        ])
        result.append(applyInlineFormatting(text, baseAttributes: attrs))
        return result
    }

    private static func renderTaskItem(_ text: String, checked: Bool) -> NSAttributedString {
        let checkbox = checked ? "☑ " : "☐ "
        let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .paragraphStyle: listParagraph()]
        let result = NSMutableAttributedString(string: checkbox, attributes: [
            .font: bodyFont, .paragraphStyle: listParagraph()
        ])
        result.append(applyInlineFormatting(text, baseAttributes: attrs))
        return result
    }

    private static func renderHorizontalRule() -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .center
        ps.paragraphSpacingBefore = 12
        ps.paragraphSpacing = 12
        return NSAttributedString(string: "─────────────────────────", attributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: hrColor,
            .paragraphStyle: ps
        ])
    }

    private static func renderTable(_ lines: [String]) -> NSAttributedString {
        // Parse table into rows (skip separator rows)
        var rows: [[String]] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let inner = String(trimmed.dropFirst().dropLast()) // remove leading/trailing |
            if inner.contains(where: { $0 != "-" && $0 != ":" && $0 != "|" && $0 != " " }) {
                let cells = inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                rows.append(cells)
            }
        }
        guard !rows.isEmpty else { return NSAttributedString() }

        // Calculate column widths
        let colCount = rows.map(\.count).max() ?? 0
        var widths = Array(repeating: 0, count: colCount)
        for row in rows {
            for (j, cell) in row.enumerated() where j < colCount {
                widths[j] = max(widths[j], cell.count)
            }
        }

        // Render as monospace aligned text
        let result = NSMutableAttributedString()
        let attrs: [NSAttributedString.Key: Any] = [.font: monoFont, .paragraphStyle: codeParagraph()]
        for (ri, row) in rows.enumerated() {
            var line = ""
            for j in 0..<colCount {
                let cell = j < row.count ? row[j] : ""
                line += cell.padding(toLength: widths[j] + 2, withPad: " ", startingAt: 0)
            }
            if ri > 0 { result.append(NSAttributedString(string: "\n")) }
            let boldAttrs: [NSAttributedString.Key: Any] = ri == 0
                ? [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold), .paragraphStyle: codeParagraph()]
                : attrs
            result.append(NSAttributedString(string: line, attributes: boldAttrs))
        }
        return result
    }

    // MARK: - Inline Formatting

    private static func applyInlineFormatting(_ text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let baseFont = baseAttributes[.font] as? NSFont ?? bodyFont
        let nsText = text as NSString

        // Images: ![alt](url) — show as [alt]
        applyPattern(result, pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#, in: nsText) { match, range in
            let alt = nsText.substring(with: match.range(at: 1))
            result.replaceCharacters(in: range, with: NSAttributedString(string: "[\(alt)]", attributes: baseAttributes))
        }

        // Links: [text](url)
        let linkNsText = result.string as NSString
        applyPatternNonMutating(result, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, in: linkNsText) { match in
            let linkText = linkNsText.substring(with: match.range(at: 1))
            let urlStr = linkNsText.substring(with: match.range(at: 2))
            let replacement = NSMutableAttributedString(string: linkText, attributes: baseAttributes)
            if let url = URL(string: urlStr) {
                replacement.addAttribute(.link, value: url, range: NSRange(location: 0, length: linkText.count))
            }
            replacement.addAttribute(.foregroundColor, value: linkColor, range: NSRange(location: 0, length: linkText.count))
            return replacement
        }

        // Inline code: `code`
        applyInlineReplacements(result, pattern: #"`([^`]+)`"#, transform: { inner in
            var attrs = baseAttributes
            attrs[.font] = monoFont
            attrs[.backgroundColor] = codeBackground
            return NSAttributedString(string: inner, attributes: attrs)
        })

        // Bold+italic: ***text***
        applyInlineReplacements(result, pattern: #"\*\*\*(.+?)\*\*\*"#, transform: { inner in
            var attrs = baseAttributes
            let boldItalic = NSFontManager.shared.convert(NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask), toHaveTrait: .italicFontMask)
            attrs[.font] = boldItalic
            return NSAttributedString(string: inner, attributes: attrs)
        })

        // Bold: **text** or __text__
        applyInlineReplacements(result, pattern: #"\*\*(.+?)\*\*"#, transform: { inner in
            var attrs = baseAttributes
            attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            return NSAttributedString(string: inner, attributes: attrs)
        })
        applyInlineReplacements(result, pattern: #"__(.+?)__"#, transform: { inner in
            var attrs = baseAttributes
            attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            return NSAttributedString(string: inner, attributes: attrs)
        })

        // Italic: *text* or _text_
        applyInlineReplacements(result, pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#, transform: { inner in
            var attrs = baseAttributes
            attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            return NSAttributedString(string: inner, attributes: attrs)
        })
        applyInlineReplacements(result, pattern: #"(?<!_)_([^_]+?)_(?!_)"#, transform: { inner in
            var attrs = baseAttributes
            attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            return NSAttributedString(string: inner, attributes: attrs)
        })

        return result
    }

    // MARK: - Helpers

    private static func newline() -> NSAttributedString {
        NSAttributedString(string: "\n")
    }

    // Replace regex matches with transformed attributed strings (processes in reverse to preserve ranges)
    private static func applyInlineReplacements(
        _ attrStr: NSMutableAttributedString,
        pattern: String,
        transform: (String) -> NSAttributedString
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: attrStr.length)
        let matches = regex.matches(in: attrStr.string, range: fullRange)

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let innerRange = match.range(at: 1)
            let inner = (attrStr.string as NSString).substring(with: innerRange)
            let replacement = transform(inner)
            attrStr.replaceCharacters(in: match.range, with: replacement)
        }
    }

    // For image replacement (mutates text, needs special handling)
    private static func applyPattern(
        _ attrStr: NSMutableAttributedString,
        pattern: String,
        in nsText: NSString,
        handler: (NSTextCheckingResult, NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: nsText as String, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            handler(match, match.range)
        }
    }

    // For link replacement (needs capture group + attributed replacement)
    private static func applyPatternNonMutating(
        _ attrStr: NSMutableAttributedString,
        pattern: String,
        in nsText: NSString,
        handler: (NSTextCheckingResult) -> NSAttributedString
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: nsText as String, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            let replacement = handler(match)
            attrStr.replaceCharacters(in: match.range, with: replacement)
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
swift test 2>&1 | grep -E "(Test Case|Executed|BUILD)"
```
Expected: All MarkdownRendererTests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/MarkdownRenderer.swift Tests/MarkdownRendererTests.swift
git commit -m "feat: add MarkdownRenderer — markdown to styled NSAttributedString"
```

---

### Task 3: MarkdownSyntaxHighlighter

**Files:**
- Create: `Sources/Services/MarkdownSyntaxHighlighter.swift`

- [ ] **Step 1: Implement MarkdownSyntaxHighlighter**

```swift
// Sources/Services/MarkdownSyntaxHighlighter.swift
import AppKit

enum MarkdownSyntaxHighlighter {
    // MARK: - Colors

    private static var headingColor: NSColor { NSColor.systemBlue }
    private static var boldColor: NSColor { NSColor.labelColor }
    private static var italicColor: NSColor { NSColor.systemPurple }
    private static var codeColor: NSColor { NSColor.systemRed }
    private static var codeBackground: NSColor { NSColor.quaternaryLabelColor }
    private static var linkColor: NSColor { NSColor.linkColor }
    private static var listColor: NSColor { NSColor.systemOrange }
    private static var quoteColor: NSColor { NSColor.secondaryLabelColor }
    private static var hrColor: NSColor { NSColor.separatorColor }

    private static let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let editorBoldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

    // MARK: - Highlight

    static func highlight(_ textStorage: NSTextStorage) {
        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Reset to base style
        textStorage.addAttributes([
            .font: editorFont,
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        let nsText = text as NSString
        let lines = text.components(separatedBy: "\n")
        var lineStart = 0
        var inCodeBlock = false

        for line in lines {
            let lineRange = NSRange(location: lineStart, length: line.count)

            // Code block fences
            if line.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                textStorage.addAttribute(.foregroundColor, value: codeColor, range: lineRange)
                textStorage.addAttribute(.font, value: editorBoldFont, range: lineRange)
                lineStart += line.count + 1
                continue
            }

            if inCodeBlock {
                textStorage.addAttribute(.foregroundColor, value: codeColor, range: lineRange)
                textStorage.addAttribute(.backgroundColor, value: codeBackground, range: lineRange)
                lineStart += line.count + 1
                continue
            }

            // Headings
            if let match = try? /^(#{1,6}\s)(.*)/.firstMatch(in: line) {
                textStorage.addAttribute(.foregroundColor, value: headingColor, range: lineRange)
                textStorage.addAttribute(.font, value: editorBoldFont, range: lineRange)
                lineStart += line.count + 1
                continue
            }

            // Horizontal rules
            if line.trimmingCharacters(in: .whitespaces).range(of: #"^(---+|\*\*\*+|___+)$"#, options: .regularExpression) != nil {
                textStorage.addAttribute(.foregroundColor, value: hrColor, range: lineRange)
                lineStart += line.count + 1
                continue
            }

            // Blockquotes
            if line.hasPrefix(">") {
                textStorage.addAttribute(.foregroundColor, value: quoteColor, range: lineRange)
                lineStart += line.count + 1
                continue
            }

            // List markers
            if let match = line.range(of: #"^(\s*[-*+]\s)"#, options: .regularExpression) {
                let nsMatch = NSRange(match, in: line)
                let adjustedRange = NSRange(location: lineStart + nsMatch.location, length: nsMatch.length)
                textStorage.addAttribute(.foregroundColor, value: listColor, range: adjustedRange)
                textStorage.addAttribute(.font, value: editorBoldFont, range: adjustedRange)
            }
            if let match = line.range(of: #"^(\s*\d+\.\s)"#, options: .regularExpression) {
                let nsMatch = NSRange(match, in: line)
                let adjustedRange = NSRange(location: lineStart + nsMatch.location, length: nsMatch.length)
                textStorage.addAttribute(.foregroundColor, value: listColor, range: adjustedRange)
                textStorage.addAttribute(.font, value: editorBoldFont, range: adjustedRange)
            }

            // Inline formatting (within the line)
            applyInlineHighlights(textStorage, lineText: line, lineStart: lineStart)

            lineStart += line.count + 1
        }
    }

    private static func applyInlineHighlights(_ textStorage: NSTextStorage, lineText: String, lineStart: Int) {
        let nsLine = lineText as NSString

        // Inline code: `code`
        applyRegex(textStorage, pattern: #"`([^`]+)`"#, in: nsLine, lineStart: lineStart,
                   attrs: [.foregroundColor: codeColor, .backgroundColor: codeBackground])

        // Bold: **text**
        applyRegex(textStorage, pattern: #"\*\*(.+?)\*\*"#, in: nsLine, lineStart: lineStart,
                   attrs: [.font: editorBoldFont])

        // Italic: *text*
        applyRegex(textStorage, pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#, in: nsLine, lineStart: lineStart,
                   attrs: [.foregroundColor: italicColor, .font: NSFontManager.shared.convert(editorFont, toHaveTrait: .italicFontMask)])

        // Links: [text](url)
        applyRegex(textStorage, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, in: nsLine, lineStart: lineStart,
                   attrs: [.foregroundColor: linkColor])
    }

    private static func applyRegex(
        _ textStorage: NSTextStorage,
        pattern: String,
        in nsLine: NSString,
        lineStart: Int,
        attrs: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: nsLine as String, range: NSRange(location: 0, length: nsLine.length))
        for match in matches {
            let range = NSRange(location: lineStart + match.range.location, length: match.range.length)
            for (key, value) in attrs {
                textStorage.addAttribute(key, value: value, range: range)
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
swift build
```
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/MarkdownSyntaxHighlighter.swift
git commit -m "feat: add MarkdownSyntaxHighlighter — edit mode syntax coloring"
```

---

### Task 4: MarkdownTextView

**Files:**
- Create: `Sources/Views/MarkdownTextView.swift`

- [ ] **Step 1: Implement MarkdownTextView**

```swift
// Sources/Views/MarkdownTextView.swift
import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    let tab: Tab

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 32, height: 24)
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Set up delegate for edit mode changes
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView

        // Apply initial content
        applyContent(to: textView, tab: tab)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator

        // Update tab reference
        coordinator.tab = tab

        // Mode changed
        if coordinator.lastMode != tab.mode {
            coordinator.lastMode = tab.mode
            applyContent(to: textView, tab: tab)
        }

        // Content changed externally (e.g., tab switch)
        if coordinator.lastContent != tab.content {
            coordinator.lastContent = tab.content
            if !coordinator.isLocalEdit {
                applyContent(to: textView, tab: tab)
            }
            coordinator.isLocalEdit = false
        }
    }

    private func applyContent(to textView: NSTextView, tab: Tab) {
        if tab.mode == .read {
            textView.isEditable = false
            textView.isSelectable = true
            let rendered = MarkdownRenderer.render(tab.content)
            textView.textStorage?.setAttributedString(rendered)
        } else {
            textView.isEditable = true
            textView.isSelectable = true
            textView.textStorage?.setAttributedString(
                NSAttributedString(string: tab.content, attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.labelColor
                ])
            )
            if let storage = textView.textStorage {
                MarkdownSyntaxHighlighter.highlight(storage)
            }
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var tab: Tab
        weak var textView: NSTextView?
        var lastMode: TabMode?
        var lastContent: String?
        var isLocalEdit = false
        private var highlightDebounceTimer: Timer?

        init(tab: Tab) {
            self.tab = tab
            self.lastMode = tab.mode
            self.lastContent = tab.content
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newContent = textView.string
            isLocalEdit = true
            tab.content = newContent
            tab.isDirty = true
            lastContent = newContent

            // Debounced syntax highlighting
            highlightDebounceTimer?.invalidate()
            highlightDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak textView] _ in
                guard let textView, let storage = textView.textStorage else { return }
                let selectedRange = textView.selectedRange()
                storage.beginEditing()
                MarkdownSyntaxHighlighter.highlight(storage)
                storage.endEditing()
                textView.setSelectedRange(selectedRange)
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run:
```bash
swift build
```
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/MarkdownTextView.swift
git commit -m "feat: add MarkdownTextView — NSTextView-based markdown view"
```

---

### Task 5: Wire Into ContentView

**Files:**
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Replace ContentView to use MarkdownTextView**

Replace `Sources/Views/ContentView.swift` with:
```swift
import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var tabToClose: Int?
    @State private var showUnsavedAlert = false

    var body: some View {
        NavigationSplitView {
            if appState.isSearching {
                SearchPanel(appState: appState)
            } else {
                SidebarView(appState: appState)
            }
        } detail: {
            VStack(spacing: 0) {
                if !appState.tabs.isEmpty {
                    TabBarView(appState: appState, onClose: handleTabClose)
                    Divider()
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

                        MarkdownTextView(tab: tab)
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
        .sheet(isPresented: $appState.showExportSheet) {
            if let tab = appState.activeTab {
                ExportSheet(tab: tab)
            }
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

- [ ] **Step 2: Verify build and all tests pass**

Run:
```bash
swift build && swift test 2>&1 | grep -E "(Executed|passed|failed)"
```
Expected: Build succeeds, 18+ tests pass

- [ ] **Step 3: Rebuild app bundle and test**

Run:
```bash
bash scripts/build-app.sh
```
Then launch and verify:
1. Open a folder, click a markdown file → rendered with styled text (headings, bold, italic, code)
2. Click Edit → raw markdown with syntax highlighting, editable
3. Type some text → dirty dot appears
4. Cmd+Z → undo works
5. Click Done → back to rendered view with changes

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/ContentView.swift
git commit -m "feat: wire MarkdownTextView into ContentView, complete native editor"
```

---

### Task 6: Update Build Script & Clean Up

**Files:**
- Modify: `scripts/build-app.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Update build-app.sh — remove WebEditor copy**

Replace `scripts/build-app.sh` with:
```bash
#!/bin/bash
# Build MD Mgr.app bundle from swift build output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/build/MD Mgr.app"
CONTENTS_DIR="$APP_DIR/Contents"

echo "Building release..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS"
mkdir -p "$CONTENTS_DIR/Resources"

# Copy binary
cp "$BUILD_DIR/MDMgr" "$CONTENTS_DIR/MacOS/MD Mgr"

# Copy Info.plist and resolve Xcode build variables for SPM
sed \
    -e 's/$(EXECUTABLE_NAME)/MD Mgr/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.mdmgr.app/g' \
    -e 's/$(CURRENT_PROJECT_VERSION)/1/g' \
    -e 's/$(MARKETING_VERSION)/1.0.0/g' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/14.0/g' \
    "$PROJECT_DIR/Sources/App/Info.plist" > "$CONTENTS_DIR/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "Built: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
```

- [ ] **Step 2: Update .gitignore — remove web-related entries that are no longer needed**

The `.gitignore` should be:
```
MDMgr.xcodeproj/
build/
.build/
DerivedData/
.superpowers/
node_modules/
*.xcworkspace
.DS_Store
.swiftpm/
```

- [ ] **Step 3: Run full test suite and build app**

Run:
```bash
swift test 2>&1 | grep -E "(Executed|passed|failed)"
```
Expected: All tests pass

Run:
```bash
bash scripts/build-app.sh
```
Expected: App bundle created successfully

- [ ] **Step 4: Commit**

```bash
git add scripts/build-app.sh .gitignore
git commit -m "chore: clean up build script and gitignore for native editor"
```
