import SwiftUI

struct QuickOpenPanel: View {
    @Bindable var appState: AppState
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0

    private var allFiles: [(url: URL, relativePath: String)] {
        guard let folderURL = appState.folderURL else { return [] }
        let urls = flattenFiles(appState.fileTree)
        let folderPath = folderURL.path.hasSuffix("/") ? folderURL.path : folderURL.path + "/"
        return urls.map { url in
            let rel = url.path.hasPrefix(folderPath)
                ? String(url.path.dropFirst(folderPath.count))
                : url.lastPathComponent
            return (url: url, relativePath: rel)
        }
    }

    private var filteredFiles: [(url: URL, relativePath: String)] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let files: [(url: URL, relativePath: String)]
        if trimmed.isEmpty {
            files = allFiles
        } else {
            files = allFiles.filter { fuzzyMatch(query: trimmed, target: $0.relativePath) }
        }
        return Array(files.prefix(20))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Open file…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit { openSelected() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if filteredFiles.isEmpty {
                Text(query.isEmpty ? "No files in folder" : "No matching files")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredFiles.enumerated()), id: \.offset) { index, file in
                        Button {
                            appState.openFile(at: file.url)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 12))
                                Text(file.relativePath)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            index == selectedIndex
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .id(index)
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 500, height: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredFiles.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private func openSelected() {
        guard !filteredFiles.isEmpty, selectedIndex < filteredFiles.count else { return }
        appState.openFile(at: filteredFiles[selectedIndex].url)
        dismiss()
    }

    private func dismiss() {
        appState.showQuickOpen = false
    }

    private func flattenFiles(_ nodes: [FileNode]) -> [URL] {
        var result: [URL] = []
        for node in nodes {
            if node.isDirectory {
                result += flattenFiles(node.children)
            } else {
                result.append(node.url)
            }
        }
        return result
    }

    private func fuzzyMatch(query: String, target: String) -> Bool {
        let query = query.lowercased()
        let target = target.lowercased()
        var queryIndex = query.startIndex
        for char in target {
            if queryIndex < query.endIndex && char == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
            }
        }
        return queryIndex == query.endIndex
    }
}
