import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let lineNumber: Int
    let lineContent: String

    var fileName: String { fileURL.lastPathComponent }
}

enum FolderSearchService {
    static func search(query: String, in folderURL: URL) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        var results: [SearchResult] = []

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let extensions = Set(["md", "markdown", "mdown", "mkd"])

        for case let fileURL as URL in enumerator {
            guard extensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.range(of: query, options: .caseInsensitive) != nil {
                    results.append(SearchResult(
                        fileURL: fileURL,
                        lineNumber: index + 1,
                        lineContent: line
                    ))
                }
            }
        }

        return results
    }
}
