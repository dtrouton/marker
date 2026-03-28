import SwiftUI
import UniformTypeIdentifiers

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
                Button("Open File…") {
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
            }
        }
    }
}
