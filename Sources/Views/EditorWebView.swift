import SwiftUI
import WebKit

struct EditorWebView: NSViewRepresentable {
    let tab: Tab
    let coordinator: WebViewCoordinator
    var onWebViewCreated: ((WKWebView) -> Void)?

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
        // 2. Next to the executable (SPM builds)
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
        // 3. Development fallback: source tree
        let devPath = execURL.deletingLastPathComponent().deletingLastPathComponent()
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
        webView.isInspectable = true

        if let resourceURL = EditorWebView.findWebEditorBundle() {
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
