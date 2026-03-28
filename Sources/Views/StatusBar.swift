import SwiftUI

struct StatusBar: View {
    let content: String

    var body: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var statusText: String {
        let words = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let chars = content.count
        let minutes = max(1, Int(ceil(Double(words) / 200.0)))
        return "\(words) words \u{00B7} \(chars) chars \u{00B7} \(minutes) min read"
    }
}
