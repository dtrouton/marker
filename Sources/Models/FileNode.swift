import Foundation

struct FileNode: Identifiable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]

    var name: String { url.lastPathComponent }

    var isMarkdown: Bool {
        let ext = url.pathExtension.lowercased()
        return ["md", "markdown", "mdown", "mkd"].contains(ext)
    }

    var sortedChildren: [FileNode] {
        children.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    init(url: URL, isDirectory: Bool, children: [FileNode] = []) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }
}
