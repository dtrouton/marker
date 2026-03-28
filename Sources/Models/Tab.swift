import Foundation

enum TabMode: Equatable {
    case read
    case edit
}

@Observable
final class Tab: Identifiable {
    let id = UUID()
    let fileURL: URL
    var content: String
    var isDirty: Bool = false
    var mode: TabMode = .read
    var scrollPosition: CGFloat = 0

    var displayName: String {
        fileURL.lastPathComponent
    }

    init(fileURL: URL, content: String) {
        self.fileURL = fileURL
        self.content = content
    }
}
