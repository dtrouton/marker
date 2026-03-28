import SwiftUI

struct TableOfContents: View {
    let content: String
    var onSelect: (Int) -> Void

    struct HeadingItem: Identifiable {
        let id = UUID()
        let level: Int
        let text: String
        let lineNumber: Int
    }

    private static let headingRegex = try! NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#)

    var headings: [HeadingItem] {
        content.components(separatedBy: "\n").enumerated().compactMap { (i, line) in
            let range = NSRange(line.startIndex..., in: line)
            guard let match = Self.headingRegex.firstMatch(in: line, range: range) else { return nil }
            guard let hashRange = Range(match.range(at: 1), in: line),
                  let textRange = Range(match.range(at: 2), in: line) else { return nil }
            let level = line[hashRange].count
            let text = String(line[textRange])
            return HeadingItem(level: level, text: text, lineNumber: i)
        }
    }

    var body: some View {
        List(headings) { heading in
            Button(action: { onSelect(heading.lineNumber) }) {
                Text(heading.text)
                    .font(heading.level <= 2 ? .callout.bold() : .callout)
                    .padding(.leading, CGFloat((heading.level - 1) * 12))
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}
