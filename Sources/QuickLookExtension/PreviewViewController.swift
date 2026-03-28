import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        self.view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            let styled = renderMarkdown(markdown)

            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.drawsBackground = true

            let textView = NSTextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor
            textView.textContainerInset = NSSize(width: 24, height: 20)
            textView.textContainer?.widthTracksTextView = true
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

            textView.textStorage?.setAttributedString(styled)

            scrollView.documentView = textView
            self.view = scrollView

            handler(nil)
        } catch {
            handler(error)
        }
    }

    // MARK: - Self-contained Markdown Renderer

    private let bodyFont = NSFont.systemFont(ofSize: 14)
    private let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let codeBg = NSColor.quaternaryLabelColor

    private func headingFont(_ level: Int) -> NSFont {
        let sizes: [CGFloat] = [26, 20, 17, 15, 14, 13]
        let size = sizes[min(level - 1, 5)]
        return .systemFont(ofSize: size, weight: level <= 2 ? .bold : .semibold)
    }

    private func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var i = 0
        var first = true

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if !first { result.append(nl()) }
                first = false
                i += 1
                var code: [String] = []
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }
                let para = NSMutableParagraphStyle()
                para.headIndent = 8; para.firstLineHeadIndent = 8; para.paragraphSpacing = 8
                result.append(NSAttributedString(string: code.joined(separator: "\n"), attributes: [
                    .font: monoFont, .foregroundColor: NSColor.labelColor,
                    .backgroundColor: codeBg, .paragraphStyle: para
                ]))
                continue
            }

            // Heading
            if let m = line.range(of: #"^(#{1,6})\s+(.+)$"#, options: .regularExpression) {
                if !first { result.append(nl()) }
                first = false
                let hashes = line.prefix(while: { $0 == "#" })
                let text = String(line.dropFirst(hashes.count).drop(while: { $0 == " " }))
                let font = headingFont(hashes.count)
                let para = NSMutableParagraphStyle()
                para.paragraphSpacingBefore = 8; para.paragraphSpacing = 4
                let s = NSMutableAttributedString(string: text, attributes: [
                    .font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: para
                ])
                applyInline(s, font: font)
                result.append(s)
                i += 1; continue
            }

            // HR
            if line.trimmingCharacters(in: .whitespaces).range(of: #"^(---+|\*\*\*+|___+)$"#, options: .regularExpression) != nil {
                if !first { result.append(nl()) }
                first = false
                let para = NSMutableParagraphStyle()
                para.alignment = .center; para.paragraphSpacing = 8
                result.append(NSAttributedString(string: String(repeating: "─", count: 30), attributes: [
                    .font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.separatorColor, .paragraphStyle: para
                ]))
                i += 1; continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                if !first { result.append(nl()) }
                first = false
                let text = String(line.dropFirst().drop(while: { $0 == " " }))
                let para = NSMutableParagraphStyle()
                para.headIndent = 20; para.firstLineHeadIndent = 8; para.paragraphSpacing = 4
                let s = NSMutableAttributedString(string: "┃ " + text, attributes: [
                    .font: bodyFont, .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: para
                ])
                result.append(s)
                i += 1; continue
            }

            // List item
            if let m = line.range(of: #"^[-*+]\s+(.+)$"#, options: .regularExpression) {
                if !first { result.append(nl()) }
                first = false
                let text = String(line[line.index(line.startIndex, offsetBy: 2)...])
                let para = NSMutableParagraphStyle()
                para.headIndent = 20; para.firstLineHeadIndent = 4; para.paragraphSpacing = 2
                let s = NSMutableAttributedString(string: "•  " + text, attributes: [
                    .font: bodyFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: para
                ])
                applyInline(s, font: bodyFont)
                result.append(s)
                i += 1; continue
            }

            // Empty
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !first { result.append(nl()) }
                i += 1; continue
            }

            // Paragraph
            if !first { result.append(nl()) }
            first = false
            let para = NSMutableParagraphStyle()
            para.paragraphSpacing = 6; para.lineSpacing = 3
            let s = NSMutableAttributedString(string: line, attributes: [
                .font: bodyFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: para
            ])
            applyInline(s, font: bodyFont)
            result.append(s)
            i += 1
        }

        return result
    }

    // MARK: - Inline formatting

    private func applyInline(_ s: NSMutableAttributedString, font: NSFont) {
        // Inline code
        replace(s, pattern: #"`([^`]+)`"#) { inner in
            NSAttributedString(string: inner, attributes: [
                .font: self.monoFont, .foregroundColor: NSColor.labelColor, .backgroundColor: self.codeBg
            ])
        }
        // Bold
        replace(s, pattern: #"\*\*(.+?)\*\*"#) { inner in
            NSAttributedString(string: inner, attributes: [
                .font: NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask),
                .foregroundColor: NSColor.labelColor
            ])
        }
        // Italic
        replace(s, pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#) { inner in
            NSAttributedString(string: inner, attributes: [
                .font: NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask),
                .foregroundColor: NSColor.labelColor
            ])
        }
        // Links
        replace(s, pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#) { _ in
            // Extract just the link text from the full match
            return nil // handled below
        }
        // Links (custom handling)
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#) {
            let matches = regex.matches(in: s.string, range: NSRange(location: 0, length: s.length))
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let text = (s.string as NSString).substring(with: match.range(at: 1))
                let url = (s.string as NSString).substring(with: match.range(at: 2))
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: NSColor.linkColor
                ]
                if let u = URL(string: url) { attrs[.link] = u }
                s.replaceCharacters(in: match.range, with: NSAttributedString(string: text, attributes: attrs))
            }
        }
    }

    private func replace(_ s: NSMutableAttributedString, pattern: String, handler: (String) -> NSAttributedString?) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: s.string, range: NSRange(location: 0, length: s.length))
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let inner = (s.string as NSString).substring(with: match.range(at: 1))
            if let replacement = handler(inner) {
                s.replaceCharacters(in: match.range, with: replacement)
            }
        }
    }

    private func nl() -> NSAttributedString {
        NSAttributedString(string: "\n")
    }
}
