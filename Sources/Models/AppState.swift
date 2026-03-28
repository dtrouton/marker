import SwiftUI

@Observable
final class AppState {
    var tabs: [Tab] = []
    var activeTabIndex: Int = 0 {
        didSet { saveTabs() }
    }
    var folderURL: URL?
    var fileTree: [FileNode] = []
    var isSearching: Bool = false
    var searchQuery: String = ""
    var showExportSheet: Bool = false
    var showQuickOpen: Bool = false

    @ObservationIgnored
    @AppStorage("lastFolderPath") var lastFolderPath: String = ""

    var activeTab: Tab? {
        guard !tabs.isEmpty, activeTabIndex >= 0, activeTabIndex < tabs.count else { return nil }
        return tabs[activeTabIndex]
    }

    func openTab(fileURL: URL, content: String) {
        if let existingIndex = tabs.firstIndex(where: { $0.fileURL == fileURL }) {
            activeTabIndex = existingIndex
            return
        }
        let tab = Tab(fileURL: fileURL, content: content)
        let insertIndex = tabs.isEmpty ? 0 : activeTabIndex + 1
        tabs.insert(tab, at: insertIndex)
        activeTabIndex = insertIndex
        saveTabs()
    }

    func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        tabs.remove(at: index)
        if tabs.isEmpty { activeTabIndex = 0 }
        else if activeTabIndex >= tabs.count { activeTabIndex = tabs.count - 1 }
        else if index < activeTabIndex { activeTabIndex -= 1 }
        saveTabs()
    }

    func openFile(at url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            openTab(fileURL: url, content: content)
        } catch {}
    }

    func saveActiveTab() {
        guard let tab = activeTab else { return }
        saveTab(tab)
    }

    func saveTab(_ tab: Tab) {
        do {
            try tab.content.write(to: tab.fileURL, atomically: true, encoding: .utf8)
            tab.isDirty = false
        } catch {}
    }

    func closeTabWithConfirmation(at index: Int) -> Bool {
        guard index >= 0, index < tabs.count else { return false }
        if tabs[index].isDirty { return false }
        closeTab(at: index)
        return true
    }

    func saveTabs() {
        let paths = tabs.map { $0.fileURL.path }
        UserDefaults.standard.set(paths, forKey: "openTabPaths")
        UserDefaults.standard.set(activeTabIndex, forKey: "activeTabIndex")
    }

    func restoreTabs() {
        guard let paths = UserDefaults.standard.stringArray(forKey: "openTabPaths") else { return }
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            openFile(at: url)
        }
        let savedIndex = UserDefaults.standard.integer(forKey: "activeTabIndex")
        if savedIndex >= 0 && savedIndex < tabs.count {
            activeTabIndex = savedIndex
        }
    }
}
