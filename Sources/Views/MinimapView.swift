import SwiftUI

struct MinimapView: View {
    let content: String
    let visiblePercentage: CGFloat
    let scrollPercentage: CGFloat
    var onScroll: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let lines = content.components(separatedBy: "\n")
                let lineHeight = size.height / max(CGFloat(lines.count), 1)

                for (i, line) in lines.enumerated() {
                    let y = CGFloat(i) * lineHeight
                    let width = min(size.width - 8, CGFloat(line.count) * 0.8)
                    let color: Color
                    if line.hasPrefix("#") { color = .blue }
                    else if line.hasPrefix("```") || line.hasPrefix("    ") { color = .gray.opacity(0.5) }
                    else if line.hasPrefix(">") { color = .orange.opacity(0.3) }
                    else if line.isEmpty { color = .clear }
                    else { color = .primary.opacity(0.2) }

                    context.fill(
                        Path(CGRect(x: 4, y: y, width: max(width, 2), height: max(lineHeight - 0.5, 0.5))),
                        with: .color(color)
                    )
                }

                // Draw visible area indicator
                let indicatorY = scrollPercentage * size.height
                let indicatorHeight = max(visiblePercentage * size.height, 4)
                context.fill(
                    Path(CGRect(x: 0, y: indicatorY, width: size.width, height: indicatorHeight)),
                    with: .color(.accentColor.opacity(0.15))
                )
                context.stroke(
                    Path(CGRect(x: 0, y: indicatorY, width: size.width, height: indicatorHeight)),
                    with: .color(.accentColor.opacity(0.3)),
                    lineWidth: 1
                )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percentage = value.location.y / geo.size.height
                        onScroll(min(max(percentage, 0), 1))
                    }
            )
        }
        .frame(width: 60)
        .background(.bar)
    }
}
