import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView!

    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            let html = renderToHTML(markdown)
            webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
            handler(nil)
        } catch {
            handler(error)
        }
    }

    private func renderToHTML(_ markdown: String) -> String {
        var html = escapeHTML(markdown)

        // Code blocks (fenced)
        html = html.replacingOccurrences(
            of: "```\\w*\\n([\\s\\S]*?)```",
            with: "<pre><code>$1</code></pre>",
            options: .regularExpression
        )

        // Headings
        html = html.replacingOccurrences(of: "(?m)^######\\s+(.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#####\\s+(.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^####\\s+(.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^###\\s+(.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##\\s+(.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#\\s+(.+)$", with: "<h1>$1</h1>", options: .regularExpression)

        // Horizontal rules
        html = html.replacingOccurrences(of: "(?m)^---+$", with: "<hr>", options: .regularExpression)

        // Blockquotes
        html = html.replacingOccurrences(of: "(?m)^&gt;\\s*(.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)

        // Unordered list items
        html = html.replacingOccurrences(of: "(?m)^[-*+]\\s+(.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Tables
        html = html.replacingOccurrences(of: "(?m)^\\|[-\\s:|]+\\|$", with: "", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\|(.+)\\|$", with: { match in
            let row = String(match.dropFirst().dropLast())
            let cells = row.components(separatedBy: "|").map { "<td>\($0.trimmingCharacters(in: .whitespaces))</td>" }
            return "<tr>\(cells.joined())</tr>"
        })

        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)

        // Strikethrough
        html = html.replacingOccurrences(of: "~~(.+?)~~", with: "<del>$1</del>", options: .regularExpression)

        // Inline code
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)

        // Links
        html = html.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        // Paragraphs: double newlines
        html = html.replacingOccurrences(of: "\n\n", with: "</p>\n<p>")
        // Single newlines in non-block context
        html = html.replacingOccurrences(of: "(?<!</p>)\n(?!<)", with: "<br>\n", options: .regularExpression)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
            :root { color-scheme: light dark; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
                font-size: 14px; line-height: 1.6; padding: 24px 32px; max-width: 740px;
            }
            h1 { font-size: 2em; border-bottom: 1px solid rgba(128,128,128,0.2); padding-bottom: 0.3em; }
            h2 { font-size: 1.5em; border-bottom: 1px solid rgba(128,128,128,0.15); padding-bottom: 0.2em; }
            h3 { font-size: 1.2em; }
            code { font-family: 'SF Mono', Menlo, monospace; background: rgba(128,128,128,0.12);
                   padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }
            pre { background: rgba(128,128,128,0.12); padding: 16px; border-radius: 6px; overflow-x: auto; }
            pre code { background: none; padding: 0; }
            blockquote { border-left: 3px solid rgba(128,128,128,0.3); padding-left: 16px;
                         color: rgba(128,128,128,0.8); margin: 1em 0; }
            hr { border: none; border-top: 1px solid rgba(128,128,128,0.25); margin: 2em 0; }
            a { color: #007aff; text-decoration: none; }
            li { margin: 4px 0; }
            table { border-collapse: collapse; margin: 1em 0; }
            th, td { border: 1px solid rgba(128,128,128,0.25); padding: 8px 12px; }
            th { background: rgba(128,128,128,0.08); font-weight: 600; }
            del { opacity: 0.5; }
            img { max-width: 100%; }
        </style>
        </head>
        <body><p>\(html)</p></body>
        </html>
        """
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

// Helper for regex replacement with closure
private extension String {
    func replacingOccurrences(of pattern: String, with handler: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return self }
        let nsString = self as NSString
        var result = self
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
        for match in matches.reversed() {
            let fullMatch = nsString.substring(with: match.range)
            let replacement = handler(fullMatch)
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }
}
