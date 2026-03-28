# Native Editor Rearchitecture

## Overview

Replace the WKWebView + HTML/JS/bridge editor with a fully native NSTextView for both read and edit modes. This eliminates the entire web layer (JS, HTML, CSS, Vite, npm) and fixes all keyboard shortcut issues.

## Architecture

```
SwiftUI Shell (sidebar, tabs, toolbar)
  └── MarkdownTextView (NSViewRepresentable wrapping NSTextView)
        ├── Read mode: non-editable, styled NSAttributedString
        └── Edit mode: editable, syntax-highlighted raw markdown
```

Single `NSTextView` handles both modes by toggling `isEditable` and swapping the attributed string between rendered output and syntax-highlighted source.

## Components

### MarkdownTextView (NSViewRepresentable)

Wraps `NSTextView` in a `NSScrollView`. Manages the text view lifecycle and communicates state changes back to the SwiftUI layer.

- **Read mode:** `isEditable = false`, displays `MarkdownRenderer` output
- **Edit mode:** `isEditable = true`, displays raw markdown with `MarkdownSyntaxHighlighter` coloring
- Reports content changes via a callback (for dirty state tracking)
- Preserves scroll position across mode switches
- Supports double-click to switch from read to edit mode

### MarkdownRenderer

Converts a markdown string to a styled `NSAttributedString` for read mode display.

**Supported elements:**
- Headings (H1-H6): system title fonts, bold, scaled sizes
- Bold/italic: font traits on the system body font
- Inline code: monospace font + light gray background
- Code blocks: monospace font + gray background, indented paragraph style
- Links: blue color + `NSAttributedString.Key.link` (clickable)
- Images: `NSTextAttachment` loading from local file paths (relative to the markdown file's directory)
- Unordered lists: bullet character (•) + indented paragraph style
- Ordered lists: numbered prefix + indented paragraph style
- Task lists: checkbox character (☐/☑) + text
- Blockquotes: indented paragraph style + gray color + left border (via paragraph head indent)
- Horizontal rules: centered thin line (via `NSAttributedString` with a dash pattern or attachment)
- Tables: monospace formatted text with aligned columns

**Parsing approach:** Line-by-line regex parsing (same approach as the working JS renderer, ported to Swift). No external dependencies.

### MarkdownSyntaxHighlighter

Applies syntax coloring to raw markdown text in edit mode. Runs on `NSTextStorage` via `NSTextStorageDelegate` or on text changes.

**Colors (matching the JS version):**
- Headings: blue, bold
- Bold markers and text: bold weight
- Italic markers and text: italic style
- Inline code: red with subtle background
- Code fences and block content: red
- Links: blue
- Link URLs: blue, dimmed
- List markers: orange, bold
- Blockquote markers: gray
- Horizontal rules: gray

Uses `NSAttributedString` attributes: `.foregroundColor`, `.font` (bold/italic traits), `.backgroundColor`.

## Files

**Remove:**
- `Sources/Views/EditorWebView.swift`
- `Sources/Bridge/WebViewCoordinator.swift`
- `Tests/BridgeMessageTests.swift`
- `Resources/WebEditor/` (entire directory)
- `web/` (entire directory)
- `package.json`, `package-lock.json`, `vite.config.js`

**Create:**
- `Sources/Views/MarkdownTextView.swift` — NSViewRepresentable
- `Sources/Services/MarkdownRenderer.swift` — markdown → styled attributed string
- `Sources/Services/MarkdownSyntaxHighlighter.swift` — edit-mode syntax coloring
- `Tests/MarkdownRendererTests.swift` — test rendering output
- `Tests/MarkdownSyntaxHighlighterTests.swift` — test highlighting

**Modify:**
- `Sources/Views/ContentView.swift` — swap EditorWebView for MarkdownTextView, remove coordinator management
- `Sources/Models/AppState.swift` — remove `activeWebView: WKWebView?`, remove `import WebKit`
- `Sources/Services/ExportService.swift` — PDF export via NSTextView print-to-PDF instead of WKWebView
- `Sources/Views/ExportSheet.swift` — remove WKWebView parameter
- `Package.swift` — remove WebEditor resource reference

## What This Fixes

- Cmd+Z/Cmd+Shift+Z: NSTextView has built-in UndoManager
- All standard keyboard shortcuts: native responder chain, no SwiftUI interception
- Spell check, autocomplete, text services: free with NSTextView
- No JS/HTML/CSS bundle, no bridge layer, no file:// security issues
- Simpler architecture, faster startup, smaller binary

## Out of Scope

- Per-language syntax highlighting in code blocks (monospace + background is sufficient)
- WYSIWYG editing (edit mode shows raw markdown with syntax highlighting)
- Rich text toolbar in edit mode (toolbar buttons insert markdown syntax into the raw text, same as current behavior)
