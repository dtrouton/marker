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
            let html = renderToHTML(markdown)

            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true

            let textView = NSTextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor
            textView.textContainerInset = NSSize(width: 20, height: 20)
            textView.textContainer?.widthTracksTextView = true
            textView.isVerticallyResizable = true

            // Use attributed string from HTML
            if let data = html.data(using: .utf8),
               let attrStr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
               ) {
                textView.textStorage?.setAttributedString(attrStr)
            } else {
                textView.string = markdown
            }

            scrollView.documentView = textView
            self.view = scrollView

            handler(nil)
        } catch {
            handler(error)
        }
    }

    private func renderToHTML(_ markdown: String) -> String {
        // Self-contained markdown to HTML conversion (no dependencies on main app)
        var html = markdown

        // Code blocks (fenced)
        html = html.replacingOccurrences(
            of: "```\\w*\\n([\\s\\S]*?)```",
            with: "<pre><code>$1</code></pre>",
            options: .regularExpression
        )

        // Headings (process longest prefix first)
        html = html.replacingOccurrences(of: "(?m)^######\\s+(.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#####\\s+(.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^####\\s+(.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^###\\s+(.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##\\s+(.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#\\s+(.+)$", with: "<h1>$1</h1>", options: .regularExpression)

        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)

        // Inline code
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)

        // Links
        html = html.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        // Horizontal rules
        html = html.replacingOccurrences(of: "(?m)^---+$", with: "<hr>", options: .regularExpression)

        // Unordered list items
        html = html.replacingOccurrences(of: "(?m)^[-*+]\\s+(.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Wrap paragraphs: convert double newlines to paragraph breaks
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")

        // Wrap in styled HTML document
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
                font-size: 14px; line-height: 1.6; padding: 20px; max-width: 700px;
                color: -apple-system-label;
                background: -apple-system-background;
            }
            h1 { font-size: 2em; border-bottom: 1px solid rgba(128,128,128,0.3); padding-bottom: 0.3em; }
            h2 { font-size: 1.5em; border-bottom: 1px solid rgba(128,128,128,0.2); padding-bottom: 0.2em; }
            h3 { font-size: 1.2em; }
            code {
                font-family: 'SF Mono', Menlo, monospace;
                background: rgba(128,128,128,0.1);
                padding: 2px 6px;
                border-radius: 3px;
                font-size: 0.9em;
            }
            pre {
                background: rgba(128,128,128,0.1);
                padding: 12px;
                border-radius: 6px;
                overflow-x: auto;
            }
            pre code { background: none; padding: 0; }
            blockquote {
                border-left: 3px solid rgba(128,128,128,0.3);
                padding-left: 12px;
                color: rgba(128,128,128,0.8);
                margin-left: 0;
            }
            hr { border: none; border-top: 1px solid rgba(128,128,128,0.3); }
            a { color: #007aff; }
            li { margin: 4px 0; }
            table { border-collapse: collapse; }
            th, td { border: 1px solid rgba(128,128,128,0.3); padding: 6px 10px; }
        </style>
        </head>
        <body><p>\(html)</p></body>
        </html>
        """
    }
}
