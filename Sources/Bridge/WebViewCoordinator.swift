import WebKit

final class WebViewCoordinator: NSObject, WKScriptMessageHandler {
    var onContentChanged: ((String) -> Void)?
    var onRequestEdit: (() -> Void)?
    var onRequestRead: (() -> Void)?
    var onReady: (() -> Void)?
    var lastSentContent: String?
    var lastSentMode: TabMode?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "contentChanged":
            if let content = json["content"] as? String {
                onContentChanged?(content)
            }
        case "requestEdit":
            onRequestEdit?()
        case "requestRead":
            onRequestRead?()
        case "ready":
            onReady?()
        default:
            break
        }
    }

    // MARK: - Message builders

    static func loadContentJSON(content: String) -> String {
        let payload: [String: Any] = ["type": "loadContent", "content": content]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8)!
    }

    static func setModeJSON(mode: TabMode) -> String {
        let modeStr = mode == .edit ? "edit" : "read"
        let payload: [String: Any] = ["type": "setMode", "mode": modeStr]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8)!
    }

    static func searchJSON(query: String) -> String {
        let payload: [String: Any] = ["type": "search", "query": query]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8)!
    }
}
