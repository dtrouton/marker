import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
        } detail: {
            if appState.activeTab != nil {
                Text("Editor placeholder — \(appState.activeTab!.displayName)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("No File Open", systemImage: "doc.text")
                } description: {
                    Text("Open a file from the sidebar or Finder")
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            restoreLastFolder()
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
    }
}
