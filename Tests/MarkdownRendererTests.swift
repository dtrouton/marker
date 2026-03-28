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

    // MARK: - Plain text

    func testPlainTextPassesThrough() {
        let result = MarkdownRenderer.render("Hello world")
        XCTAssertTrue(text(result).contains("Hello world"))
    }
}
