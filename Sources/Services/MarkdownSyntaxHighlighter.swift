import AppKit

enum MarkdownSyntaxHighlighter {
    private static var headingColor: NSColor { .systemBlue }
    private static var boldColor: NSColor { .labelColor }
    private static var italicColor: NSColor { .systemPurple }
    private static var codeColor: NSColor { .systemRed }
    private static var codeBackground: NSColor { .quaternaryLabelColor }
    private static var linkColor: NSColor { .linkColor }
    private static var listColor: NSColor { .systemOrange }
    private static var quoteColor: NSColor { .secondaryLabelColor }
    private static var hrColor: NSColor { .separatorColor }

    private static let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let editorBoldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

    static func highlight(_ textStorage: NSTextStorage) {
        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Reset to base style
        textStorage.addAttributes([
            .font: editorFont,
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        let lines = text.components(separatedBy: "\n")
        var lineStart = 0
        var inCodeBlock = false

        for line in lines {
            let lineRange = NSRange(location: lineStart, length: line.count)
            guard lineRange.location + lineRange.length <= textStorage.length else {
                lineStart += line.count + 1
                continue
            }

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
            if line.range(of: #"^#{1,6}\s"#, options: .regularExpression) != nil {
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

            // List markers (unordered)
            if let match = line.range(of: #"^(\s*[-*+]\s)"#, options: .regularExpression) {
                let nsMatch = NSRange(match, in: line)
                let adjusted = NSRange(location: lineStart + nsMatch.location, length: nsMatch.length)
                textStorage.addAttribute(.foregroundColor, value: listColor, range: adjusted)
                textStorage.addAttribute(.font, value: editorBoldFont, range: adjusted)
            }

            // List markers (ordered)
            if let match = line.range(of: #"^(\s*\d+\.\s)"#, options: .regularExpression) {
                let nsMatch = NSRange(match, in: line)
                let adjusted = NSRange(location: lineStart + nsMatch.location, length: nsMatch.length)
                textStorage.addAttribute(.foregroundColor, value: listColor, range: adjusted)
                textStorage.addAttribute(.font, value: editorBoldFont, range: adjusted)
            }

            // Inline: code, bold, italic, links
            applyInlineHighlights(textStorage, lineText: line, lineStart: lineStart)

            lineStart += line.count + 1
        }
    }

    private static func applyInlineHighlights(_ textStorage: NSTextStorage, lineText: String, lineStart: Int) {
        let nsLine = lineText as NSString

        // Inline code
        applyRegex(textStorage, pattern: #"`([^`]+)`"#, in: nsLine, lineStart: lineStart,
                   attrs: [.foregroundColor: codeColor, .backgroundColor: codeBackground])

        // Bold
        applyRegex(textStorage, pattern: #"\*\*(.+?)\*\*"#, in: nsLine, lineStart: lineStart,
                   attrs: [.font: editorBoldFont])

        // Italic
        applyRegex(textStorage, pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#, in: nsLine, lineStart: lineStart,
                   attrs: [.foregroundColor: italicColor,
                           .font: NSFontManager.shared.convert(editorFont, toHaveTrait: .italicFontMask)])

        // Links
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
            guard range.location + range.length <= textStorage.length else { continue }
            for (key, value) in attrs {
                textStorage.addAttribute(key, value: value, range: range)
            }
        }
    }
}
