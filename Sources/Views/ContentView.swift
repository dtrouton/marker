import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var tabToClose: Int?
    @State private var showUnsavedAlert = false
    @State private var editorCoordinator: MarkdownTextView.Coordinator?

    var body: some View {
        NavigationSplitView {
            if appState.isSearching {
                SearchPanel(appState: appState)
            } else {
                SidebarView(appState: appState)
            }
        } detail: {
            VStack(spacing: 0) {
                if !appState.tabs.isEmpty {
                    TabBarView(appState: appState, onClose: handleTabClose)
                    Divider()
                    if let tab = appState.activeTab {
                        HStack(spacing: 4) {
                            if tab.mode == .edit {
                                EditToolbar(coordinator: editorCoordinator)
                            }
                            Spacer()
                            Button(tab.mode == .read ? "Edit" : "Done") {
                                tab.mode = tab.mode == .read ? .edit : .read
                            }
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)

                        HStack(spacing: 0) {
                            MarkdownTextView(tab: tab, onCoordinatorReady: { coord in
                                editorCoordinator = coord
                            })

                            if appState.showTableOfContents {
                                Divider()
                                TableOfContents(content: tab.content) { lineNumber in
                                    editorCoordinator?.scrollToLine(lineNumber)
                                }
                                .frame(width: 220)
                            }
                        }
                        StatusBar(content: tab.content)
                    }
                } else {
                    ContentUnavailableView {
                        Label("No File Open", systemImage: "doc.text")
                    } description: {
                        Text("Open a file from the sidebar or Finder")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { restoreLastFolder() }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .sheet(isPresented: $appState.showExportSheet) {
            if let tab = appState.activeTab {
                ExportSheet(tab: tab)
            }
        }
        .overlay {
            if appState.showQuickOpen {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { appState.showQuickOpen = false }

                    VStack {
                        QuickOpenPanel(appState: appState)
                            .padding(.top, 40)
                        Spacer()
                    }
                }
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Save") {
                if let idx = tabToClose {
                    appState.saveTab(appState.tabs[idx])
                    appState.closeTab(at: idx)
                }
            }
            Button("Don't Save", role: .destructive) {
                if let idx = tabToClose { appState.closeTab(at: idx) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save changes before closing?")
        }
    }

    private func handleTabClose(at index: Int) {
        if !appState.closeTabWithConfirmation(at: index) {
            tabToClose = index
            showUnsavedAlert = true
        }
    }

    private func restoreLastFolder() {
        let path = appState.lastFolderPath
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            appState.folderURL = url
            do {
                appState.fileTree = try FileTreeLoader.load(directory: url, markdownOnly: true)
            } catch {}
        }
        appState.restoreTabs()
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url") { data, _ in
                guard let data = data as? Data,
                      let urlString = String(data: data, encoding: .utf8),
                      let url = URL(string: urlString) else { return }
                let ext = url.pathExtension.lowercased()
                if ["md", "markdown", "mdown", "mkd"].contains(ext) {
                    DispatchQueue.main.async {
                        appState.openFile(at: url)
                    }
                }
            }
        }
        return true
    }
}
