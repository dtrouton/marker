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
                        FileNodeRow(node: node)
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

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                ForEach(node.sortedChildren, id: \.id) { child in
                    FileNodeRow(node: child)
                }
            } label: {
                Label(node.name, systemImage: "folder")
            }
        } else {
            Label(node.name, systemImage: "doc.text")
                .tag(node.url)
        }
    }
}
