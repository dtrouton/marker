import SwiftUI

struct SearchPanel: View {
    @Bindable var appState: AppState
    @State private var results: [SearchResult] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search in folder…", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit { performSearch() }
                if !appState.searchQuery.isEmpty {
                    Button(action: {
                        appState.searchQuery = ""
                        results = []
                        appState.isSearching = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)

            Divider()

            if results.isEmpty && !appState.searchQuery.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass")
                    .frame(maxHeight: .infinity)
            } else {
                List(results) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.fileName)
                            .font(.callout.bold())
                        Text("Line \(result.lineNumber): \(result.lineContent)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.openFile(at: result.fileURL)
                        appState.isSearching = false
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func performSearch() {
        guard let folder = appState.folderURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let found = FolderSearchService.search(query: appState.searchQuery, in: folder)
            DispatchQueue.main.async {
                results = found
            }
        }
    }
}
