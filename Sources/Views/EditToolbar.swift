import SwiftUI

struct EditToolbar: View {
    let coordinator: MarkdownTextView.Coordinator?

    var body: some View {
        HStack(spacing: 2) {
            toolbarButton("B", tooltip: "Bold") { coordinator?.toggleWrap(prefix: "**", suffix: "**") }
                .fontWeight(.bold)
            toolbarButton("I", tooltip: "Italic") { coordinator?.toggleWrap(prefix: "*", suffix: "*") }
                .italic()
            divider()
            toolbarButton("H1", tooltip: "Heading 1") { coordinator?.toggleLinePrefix("# ") }
            toolbarButton("H2", tooltip: "Heading 2") { coordinator?.toggleLinePrefix("## ") }
            toolbarButton("H3", tooltip: "Heading 3") { coordinator?.toggleLinePrefix("### ") }
            divider()
            toolbarButton("\u{2022}", tooltip: "Bullet List") { coordinator?.toggleLinePrefix("- ") }
            toolbarButton("1.", tooltip: "Numbered List") { coordinator?.toggleLinePrefix("1. ") }
            divider()
            toolbarButton("</>", tooltip: "Code") { coordinator?.toggleWrap(prefix: "`", suffix: "`") }
            toolbarButton("\u{201C}", tooltip: "Block Quote") { coordinator?.toggleLinePrefix("> ") }
            toolbarButton("Link", tooltip: "Insert Link") { coordinator?.insertLink() }
            toolbarButton("\u{2014}", tooltip: "Horizontal Rule") { coordinator?.insertAtCursor("\n---\n") }
        }
    }

    private func toolbarButton(_ label: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .frame(minWidth: 24, minHeight: 20)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(tooltip)
    }

    private func divider() -> some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 2)
    }
}
