import Foundation

enum FileTreeLoader {
    static func load(directory: URL, markdownOnly: Bool) throws -> [FileNode] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        )

        var nodes: [FileNode] = []

        for url in contents {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = resourceValues.isDirectory ?? false

            if isDir {
                let children = try load(directory: url, markdownOnly: markdownOnly)
                if !markdownOnly || !children.isEmpty {
                    nodes.append(FileNode(url: url, isDirectory: true, children: children))
                }
            } else {
                let node = FileNode(url: url, isDirectory: false)
                if !markdownOnly || node.isMarkdown {
                    nodes.append(node)
                }
            }
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
