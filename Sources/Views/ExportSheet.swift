import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    let tab: Tab
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Export \(tab.displayName)")
                .font(.headline)
            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Export...") { export() }
                    .keyboardShortcut(.return)
                    .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = selectedFormat == .pdf ? [.pdf] : [.html]
        panel.nameFieldStringValue = tab.fileURL
            .deletingPathExtension()
            .lastPathComponent + (selectedFormat == .pdf ? ".pdf" : ".html")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isExporting = true
        Task {
            do {
                switch selectedFormat {
                case .pdf:
                    let rendered = MarkdownRenderer.render(tab.content, baseURL: tab.fileURL.deletingLastPathComponent())
                    try ExportService.exportPDF(content: rendered, to: url)
                case .html:
                    try ExportService.exportHTML(content: tab.content, to: url)
                }
            } catch {}
            isExporting = false
            dismiss()
        }
    }
}
