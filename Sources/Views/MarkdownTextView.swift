import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    let tab: Tab
    var onCoordinatorReady: ((Coordinator) -> Void)?
    @Binding var scrollPercentage: CGFloat
    @Binding var visiblePercentage: CGFloat

    func makeCoordinator() -> Coordinator {
        let coord = Coordinator(tab: tab, scrollPercentage: $scrollPercentage, visiblePercentage: $visiblePercentage)
        DispatchQueue.main.async { onCoordinatorReady?(coord) }
        return coord
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
        textView.usesFindBar = true
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

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        context.coordinator.scrollView = scrollView

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
        // Save scroll position as a percentage so it survives content-height changes
        // between read mode (rendered) and edit mode (raw markdown).
        let scrollView = textView.enclosingScrollView
        let scrollPercentage: CGFloat = {
            guard let sv = scrollView,
                  let docView = sv.documentView else { return 0 }
            let contentHeight = docView.frame.height
            let scrollOffset = sv.contentView.bounds.origin.y
            return contentHeight > 0 ? scrollOffset / contentHeight : 0
        }()

        if tab.mode == .read {
            textView.isEditable = false
            textView.isSelectable = true
            let rendered = MarkdownRenderer.render(tab.content, baseURL: tab.fileURL.deletingLastPathComponent())
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

        // Restore scroll position using the saved percentage.
        if let sv = scrollView {
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let newContentHeight = sv.documentView?.frame.height ?? 0
            let newOffset = scrollPercentage * newContentHeight
            sv.contentView.scroll(to: NSPoint(x: 0, y: newOffset))
            sv.reflectScrolledClipView(sv.contentView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var tab: Tab
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var lastMode: TabMode?
        var lastContent: String?
        var isLocalEdit = false
        private var highlightTimer: Timer?
        private var scrollPercentageBinding: Binding<CGFloat>
        private var visiblePercentageBinding: Binding<CGFloat>

        init(tab: Tab, scrollPercentage: Binding<CGFloat>, visiblePercentage: Binding<CGFloat>) {
            self.tab = tab
            self.lastMode = tab.mode
            self.lastContent = tab.content
            self.scrollPercentageBinding = scrollPercentage
            self.visiblePercentageBinding = visiblePercentage
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let sv = scrollView,
                  let docView = sv.documentView else { return }
            let contentHeight = docView.frame.height
            let visibleHeight = sv.contentView.bounds.height
            let scrollOffset = sv.contentView.bounds.origin.y
            let scrollable = contentHeight - visibleHeight
            guard scrollable > 0 else {
                scrollPercentageBinding.wrappedValue = 0
                visiblePercentageBinding.wrappedValue = 1
                return
            }
            scrollPercentageBinding.wrappedValue = scrollOffset / contentHeight
            visiblePercentageBinding.wrappedValue = visibleHeight / contentHeight
        }

        func scrollToPercentage(_ percentage: CGFloat) {
            guard let sv = scrollView,
                  let docView = sv.documentView else { return }
            let contentHeight = docView.frame.height
            let visibleHeight = sv.contentView.bounds.height
            // Center the visible area on the clicked position
            let targetOffset = percentage * contentHeight - visibleHeight / 2
            let maxOffset = contentHeight - visibleHeight
            let clampedOffset = min(max(targetOffset, 0), maxOffset)
            sv.contentView.scroll(to: NSPoint(x: 0, y: clampedOffset))
            sv.reflectScrolledClipView(sv.contentView)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
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

        // MARK: - Toolbar Actions

        /// Toggle wrap: if selection is wrapped with prefix/suffix, remove; otherwise add.
        func toggleWrap(prefix: String, suffix: String) {
            guard let tv = textView else { return }
            let text = tv.string as NSString
            let sel = tv.selectedRange()

            // Check if text around selection is the wrapper
            let beforeStart = sel.location - prefix.count
            let afterEnd = sel.location + sel.length
            if beforeStart >= 0 && afterEnd + suffix.count <= text.length {
                let before = text.substring(with: NSRange(location: beforeStart, length: prefix.count))
                let after = text.substring(with: NSRange(location: afterEnd, length: suffix.count))
                if before == prefix && after == suffix {
                    // Remove wrapping
                    let fullRange = NSRange(location: beforeStart, length: sel.length + prefix.count + suffix.count)
                    let inner = text.substring(with: sel)
                    tv.insertText(inner, replacementRange: fullRange)
                    tv.setSelectedRange(NSRange(location: beforeStart, length: sel.length))
                    return
                }
            }

            // Check if selection itself contains the wrappers
            if sel.length >= prefix.count + suffix.count {
                let selText = text.substring(with: sel)
                if selText.hasPrefix(prefix) && selText.hasSuffix(suffix) {
                    let innerStart = selText.index(selText.startIndex, offsetBy: prefix.count)
                    let innerEnd = selText.index(selText.endIndex, offsetBy: -suffix.count)
                    let inner = String(selText[innerStart..<innerEnd])
                    tv.insertText(inner, replacementRange: sel)
                    tv.setSelectedRange(NSRange(location: sel.location, length: inner.count))
                    return
                }
            }

            // Add wrapping
            let selText = text.substring(with: sel)
            let replacement = prefix + selText + suffix
            tv.insertText(replacement, replacementRange: sel)
            tv.setSelectedRange(NSRange(location: sel.location + prefix.count, length: sel.length))
        }

        /// Toggle line prefix: if current line starts with prefix, remove; otherwise add.
        func toggleLinePrefix(_ prefix: String) {
            guard let tv = textView else { return }
            let text = tv.string as NSString
            let sel = tv.selectedRange()

            // Find line start
            let lineStart = text.lineRange(for: NSRange(location: sel.location, length: 0)).location
            let lineRange = text.lineRange(for: NSRange(location: sel.location, length: 0))
            let line = text.substring(with: lineRange)

            if line.hasPrefix(prefix) {
                // Remove prefix
                let prefixRange = NSRange(location: lineStart, length: prefix.count)
                tv.insertText("", replacementRange: prefixRange)
            } else {
                // Add prefix
                tv.insertText(prefix, replacementRange: NSRange(location: lineStart, length: 0))
            }
        }

        /// Insert text at cursor position
        func insertAtCursor(_ text: String) {
            guard let tv = textView else { return }
            let sel = tv.selectedRange()
            tv.insertText(text, replacementRange: sel)
        }

        /// Insert link wrapping selection as the link text
        func insertLink() {
            guard let tv = textView else { return }
            let text = tv.string as NSString
            let sel = tv.selectedRange()
            let selText = sel.length > 0 ? text.substring(with: sel) : "text"
            let replacement = "[\(selText)](url)"
            tv.insertText(replacement, replacementRange: sel)
            // Select "url" for easy replacement
            let urlStart = sel.location + selText.count + 2 // after "[text]("
            tv.setSelectedRange(NSRange(location: urlStart, length: 3))
        }

        /// Scroll to a specific line number (zero-based)
        func scrollToLine(_ lineNumber: Int) {
            guard let tv = textView else { return }
            let text = tv.string as NSString
            var currentLine = 0
            var charIndex = 0
            while currentLine < lineNumber && charIndex < text.length {
                if text.character(at: charIndex) == UInt16(UnicodeScalar("\n").value) {
                    currentLine += 1
                }
                charIndex += 1
            }
            let range = NSRange(location: charIndex, length: 0)
            tv.scrollRangeToVisible(range)
            tv.setSelectedRange(range)
        }
    }
}
