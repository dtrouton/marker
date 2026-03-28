import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    let tab: Tab

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 32, height: 24)
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        scrollView.documentView = textView
        applyContent(to: textView, tab: tab)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator
        coordinator.tab = tab

        if coordinator.lastMode != tab.mode {
            coordinator.lastMode = tab.mode
            applyContent(to: textView, tab: tab)
        }

        if coordinator.lastContent != tab.content {
            coordinator.lastContent = tab.content
            if !coordinator.isLocalEdit {
                applyContent(to: textView, tab: tab)
            }
            coordinator.isLocalEdit = false
        }
    }

    private func applyContent(to textView: NSTextView, tab: Tab) {
        if tab.mode == .read {
            textView.isEditable = false
            textView.isSelectable = true
            let rendered = MarkdownRenderer.render(tab.content)
            textView.textStorage?.setAttributedString(rendered)
        } else {
            textView.isEditable = true
            textView.isSelectable = true
            textView.textStorage?.setAttributedString(
                NSAttributedString(string: tab.content, attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.labelColor
                ])
            )
            if let storage = textView.textStorage {
                MarkdownSyntaxHighlighter.highlight(storage)
            }
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var tab: Tab
        weak var textView: NSTextView?
        var lastMode: TabMode?
        var lastContent: String?
        var isLocalEdit = false
        private var highlightTimer: Timer?

        init(tab: Tab) {
            self.tab = tab
            self.lastMode = tab.mode
            self.lastContent = tab.content
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newContent = textView.string
            isLocalEdit = true
            tab.content = newContent
            tab.isDirty = true
            lastContent = newContent

            highlightTimer?.invalidate()
            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak textView] _ in
                guard let textView, let storage = textView.textStorage else { return }
                let sel = textView.selectedRange()
                storage.beginEditing()
                MarkdownSyntaxHighlighter.highlight(storage)
                storage.endEditing()
                textView.setSelectedRange(sel)
            }
        }
    }
}
