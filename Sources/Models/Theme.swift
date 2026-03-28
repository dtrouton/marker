import AppKit

struct MarkdownTheme {
    let name: String
    let bodyFont: NSFont
    let monoFont: NSFont
    let headingFontProvider: (Int) -> NSFont  // level 1-6
    let bodySize: CGFloat
    let lineSpacing: CGFloat
    let paragraphSpacing: CGFloat
}

enum ThemeManager {
    static let themes: [MarkdownTheme] = [system, serif, mono, compact]

    static var current: MarkdownTheme {
        let name = UserDefaults.standard.string(forKey: "selectedTheme") ?? "System"
        return themes.first { $0.name == name } ?? system
    }

    static func select(_ theme: MarkdownTheme) {
        UserDefaults.standard.set(theme.name, forKey: "selectedTheme")
    }

    static let system = MarkdownTheme(
        name: "System",
        bodyFont: .systemFont(ofSize: 14),
        monoFont: .monospacedSystemFont(ofSize: 13, weight: .regular),
        headingFontProvider: { level in
            let sizes: [CGFloat] = [28, 22, 18, 16, 15, 14]
            let size = sizes[min(level - 1, 5)]
            return .systemFont(ofSize: size, weight: level <= 2 ? .bold : .semibold)
        },
        bodySize: 14,
        lineSpacing: 4,
        paragraphSpacing: 8
    )

    static let serif = MarkdownTheme(
        name: "Serif",
        bodyFont: NSFont(name: "New York", size: 16) ?? .systemFont(ofSize: 16),
        monoFont: .monospacedSystemFont(ofSize: 14, weight: .regular),
        headingFontProvider: { level in
            let sizes: [CGFloat] = [32, 26, 20, 18, 16, 15]
            let size = sizes[min(level - 1, 5)]
            if let font = NSFont(name: "New York", size: size) {
                return NSFontManager.shared.convert(font, toHaveTrait: level <= 2 ? .boldFontMask : .unboldFontMask)
            }
            return .systemFont(ofSize: size, weight: level <= 2 ? .bold : .semibold)
        },
        bodySize: 16,
        lineSpacing: 5,
        paragraphSpacing: 10
    )

    static let mono = MarkdownTheme(
        name: "Mono",
        bodyFont: .monospacedSystemFont(ofSize: 13, weight: .regular),
        monoFont: .monospacedSystemFont(ofSize: 13, weight: .regular),
        headingFontProvider: { level in
            let sizes: [CGFloat] = [24, 20, 16, 14, 13, 12]
            let size = sizes[min(level - 1, 5)]
            return .monospacedSystemFont(ofSize: size, weight: .bold)
        },
        bodySize: 13,
        lineSpacing: 3,
        paragraphSpacing: 6
    )

    static let compact = MarkdownTheme(
        name: "Compact",
        bodyFont: .systemFont(ofSize: 12),
        monoFont: .monospacedSystemFont(ofSize: 11, weight: .regular),
        headingFontProvider: { level in
            let sizes: [CGFloat] = [22, 18, 15, 13, 12, 11]
            let size = sizes[min(level - 1, 5)]
            return .systemFont(ofSize: size, weight: level <= 2 ? .bold : .semibold)
        },
        bodySize: 12,
        lineSpacing: 2,
        paragraphSpacing: 4
    )
}
