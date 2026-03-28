import AppKit

enum MarkdownRenderer {

    // MARK: - Public API

    static func render(_ markdown: String, baseURL: URL? = nil) -> NSAttributedString {
        guard !markdown.isEmpty else { return NSAttributedString() }

        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var index = 0
        var isFirstBlock = true

        while index < lines.count {
            let line = lines[index]

            // --- Fenced code block ---
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if !isFirstBlock { result.append(paragraphBreak) }
                isFirstBlock = false
                let lang = String(line.trimmingCharacters(in: .whitespaces).dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count {
                    let cl = lines[index]
                    if cl.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(cl)
                    index += 1
                }
                let codeText = codeLines.joined(separator: "\n")
                result.append(renderCodeBlock(codeText, language: lang.isEmpty ? nil : lang))
                continue
            }

            // --- Empty line → paragraph break ---
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !isFirstBlock { result.append(paragraphBreak) }
                index += 1
                continue
            }

            if !isFirstBlock { result.append(paragraphBreak) }
            isFirstBlock = false

            // --- Heading ---
            if let heading = parseHeading(line) {
                result.append(renderHeading(heading.text, level: heading.level, baseURL: baseURL))
            }
            // --- Horizontal rule ---
            else if isHorizontalRule(line) {
                result.append(renderHorizontalRule())
            }
            // --- Blockquote ---
            else if line.hasPrefix(">") {
                var quoteLines: [String] = []
                var qi = index
                while qi < lines.count && lines[qi].hasPrefix(">") {
                    let stripped = String(lines[qi].dropFirst(lines[qi].hasPrefix("> ") ? 2 : 1))
                    quoteLines.append(stripped)
                    qi += 1
                }
                result.append(renderBlockquote(quoteLines.joined(separator: "\n"), baseURL: baseURL))
                index = qi
                continue
            }
            // --- Task list ---
            else if isTaskListItem(line) {
                let checked = line.contains("- [x]") || line.contains("- [X]")
                let text = extractTaskListText(line)
                result.append(renderTaskListItem(text, checked: checked, baseURL: baseURL))
            }
            // --- Unordered list ---
            else if isUnorderedListItem(line) {
                let text = extractUnorderedListText(line)
                result.append(renderUnorderedListItem(text, baseURL: baseURL))
            }
            // --- Ordered list ---
            else if let olMatch = parseOrderedListItem(line) {
                result.append(renderOrderedListItem(olMatch.text, number: olMatch.number, baseURL: baseURL))
            }
            // --- Table ---
            else if line.contains("|") && index + 1 < lines.count && isTableSeparator(lines[index + 1]) {
                var tableLines: [String] = []
                var ti = index
                while ti < lines.count && lines[ti].contains("|") {
                    tableLines.append(lines[ti])
                    ti += 1
                }
                result.append(renderTable(tableLines))
                index = ti
                continue
            }
            // --- Footnote definition: [^label]: text ---
            else if isFootnoteDefinition(line) {
                let parsed = parseFootnoteDefinition(line)
                result.append(renderFootnoteDefinition(label: parsed.label, text: parsed.text, baseURL: baseURL))
            }
            // --- Plain paragraph ---
            else {
                result.append(renderInline(line, baseFont: bodyFont, baseURL: baseURL))
            }

            index += 1
        }

        return result
    }

    // MARK: - Fonts & Constants

    private static let bodyFont = NSFont.systemFont(ofSize: 14)
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    private static var paragraphBreak: NSAttributedString {
        NSAttributedString(string: "\n")
    }

    private static func headingFont(level: Int) -> NSFont {
        let sizes: [CGFloat] = [28, 22, 18, 16, 15, 14]
        let size = sizes[min(level - 1, sizes.count - 1)]
        let weight: NSFont.Weight = level <= 2 ? .bold : .semibold
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    // MARK: - Image Loading

    private static func loadImage(src: String, baseURL: URL?) -> NSImage? {
        // Try as absolute file path
        if src.hasPrefix("/") {
            let fileURL = URL(fileURLWithPath: src)
            if let image = NSImage(contentsOf: fileURL) {
                return image
            }
        }
        // Try as absolute URL (e.g. https:// or file://)
        if let url = URL(string: src), url.scheme != nil, let image = NSImage(contentsOf: url) {
            return image
        }
        // Try as relative path from baseURL
        if let base = baseURL {
            let resolved = base.appendingPathComponent(src)
            if let image = NSImage(contentsOf: resolved) {
                return image
            }
        }
        return nil
    }

    // MARK: - Block Renderers

    private static func renderHeading(_ text: String, level: Int, baseURL: URL? = nil) -> NSAttributedString {
        let font = headingFont(level: level)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = 8
        para.paragraphSpacing = 4
        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ]
        let result = NSMutableAttributedString(string: text, attributes: base)
        applyInlineFormatting(result, baseFont: font, baseURL: baseURL)
        return result
    }

    private static func renderCodeBlock(_ code: String, language: String? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Language label
        if let language = language {
            let labelPara = NSMutableParagraphStyle()
            labelPara.headIndent = 12
            labelPara.firstLineHeadIndent = 12
            labelPara.paragraphSpacingBefore = 10
            labelPara.paragraphSpacing = 2
            let labelFont = NSFont.systemFont(ofSize: 10, weight: .medium)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: labelPara,
            ]
            result.append(NSAttributedString(string: language.uppercased() + "\n", attributes: labelAttrs))
        }

        let codePara = NSMutableParagraphStyle()
        codePara.headIndent = 12
        codePara.firstLineHeadIndent = 12
        codePara.tailIndent = -12
        // Extra spacing only when there is no language label above
        codePara.paragraphSpacingBefore = language == nil ? 10 : 0
        codePara.paragraphSpacing = 10

        let bgColor: NSColor
        if let blended = NSColor.textBackgroundColor.blended(withFraction: 0.1, of: .gray) {
            bgColor = blended
        } else {
            bgColor = NSColor.controlBackgroundColor
        }

        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: monoFont,
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: bgColor,
            .paragraphStyle: codePara,
        ]
        result.append(NSAttributedString(string: code, attributes: codeAttrs))
        return result
    }

    private static func renderBlockquote(_ text: String, baseURL: URL? = nil) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.headIndent = 24
        para.firstLineHeadIndent = 12
        para.paragraphSpacingBefore = 4
        para.paragraphSpacing = 4
        let result = NSMutableAttributedString()
        let bar = NSAttributedString(string: "┃ ", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para,
        ])
        result.append(bar)
        let body = NSMutableAttributedString(string: text, attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para,
        ])
        applyInlineFormatting(body, baseFont: bodyFont, baseURL: baseURL)
        result.append(body)
        return result
    }

    private static func renderUnorderedListItem(_ text: String, baseURL: URL? = nil) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.headIndent = 20
        para.firstLineHeadIndent = 4
        let bullet = NSAttributedString(string: "• ", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ])
        let body = NSMutableAttributedString(string: text, attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ])
        applyInlineFormatting(body, baseFont: bodyFont, baseURL: baseURL)
        let result = NSMutableAttributedString()
        result.append(bullet)
        result.append(body)
        return result
    }

    private static func renderOrderedListItem(_ text: String, number: Int, baseURL: URL? = nil) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.headIndent = 24
        para.firstLineHeadIndent = 4
        let prefix = NSAttributedString(string: "\(number). ", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ])
        let body = NSMutableAttributedString(string: text, attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ])
        applyInlineFormatting(body, baseFont: bodyFont, baseURL: baseURL)
        let result = NSMutableAttributedString()
        result.append(prefix)
        result.append(body)
        return result
    }

    private static func renderTaskListItem(_ text: String, checked: Bool, baseURL: URL? = nil) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.headIndent = 24
        para.firstLineHeadIndent = 4
        let checkbox = checked ? "☑ " : "☐ "
        let prefix = NSAttributedString(string: checkbox, attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ])
        let body = NSMutableAttributedString(string: text, attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ])
        applyInlineFormatting(body, baseFont: bodyFont, baseURL: baseURL)
        let result = NSMutableAttributedString()
        result.append(prefix)
        result.append(body)
        return result
    }

    private static func renderHorizontalRule() -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.paragraphSpacingBefore = 8
        para.paragraphSpacing = 8
        let rule = String(repeating: "─", count: 40)
        return NSAttributedString(string: rule, attributes: [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.separatorColor,
            .paragraphStyle: para,
        ])
    }

    private static func renderFootnoteDefinition(label: String, text: String, baseURL: URL? = nil) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.headIndent = 24
        para.firstLineHeadIndent = 8
        para.paragraphSpacingBefore = 2
        para.paragraphSpacing = 2

        let smallFont = NSFont.systemFont(ofSize: bodyFont.pointSize * 0.85)
        let labelFont = NSFont.systemFont(ofSize: bodyFont.pointSize * 0.75)

        let result = NSMutableAttributedString()

        // Superscript label
        let labelStr = NSAttributedString(string: label, attributes: [
            .font: labelFont,
            .foregroundColor: NSColor.linkColor,
            .superscript: 1,
            .paragraphStyle: para,
        ])
        result.append(labelStr)

        // Separator
        result.append(NSAttributedString(string: " ", attributes: [.font: smallFont, .paragraphStyle: para]))

        // Body text
        let body = NSMutableAttributedString(string: text, attributes: [
            .font: smallFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para,
        ])
        applyInlineFormatting(body, baseFont: smallFont, baseURL: baseURL)
        result.append(body)
        return result
    }

    private static func renderTable(_ lines: [String]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 2

        func parseCells(_ line: String) -> [String] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let stripped = trimmed.hasPrefix("|") ? String(trimmed.dropFirst()) : trimmed
            let stripped2 = stripped.hasSuffix("|") ? String(stripped.dropLast()) : stripped
            return stripped2.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        // Parse all data rows (skip separators)
        var rows: [[String]] = []
        for line in lines {
            if isTableSeparator(line) { continue }
            rows.append(parseCells(line))
        }
        guard !rows.isEmpty else { return result }

        // Calculate column widths
        let colCount = rows.map(\.count).max() ?? 0
        var widths = Array(repeating: 0, count: colCount)
        for row in rows {
            for (j, cell) in row.enumerated() where j < colCount {
                widths[j] = max(widths[j], cell.count)
            }
        }

        // Render rows with padded columns
        for (i, row) in rows.enumerated() {
            let isHeader = (i == 0)
            let font = isHeader
                ? NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
                : monoFont

            var paddedCells: [String] = []
            for j in 0..<colCount {
                let cell = j < row.count ? row[j] : ""
                paddedCells.append(cell.padding(toLength: widths[j], withPad: " ", startingAt: 0))
            }
            let rowText = paddedCells.joined(separator: "  │  ")
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: para,
            ]
            if !result.string.isEmpty { result.append(NSAttributedString(string: "\n")) }
            result.append(NSAttributedString(string: rowText, attributes: attrs))

            // Add separator line after header
            if isHeader {
                let sepParts = widths.map { String(repeating: "─", count: $0) }
                let sepText = sepParts.joined(separator: "──┼──")
                let sepAttrs: [NSAttributedString.Key: Any] = [
                    .font: monoFont,
                    .foregroundColor: NSColor.separatorColor,
                    .paragraphStyle: para,
                ]
                result.append(NSAttributedString(string: "\n"))
                result.append(NSAttributedString(string: sepText, attributes: sepAttrs))
            }
        }
        return result
    }

    // MARK: - Inline Rendering

    private static func renderInline(_ text: String, baseFont: NSFont, baseURL: URL? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ])
        applyInlineFormatting(result, baseFont: baseFont, baseURL: baseURL)
        return result
    }

    /// Apply inline formatting patterns to a mutable attributed string.
    /// Order: images, inline code (protect from inner matching), links, bold+italic, bold, italic.
    private static func applyInlineFormatting(_ attrStr: NSMutableAttributedString, baseFont: NSFont, baseURL: URL? = nil) {
        // 1. Images: ![alt](path) → inline image or [alt] fallback
        applyPattern(attrStr, pattern: #"!\[([^\]]*)\]\(([^\)]+)\)"#) { match, str in
            let alt = (str.string as NSString).substring(with: match.range(at: 1))
            let src = (str.string as NSString).substring(with: match.range(at: 2))

            // Try to load the image
            if let image = loadImage(src: src, baseURL: baseURL) {
                let attachment = NSTextAttachment()
                // Scale image to fit within max width
                let maxWidth: CGFloat = 600
                if image.size.width > maxWidth {
                    let scale = maxWidth / image.size.width
                    let newSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
                    attachment.bounds = CGRect(origin: .zero, size: newSize)
                }
                attachment.image = image
                return NSAttributedString(attachment: attachment)
            }

            // Fallback to [alt] text
            return NSAttributedString(string: "[\(alt)]", attributes: [
                .font: baseFont,
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        }

        // 2. Inline code: `code`
        applyPattern(attrStr, pattern: #"`([^`]+)`"#) { match, str in
            let code = (str.string as NSString).substring(with: match.range(at: 1))
            let mono = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
            return NSAttributedString(string: code, attributes: [
                .font: mono,
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.quaternaryLabelColor,
            ])
        }

        // 3. Links: [text](url)
        applyPattern(attrStr, pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#) { match, str in
            let linkText = (str.string as NSString).substring(with: match.range(at: 1))
            let urlString = (str.string as NSString).substring(with: match.range(at: 2))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NSColor.linkColor,
                .link: URL(string: urlString) as Any,
            ]
            let result = NSMutableAttributedString(string: linkText, attributes: attrs)
            return result
        }

        // 4. Strikethrough: ~~text~~
        applyPattern(attrStr, pattern: #"~~(.+?)~~"#) { match, str in
            let inner = (str.string as NSString).substring(with: match.range(at: 1))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: NSColor.labelColor,
            ]
            return NSAttributedString(string: inner, attributes: attrs)
        }

        // 5. Footnote references: [^1], [^note], etc. → superscript number/label
        applyPattern(attrStr, pattern: #"\[\^([^\]]+)\](?!:)"#) { match, str in
            let label = (str.string as NSString).substring(with: match.range(at: 1))
            let smallFont = NSFont.systemFont(ofSize: baseFont.pointSize * 0.75)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: smallFont,
                .foregroundColor: NSColor.linkColor,
                .superscript: 1,
            ]
            return NSAttributedString(string: label, attributes: attrs)
        }

        // 6. Bold+Italic: ***text*** or ___text___
        applyPattern(attrStr, pattern: #"\*\*\*(.+?)\*\*\*"#) { match, str in
            let inner = (str.string as NSString).substring(with: match.range(at: 1))
            var font = baseFont
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            return NSAttributedString(string: inner, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        applyPattern(attrStr, pattern: #"___(.+?)___"#) { match, str in
            let inner = (str.string as NSString).substring(with: match.range(at: 1))
            var font = baseFont
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            return NSAttributedString(string: inner, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }

        // 7. Bold: **text** or __text__
        applyPattern(attrStr, pattern: #"\*\*(.+?)\*\*"#) { match, str in
            let inner = (str.string as NSString).substring(with: match.range(at: 1))
            let font = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            return NSAttributedString(string: inner, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        applyPattern(attrStr, pattern: #"__(.+?)__"#) { match, str in
            let inner = (str.string as NSString).substring(with: match.range(at: 1))
            let font = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            return NSAttributedString(string: inner, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }

        // 8. Italic: *text* or _text_ — must NOT match inside ** or __
        applyPattern(attrStr, pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#) { match, str in
            let inner = (str.string as NSString).substring(with: match.range(at: 1))
            let font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            return NSAttributedString(string: inner, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        applyPattern(attrStr, pattern: #"(?<!_)_([^_]+?)_(?!_)"#) { match, str in
            let inner = (str.string as NSString).substring(with: match.range(at: 1))
            let font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            return NSAttributedString(string: inner, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
    }

    /// Find all matches of `pattern` in `attrStr`, call `replacer` for each, and replace
    /// in REVERSE order so that indices remain valid.
    private static func applyPattern(
        _ attrStr: NSMutableAttributedString,
        pattern: String,
        replacer: (NSTextCheckingResult, NSAttributedString) -> NSAttributedString
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let fullRange = NSRange(location: 0, length: attrStr.length)
        let matches = regex.matches(in: attrStr.string, options: [], range: fullRange)
        // Process in reverse to preserve indices
        for match in matches.reversed() {
            let replacement = replacer(match, attrStr)
            attrStr.replaceCharacters(in: match.range, with: replacement)
        }
    }

    // MARK: - Line Parsers

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        for ch in trimmed {
            if ch == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        guard trimmed.count > level else { return (level, "") }
        let afterHashes = trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)...]
        guard afterHashes.first == " " else { return nil }
        let text = String(afterHashes.dropFirst()).trimmingCharacters(in: .whitespaces)
        return (level, text)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let dashes = trimmed.filter { $0 == "-" }
        let stars = trimmed.filter { $0 == "*" }
        let underscores = trimmed.filter { $0 == "_" }
        let clean = trimmed.replacingOccurrences(of: " ", with: "")
        if clean.count >= 3 && dashes.count == clean.count { return true }
        if clean.count >= 3 && stars.count == clean.count { return true }
        if clean.count >= 3 && underscores.count == clean.count { return true }
        return false
    }

    private static func isUnorderedListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")
    }

    private static func extractUnorderedListText(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return String(trimmed.dropFirst(2))
    }

    private static func isTaskListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
    }

    private static func extractTaskListText(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return String(trimmed.dropFirst(6))
    }

    private static func parseOrderedListItem(_ line: String) -> (number: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let numStr = String(trimmed[trimmed.startIndex..<dotIndex])
        guard let num = Int(numStr) else { return nil }
        let afterDot = trimmed[trimmed.index(after: dotIndex)...]
        guard afterDot.first == " " else { return nil }
        return (num, String(afterDot.dropFirst()))
    }

    private static func isFootnoteDefinition(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.range(of: #"^\[\^[^\]]+\]:"#, options: .regularExpression) != nil
    }

    private static func parseFootnoteDefinition(_ line: String) -> (label: String, text: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let regex = try? NSRegularExpression(pattern: #"^\[\^([^\]]+)\]:\s*(.*)"#),
              let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length))
        else {
            return ("", trimmed)
        }
        let label = (trimmed as NSString).substring(with: match.range(at: 1))
        let text = (trimmed as NSString).substring(with: match.range(at: 2))
        return (label, text)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Table separator lines contain |, -, and optionally :
        let allowed = Set<Character>(["|", "-", ":", " "])
        return trimmed.contains("-") && trimmed.contains("|")
            && trimmed.allSatisfy { allowed.contains($0) }
    }
}
