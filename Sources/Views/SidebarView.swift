import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState
    @State private var watcher: FileWatcher?

    var body: some View {
        VStack(spacing: 0) {
            if appState.fileTree.isEmpty {
                ContentUnavailableView {
                    Label("No Folder Open", systemImage: "folder")
                } description: {
                    Text("Open a folder to browse markdown files")
                } actions: {
                    Button("Open Folder…") {
                        openFolder()
                    }
                }
            } else {
                List(selection: Binding<URL?>(
                    get: { appState.activeTab?.fileURL },
                    set: { url in
                        if let url { appState.openFile(at: url) }
                    }
                )) {
                    ForEach(appState.fileTree, id: \.id) { node in
                        FileNodeRow(node: node, gitStatus: appState.gitStatus)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200)
        .onChange(of: appState.folderURL) { _, newURL in
            watcher?.stop()
            guard let url = newURL else { return }
            let state = appState
            watcher = FileWatcher(url: url) {
                do {
                    state.fileTree = try FileTreeLoader.load(directory: url, markdownOnly: true)
                } catch {}
                state.refreshGitStatus()
            }
            watcher?.start()
        }
        .onDisappear {
            watcher?.stop()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
            }
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.folderURL = url
            appState.lastFolderPath = url.path
            reloadTree()
            appState.refreshGitStatus()
        }
    }

    func reloadTree() {
        guard let folder = appState.folderURL else { return }
        do {
            appState.fileTree = try FileTreeLoader.load(directory: folder, markdownOnly: true)
        } catch {
            appState.fileTree = []
        }
    }
}

struct FileNodeRow: View {
    let node: FileNode
    let gitStatus: [URL: GitFileStatus]

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                ForEach(node.sortedChildren, id: \.id) { child in
                    FileNodeRow(node: child, gitStatus: gitStatus)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else {
            HStack {
                Label(node.name, systemImage: "doc.text")
                Spacer()
                if let status = gitStatus[node.url] {
                    Text(statusLabel(status))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor(status))
                }
            }
            .tag(node.url)
        }
    }

    private func statusLabel(_ status: GitFileStatus) -> String {
        switch status {
        case .modified: return "M"
        case .added: return "A"
        case .untracked: return "?"
        }
    }

    private func statusColor(_ status: GitFileStatus) -> Color {
        switch status {
        case .modified: return .orange
        case .added: return .green
        case .untracked: return .gray
        }
    }
}
