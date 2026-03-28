import AppKit

enum ExportFormat: String, CaseIterable {
    case pdf = "PDF"
    case html = "HTML"
}

enum ExportService {
    static func exportPDF(content: NSAttributedString, to url: URL) throws {
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        textView.textStorage?.setAttributedString(content)
        textView.sizeToFit()

        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try pdfData.write(to: url)
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
