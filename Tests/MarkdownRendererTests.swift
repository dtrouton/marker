import XCTest
@testable import MDMgr

final class MarkdownRendererTests: XCTestCase {

    // MARK: - Helpers

    func text(_ as: NSAttributedString) -> String { `as`.string }

    func font(_ as: NSAttributedString, at pos: Int) -> NSFont? {
        `as`.attribute(.font, at: pos, effectiveRange: nil) as? NSFont
    }

    // MARK: - Headings

    func testH1RendersLargeBoldFont() {
        let result = MarkdownRenderer.render("# Heading One")
        let f = font(result, at: 0)
        XCTAssertNotNil(f)
        XCTAssertGreaterThan(f!.pointSize, 20)
        let traits = NSFontManager.shared.traits(of: f!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    func testH2RendersMediumBoldFont() {
        let result = MarkdownRenderer.render("## Heading Two")
        let f = font(result, at: 0)
        XCTAssertNotNil(f)
        XCTAssertGreaterThan(f!.pointSize, 16)
        let traits = NSFontManager.shared.traits(of: f!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    // MARK: - Bold

    func testBoldTextHasBoldTrait() {
        let result = MarkdownRenderer.render("Hello **bold** world")
        let boldText = text(result)
        // Find where "bold" starts in the rendered string
        guard let range = boldText.range(of: "bold") else {
            XCTFail("Expected 'bold' in output")
            return
        }
        let nsRange = NSRange(range, in: boldText)
        let f = font(result, at: nsRange.location)
        XCTAssertNotNil(f)
        let traits = NSFontManager.shared.traits(of: f!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    // MARK: - Italic

    func testItalicTextHasItalicTrait() {
        let result = MarkdownRenderer.render("Hello *italic* world")
        let rendered = text(result)
        guard let range = rendered.range(of: "italic") else {
            XCTFail("Expected 'italic' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let f = font(result, at: nsRange.location)
        XCTAssertNotNil(f)
        let traits = NSFontManager.shared.traits(of: f!)
        XCTAssertTrue(traits.contains(.italicFontMask))
    }

    // MARK: - Inline code

    func testInlineCodeUsesMonospaceFont() {
        let result = MarkdownRenderer.render("Use `code` here")
        let rendered = text(result)
        guard let range = rendered.range(of: "code") else {
            XCTFail("Expected 'code' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let f = font(result, at: nsRange.location)
        XCTAssertNotNil(f)
        XCTAssertTrue(f!.isFixedPitch || f!.fontName.lowercased().contains("mono"))
    }

    // MARK: - Code block

    func testCodeBlockUsesMonospaceFont() {
        let md = """
        ```
        let x = 1
        ```
        """
        let result = MarkdownRenderer.render(md)
        let rendered = text(result)
        guard let range = rendered.range(of: "let x = 1") else {
            XCTFail("Expected 'let x = 1' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let f = font(result, at: nsRange.location)
        XCTAssertNotNil(f)
        XCTAssertTrue(f!.isFixedPitch || f!.fontName.lowercased().contains("mono"))
    }

    // MARK: - Links

    func testLinksHaveLinkAttribute() {
        let result = MarkdownRenderer.render("Visit [Google](https://google.com) now")
        let rendered = text(result)
        guard let range = rendered.range(of: "Google") else {
            XCTFail("Expected 'Google' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let link = result.attribute(.link, at: nsRange.location, effectiveRange: nil)
        XCTAssertNotNil(link)
    }

    // MARK: - Unordered list

    func testUnorderedListContainsBullet() {
        let result = MarkdownRenderer.render("- Item one")
        let rendered = text(result)
        XCTAssertTrue(rendered.contains("•"))
    }

    // MARK: - Blockquote

    func testBlockquoteContainsText() {
        let result = MarkdownRenderer.render("> Some quote")
        let rendered = text(result)
        XCTAssertTrue(rendered.contains("Some quote"))
    }

    // MARK: - Horizontal rule

    func testHorizontalRuleRenders() {
        let result = MarkdownRenderer.render("---")
        let rendered = text(result)
        XCTAssertFalse(rendered.isEmpty)
    }

    // MARK: - Empty input

    func testEmptyInputReturnsEmptyString() {
        let result = MarkdownRenderer.render("")
        XCTAssertEqual(text(result), "")
    }

    // MARK: - Strikethrough

    func testStrikethroughRendersWithStrikethroughStyle() {
        let result = MarkdownRenderer.render("Hello ~~removed~~ world")
        let rendered = text(result)
        guard let range = rendered.range(of: "removed") else {
            XCTFail("Expected 'removed' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let style = result.attribute(.strikethroughStyle, at: nsRange.location, effectiveRange: nil) as? Int
        XCTAssertNotNil(style)
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testStrikethroughStripsMarkers() {
        let result = MarkdownRenderer.render("Hello ~~removed~~ world")
        let rendered = text(result)
        XCTAssertFalse(rendered.contains("~~"))
        XCTAssertTrue(rendered.contains("removed"))
    }

    func testStrikethroughHasStrikethroughColor() {
        let result = MarkdownRenderer.render("~~gone~~")
        let rendered = text(result)
        guard let range = rendered.range(of: "gone") else {
            XCTFail("Expected 'gone' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let color = result.attribute(.strikethroughColor, at: nsRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(color)
    }

    // MARK: - Footnote references

    func testFootnoteReferenceRendersAsSuperscript() {
        let result = MarkdownRenderer.render("See this[^1] for details")
        let rendered = text(result)
        guard let range = rendered.range(of: "1") else {
            XCTFail("Expected '1' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let sup = result.attribute(.superscript, at: nsRange.location, effectiveRange: nil) as? Int
        XCTAssertEqual(sup, 1)
    }

    func testFootnoteReferenceStripsMarkers() {
        let result = MarkdownRenderer.render("Text[^1] here")
        let rendered = text(result)
        XCTAssertFalse(rendered.contains("[^"))
        XCTAssertFalse(rendered.contains("]"))
        XCTAssertTrue(rendered.contains("1"))
    }

    func testFootnoteReferenceUsesLinkColor() {
        let result = MarkdownRenderer.render("Text[^1] here")
        let rendered = text(result)
        guard let range = rendered.range(of: "1") else {
            XCTFail("Expected '1' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let color = result.attribute(.foregroundColor, at: nsRange.location, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor.linkColor)
    }

    // MARK: - Footnote definitions

    func testFootnoteDefinitionRendersSmallFont() {
        let result = MarkdownRenderer.render("[^1]: This is a footnote")
        let rendered = text(result)
        XCTAssertTrue(rendered.contains("This is a footnote"))
        // Find the body text and check the font is smaller than body
        guard let range = rendered.range(of: "This is a footnote") else {
            XCTFail("Expected footnote text in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let f = font(result, at: nsRange.location)
        XCTAssertNotNil(f)
        XCTAssertLessThan(f!.pointSize, 14) // smaller than body font
    }

    func testFootnoteDefinitionLabelIsSuperscript() {
        let result = MarkdownRenderer.render("[^1]: Footnote text")
        let rendered = text(result)
        guard let range = rendered.range(of: "1") else {
            XCTFail("Expected '1' in output")
            return
        }
        let nsRange = NSRange(range, in: rendered)
        let sup = result.attribute(.superscript, at: nsRange.location, effectiveRange: nil) as? Int
        XCTAssertEqual(sup, 1)
    }

    // MARK: - Plain text

    func testPlainTextPassesThrough() {
        let result = MarkdownRenderer.render("Hello world")
        XCTAssertTrue(text(result).contains("Hello world"))
    }
}
