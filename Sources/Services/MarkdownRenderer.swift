import AppKit

enum MarkdownRenderer {
    static func render(_ markdown: String) -> NSAttributedString {
        NSAttributedString(string: markdown)
    }
}
