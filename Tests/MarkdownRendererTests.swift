import XCTest
@testable import MDMgr

final class MarkdownRendererTests: XCTestCase {

    // MARK: - Helpers

    func text(_ as: NSAttributedString) -> String { `as`.string }

    func font(_ as: NSAttributedString, at pos: Int) -> NSFont? {
        `as`.attribute(.font, at: pos, effectiveRange: nil) as? NSFont
    }

    // MARK: - Tables

    func testTableUsesSeparateCellsWithAlignmentAndInlineFormatting() throws {
        let result = MarkdownRenderer.render("""
        | Signal | Measurement | Value |
        | :--- | :---: | ---: |
        | **Growth** | [Source](https://example.com) | 42 |

        After table
        """)
        var blocks: [NSTextTableBlock] = []
        var alignments: [NSTextAlignment] = []
        result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let style = value as? NSParagraphStyle,
                  let block = style.textBlocks.first as? NSTextTableBlock else { return }
            blocks.append(block)
            alignments.append(style.alignment)
        }
        XCTAssertEqual(blocks.count, 6)
        XCTAssertEqual(blocks.map(\.startingRow), [0, 0, 0, 1, 1, 1])
        XCTAssertEqual(blocks.map(\.startingColumn), [0, 1, 2, 0, 1, 2])
        XCTAssertTrue(blocks.allSatisfy { $0.table === blocks[0].table })
        XCTAssertEqual(alignments, [.natural, .center, .right, .natural, .center, .right])
        let growth = (result.string as NSString).range(of: "Growth").location
        XCTAssertTrue(NSFontManager.shared.traits(of: try XCTUnwrap(font(result, at: growth))).contains(.boldFontMask))
        let source = (result.string as NSString).range(of: "Source").location
        XCTAssertNotNil(result.attribute(.link, at: source, effectiveRange: nil))
        let after = (result.string as NSString).range(of: "After table").location
        let afterStyle = result.attribute(.paragraphStyle, at: after, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertTrue(afterStyle?.textBlocks.isEmpty ?? true)
        XCTAssertFalse(result.string.contains("│"))
    }

    func testTablePreservesEscapedPipesAndEmptyCells() {
        let result = MarkdownRenderer.render("""
        | Name | Value |
        | --- | --- |
        | A\\|B | |
        | C | 3 |
        """)
        XCTAssertEqual(result.string, "Name\nValue\nA|B\n\nC\n3\n")
    }

    func testLongTableCellsWrapWithinColumnsWhenResized() {
        let result = MarkdownRenderer.render("""
        | Signal | Proposed measurement | Source | Limitation |
        | --- | --- | --- | --- |
        | Sustained capture | Markup trend; risk-adjusted return on invested capital against cost of capital | Published competition research, company accounts, relevant regulators | Accounting comparability, intangibles, fixed costs and selection |
        | Entry response | Births and new operating capacity following attractive returns or unmet demand | ONS business demography, establishment registers | Registration is not capacity; acquisitions are not entry |
        """)
        let storage = NSTextStorage(attributedString: result)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 900, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        var previousHeight: CGFloat = 0
        for width: CGFloat in [900, 480] {
            container.containerSize.width = width
            manager.ensureLayout(for: container)
            let used = manager.usedRect(for: container)
            XCTAssertLessThanOrEqual(used.maxX, width + 1)
            XCTAssertGreaterThan(used.height, previousHeight)
            previousHeight = used.height
            func rect(_ text: String) -> NSRect {
                let range = (result.string as NSString).range(of: text)
                return manager.boundingRect(forGlyphRange: manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: container)
            }
            let first = rect("Sustained capture")
            let measurement = rect("Markup trend; risk-adjusted return on invested capital against cost of capital")
            let source = rect("Published competition research, company accounts, relevant regulators")
            let limitation = rect("Accounting comparability, intangibles, fixed costs and selection")
            XCTAssertLessThan(first.maxX, measurement.minX)
            XCTAssertLessThan(measurement.maxX, source.minX)
            XCTAssertLessThan(source.maxX, limitation.minX)
            XCTAssertGreaterThan(rect("Entry response").minY, max(measurement.maxY, limitation.maxY))
        }
    }

    @MainActor
    func testReaderViewLaysOutTextAndTablesInItsViewport() throws {
        let scrollView = MarkdownTextView.makeScrollView()
        let textView = try XCTUnwrap(scrollView.documentView as? NSTextView)
        let container = try XCTUnwrap(textView.textContainer)
        let manager = try XCTUnwrap(textView.layoutManager)
        textView.textStorage?.setAttributedString(MarkdownRenderer.render("""
        # Visible heading

        | Signal | Measurement |
        | --- | --- |
        | Growth | New operating capacity following attractive returns or unmet demand |

        Visible paragraph after the table.
        """))
        for width: CGFloat in [1000, 480] {
            scrollView.setFrameSize(NSSize(width: width, height: 400))
            scrollView.layoutSubtreeIfNeeded()
            manager.ensureLayout(for: container)
            XCTAssertGreaterThan(container.containerSize.width, 300)
            XCTAssertEqual(textView.frame.width, scrollView.contentSize.width, accuracy: 1)
            let range = manager.glyphRange(for: container)
            XCTAssertEqual(range.length, manager.numberOfGlyphs)
            let rect = manager.usedRect(for: container)
            XCTAssertGreaterThan(rect.width, 100)
            XCTAssertGreaterThan(rect.height, 50)
            XCTAssertLessThanOrEqual(rect.maxX, width)
        }
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
