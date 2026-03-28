import SwiftUI
import WebKit

struct EditorWebView: NSViewRepresentable {
    let tab: Tab
    let coordinator: WebViewCoordinator
    var onWebViewCreated: ((WKWebView) -> Void)?

    /// Locate the WebEditor bundle directory at runtime.
    /// SPM executable targets may not generate Bundle.module, so we search
    /// multiple locations: the main bundle, next to the executable, and
    /// the original Resources/ directory for development runs.
    static func findWebEditorBundle() -> URL? {
        // 1. Bundle.main resources (works when run as .app)
        if let url = Bundle.main.url(forResource: "WebEditor", withExtension: nil) {
            return url
        }
        if let resURL = Bundle.main.resourceURL {
            let candidate = resURL.appendingPathComponent("WebEditor")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        // 2. Next to the executable (SPM debug builds put resources alongside the binary)
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidates = [
            execURL.appendingPathComponent("MDMgr_MDMgr.bundle/WebEditor"),
            execURL.appendingPathComponent("WebEditor"),
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        // 3. Development fallback: look relative to the source tree
        let devPath = execURL
            .deletingLastPathComponent() // .build
            .deletingLastPathComponent() // .build parent = project root
        let devCandidate = devPath.appendingPathComponent("Resources/WebEditor")
        if FileManager.default.fileExists(atPath: devCandidate.path) {
            return devCandidate
        }
        return nil
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(coordinator, name: "bridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        // Load the web editor bundle
        let resourceURL: URL? = EditorWebView.findWebEditorBundle()

        if let resourceURL = resourceURL {
            let indexURL = resourceURL.appendingPathComponent("index.html")
            webView.loadFileURL(indexURL, allowingReadAccessTo: resourceURL)
        }

        coordinator.onReady = { [weak webView] in
            guard let webView else { return }
            let json = WebViewCoordinator.loadContentJSON(content: tab.content)
            webView.evaluateJavaScript("handleSwiftMessage('\(json.jsEscaped)')")

            let baseDir = tab.fileURL.deletingLastPathComponent().absoluteString
            let baseJSON = "{\"type\":\"setBaseURL\",\"url\":\"\(baseDir)\"}"
            webView.evaluateJavaScript("handleSwiftMessage('\(baseJSON.jsEscaped)')")
        }

        coordinator.onContentChanged = { content in
            DispatchQueue.main.async {
                tab.content = content
                tab.isDirty = true
            }
        }

        coordinator.onRequestEdit = {
            DispatchQueue.main.async { tab.mode = .edit }
        }

        coordinator.onRequestRead = {
            DispatchQueue.main.async { tab.mode = .read }
        }

        onWebViewCreated?(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if coordinator.lastSentMode != tab.mode {
            coordinator.lastSentMode = tab.mode
            let json = WebViewCoordinator.setModeJSON(mode: tab.mode)
            webView.evaluateJavaScript("handleSwiftMessage('\(json.jsEscaped)')")
        }
        if coordinator.lastSentContent != tab.content {
            coordinator.lastSentContent = tab.content
            let json = WebViewCoordinator.loadContentJSON(content: tab.content)
            webView.evaluateJavaScript("handleSwiftMessage('\(json.jsEscaped)')")
        }
    }
}

extension String {
    var jsEscaped: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
