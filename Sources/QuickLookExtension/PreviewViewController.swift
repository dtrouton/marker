import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        guard let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            handler(nil)
            return
        }

        let scrollView = NSScrollView(frame: self.view.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 20, height: 16)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let styled = Self.renderMarkdown(markdown)
        textView.textStorage?.setAttributedString(styled)

        scrollView.documentView = textView
        self.view.addSubview(scrollView)

        handler(nil)
    }

    // MARK: - Renderer (all static to avoid capturing self)

    private static let bodyFont = NSFont.systemFont(ofSize: 14)
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let codeBg = NSColor.quaternaryLabelColor

    private static func headingFont(_ level: Int) -> NSFont {
        let sizes: [CGFloat] = [26, 20, 17, 15, 14, 13]
        return .systemFont(ofSize: sizes[min(level - 1, 5)], weight: level <= 2 ? .bold : .semibold)
    }

    static func renderMarkdown(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        var i = 0

        func addNewline() {
            if result.length > 0 { result.append(NSAttributedString(string: "\n")) }
        }

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                addNewline()
                i += 1
                var code: [String] = []
                while i < lines.count && !lines[i].hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }
                result.append(NSAttributedString(string: code.joined(separator: "\n"), attributes: [
                    .font: monoFont, .foregroundColor: NSColor.labelColor, .backgroundColor: codeBg
                ]))
                continue
            }

            // Heading
            if line.hasPrefix("#") {
                let hashes = line.prefix(while: { $0 == "#" })
                let level = hashes.count
                if level >= 1 && level <= 6 && line.count > level {
                    let idx = line.index(line.startIndex, offsetBy: level)
                    if line[idx] == " " {
                        addNewline()
                        let text = String(line[line.index(after: idx)...])
                        let s = NSMutableAttributedString(string: text, attributes: [
                            .font: headingFont(level), .foregroundColor: NSColor.labelColor
                        ])
                        applyInline(s)
                        result.append(s)
                        i += 1; continue
                    }
                }
            }

            // HR
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 3 && (trimmed.allSatisfy({ $0 == "-" }) || trimmed.allSatisfy({ $0 == "*" }) || trimmed.allSatisfy({ $0 == "_" })) {
                addNewline()
                result.append(NSAttributedString(string: "────────────────────", attributes: [
                    .foregroundColor: NSColor.separatorColor, .font: NSFont.systemFont(ofSize: 8)
                ]))
                i += 1; continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                addNewline()
                let content = String(line.dropFirst().drop(while: { $0 == " " }))
                result.append(NSAttributedString(string: "┃ " + content, attributes: [
                    .font: bodyFont, .foregroundColor: NSColor.secondaryLabelColor
                ]))
                i += 1; continue
            }

            // Unordered list
            if line.count >= 2 && (line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")) {
                addNewline()
                let content = String(line.dropFirst(2))
                let s = NSMutableAttributedString(string: "•  " + content, attributes: [
                    .font: bodyFont, .foregroundColor: NSColor.labelColor
                ])
                applyInline(s)
                result.append(s)
                i += 1; continue
            }

            // Ordered list
            if let dotIdx = line.firstIndex(of: "."), dotIdx > line.startIndex,
               line[line.startIndex..<dotIdx].allSatisfy({ $0.isNumber }),
               line.index(after: dotIdx) < line.endIndex && line[line.index(after: dotIdx)] == " " {
                addNewline()
                let num = String(line[line.startIndex..<dotIdx])
                let content = String(line[line.index(dotIdx, offsetBy: 2)...])
                let s = NSMutableAttributedString(string: "\(num).  " + content, attributes: [
                    .font: bodyFont, .foregroundColor: NSColor.labelColor
                ])
                applyInline(s)
                result.append(s)
                i += 1; continue
            }

            // Empty line
            if trimmed.isEmpty {
                addNewline()
                i += 1; continue
            }

            // Paragraph
            addNewline()
            let s = NSMutableAttributedString(string: line, attributes: [
                .font: bodyFont, .foregroundColor: NSColor.labelColor
            ])
            applyInline(s)
            result.append(s)
            i += 1
        }
        return result
    }

    private static func applyInline(_ s: NSMutableAttributedString) {
        // Inline code
        applyReplace(s, pattern: "`([^`]+)`") { inner in
            NSAttributedString(string: inner, attributes: [
                .font: monoFont, .foregroundColor: NSColor.labelColor, .backgroundColor: codeBg
            ])
        }
        // Bold
        applyReplace(s, pattern: "\\*\\*(.+?)\\*\\*") { inner in
            NSAttributedString(string: inner, attributes: [
                .font: NSFontManager.shared.convert(bodyFont, toHaveTrait: .boldFontMask),
                .foregroundColor: NSColor.labelColor
            ])
        }
        // Italic (negative lookahead/behind avoid matching inside **)
        applyReplace(s, pattern: "(?<!\\*)\\*([^*]+?)\\*(?!\\*)") { inner in
            NSAttributedString(string: inner, attributes: [
                .font: NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask),
                .foregroundColor: NSColor.labelColor
            ])
        }
        // Links
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)") {
            let matches = regex.matches(in: s.string, range: NSRange(location: 0, length: s.length))
            for match in matches.reversed() where match.numberOfRanges >= 3 {
                let text = (s.string as NSString).substring(with: match.range(at: 1))
                let url = (s.string as NSString).substring(with: match.range(at: 2))
                var attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor.linkColor]
                if let u = URL(string: url) { attrs[.link] = u }
                s.replaceCharacters(in: match.range, with: NSAttributedString(string: text, attributes: attrs))
            }
        }
    }

    private static func applyReplace(_ s: NSMutableAttributedString, pattern: String, handler: (String) -> NSAttributedString) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: s.string, range: NSRange(location: 0, length: s.length))
        for match in matches.reversed() where match.numberOfRanges >= 2 {
            let inner = (s.string as NSString).substring(with: match.range(at: 1))
            s.replaceCharacters(in: match.range, with: handler(inner))
        }
    }
}
