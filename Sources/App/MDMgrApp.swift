import SwiftUI
import UniformTypeIdentifiers

private func findPanelSender(action: NSFindPanelAction) -> NSMenuItem {
    let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    item.tag = Int(action.rawValue)
    return item
}

@main
struct MDMgrApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onOpenURL { url in
                    appState.openFile(at: url)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.plainText]
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK {
                        for url in panel.urls {
                            appState.openFile(at: url)
                        }
                    }
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Folder...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        appState.folderURL = url
                        appState.lastFolderPath = url.path
                        do {
                            appState.fileTree = try FileTreeLoader.load(directory: url, markdownOnly: true)
                        } catch {}
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Menu("Recent Files") {
                    ForEach(appState.recentFiles, id: \.path) { url in
                        Button(url.lastPathComponent) {
                            appState.openFile(at: url)
                        }
                    }
                    if !appState.recentFiles.isEmpty {
                        Divider()
                        Button("Clear Recent Files") {
                            UserDefaults.standard.removeObject(forKey: "recentFiles")
                        }
                    }
                }
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appState.saveActiveTab()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.activeTab == nil || !(appState.activeTab?.isDirty ?? false))

                Button("Export…") {
                    appState.showExportSheet = true
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.activeTab == nil)
            }

            CommandGroup(before: .textEditing) {
                Button("Quick Open") {
                    appState.showQuickOpen = true
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(appState.folderURL == nil)
            }

            CommandGroup(after: .textEditing) {
                Button("Find…") {
                    NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: findPanelSender(action: .showFindPanel))
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: findPanelSender(action: .next))
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: findPanelSender(action: .previous))
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Divider()

                Button("Find in Folder") {
                    appState.isSearching = true
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(after: .windowArrangement) {
                Button("Next Tab") {
                    if !appState.tabs.isEmpty {
                        appState.activeTabIndex = (appState.activeTabIndex + 1) % appState.tabs.count
                    }
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    if !appState.tabs.isEmpty {
                        appState.activeTabIndex = (appState.activeTabIndex - 1 + appState.tabs.count) % appState.tabs.count
                    }
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Close Tab") {
                    appState.closeTab(at: appState.activeTabIndex)
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Toggle Edit Mode") {
                    if let tab = appState.activeTab {
                        tab.mode = tab.mode == .read ? .edit : .read
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(appState.activeTab == nil)
            }
        }
    }
}
