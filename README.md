# Marker

A lightweight, fast, native macOS markdown reader and editor. No Electron, no web views, no bloat — just a clean Mac app built with SwiftUI and AppKit.

Marker opens markdown files rendered by default. Double-click or press Edit to switch to a syntax-highlighted editor with formatting shortcuts. That's it.

## Features

**Reading**
- Styled markdown rendering — headings, bold, italic, code, links, lists, tables, blockquotes, images, footnotes, strikethrough
- Dark mode with adaptive colors
- Four themes — System, Serif, Mono, Compact
- Table of contents sidebar (Cmd+Shift+T)

**Editing**
- Syntax-highlighted raw markdown editor
- Formatting toolbar — bold, italic, headings, lists, code, blockquote, links, horizontal rules
- Toggle formatting — click Bold on bold text to remove it
- Native undo/redo (Cmd+Z / Cmd+Shift+Z)
- Spell check, autocomplete, all standard macOS text shortcuts
- Auto-save every 30 seconds

**Navigation**
- Sidebar file tree with live updates
- Tabs with unsaved change indicators
- Quick open (Cmd+P) — fuzzy file finder
- Find in document (Cmd+F) with match highlighting
- Folder-wide search (Cmd+Shift+F)
- Recent files menu

**System Integration**
- Open `.md` files from Finder (double-click or Open With)
- Drag and drop files onto the app
- Quick Look preview — press spacebar on any `.md` in Finder
- Git status indicators in the sidebar (M/A/?)
- Export to PDF or HTML (Cmd+E)
- Print (Cmd+Shift+P)
- Multiple windows (Cmd+N)
- Minimap (Cmd+Shift+M)

## Install

### Build from source

Requires Xcode 15+ and macOS 14 (Sonoma) or later.

```bash
git clone https://github.com/dtrouton/marker.git
cd marker
bash scripts/build-app.sh --install
```

This builds a release binary, creates `Marker.app`, copies it to `/Applications`, and launches it.

### With Quick Look extension

The Quick Look preview extension requires code signing with an Apple Developer certificate (free account works). Set your team ID in `project.yml`, then:

```bash
bash scripts/build-app.sh --xcode --install
```

### Set as default for `.md` files

Right-click any `.md` file in Finder → Get Info → Open with → Marker → Change All.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+O | Open file |
| Cmd+Shift+O | Open folder |
| Cmd+P | Quick open (fuzzy finder) |
| Cmd+W | Close tab |
| Cmd+S | Save |
| Cmd+F | Find in document |
| Cmd+G | Find next |
| Cmd+Shift+G | Find previous |
| Cmd+Shift+F | Find in folder |
| Cmd+E | Export |
| Cmd+Shift+P | Print |
| Cmd+N | New window |
| Cmd+Return | Toggle edit mode |
| Cmd+Shift+T | Toggle table of contents |
| Cmd+Shift+M | Toggle minimap |
| Cmd+Shift+] | Next tab |
| Cmd+Shift+[ | Previous tab |
| Escape | Exit edit mode |

## Architecture

Marker is built entirely in Swift with zero external dependencies.

- **SwiftUI** — window management, sidebar, tabs, toolbar, dialogs
- **NSTextView** — markdown rendering (read mode) and editing (edit mode) via `NSAttributedString`
- **MarkdownRenderer** — parses markdown and produces styled attributed strings for read mode
- **MarkdownSyntaxHighlighter** — applies syntax coloring to raw markdown in edit mode

No web views, no JavaScript, no HTML, no npm. The app binary is under 5MB.

## License

MIT
