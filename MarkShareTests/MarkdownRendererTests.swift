import XCTest
@testable import MarkShare

final class MarkdownRendererTests: XCTestCase {

    var renderer: MarkdownRenderer!

    override func setUp() {
        super.setUp()
        renderer = MarkdownRenderer()
    }

    // MARK: - Headers

    func testH1() {
        let html = renderer.convertToHTML("# Hello")
        XCTAssertTrue(html.contains("<h1>Hello</h1>"))
    }

    func testH2() {
        let html = renderer.convertToHTML("## Hello")
        XCTAssertTrue(html.contains("<h2>Hello</h2>"))
    }

    func testH3() {
        let html = renderer.convertToHTML("### Hello")
        XCTAssertTrue(html.contains("<h3>Hello</h3>"))
    }

    func testH4() {
        let html = renderer.convertToHTML("#### Hello")
        XCTAssertTrue(html.contains("<h4>Hello</h4>"))
    }

    func testH5() {
        let html = renderer.convertToHTML("##### Hello")
        XCTAssertTrue(html.contains("<h5>Hello</h5>"))
    }

    func testH6() {
        let html = renderer.convertToHTML("###### Hello")
        XCTAssertTrue(html.contains("<h6>Hello</h6>"))
    }

    func testHeaderWithTrailingHashes() {
        let html = renderer.convertToHTML("## Hello ##")
        XCTAssertTrue(html.contains("<h2>Hello</h2>"))
    }

    func testHeaderWithInlineFormatting() {
        let html = renderer.convertToHTML("# Hello **world**")
        XCTAssertTrue(html.contains("<h1>Hello <strong>world</strong></h1>"))
    }

    // MARK: - Paragraphs

    func testSimpleParagraph() {
        let html = renderer.convertToHTML("Hello world")
        XCTAssertTrue(html.contains("<p>Hello world</p>"))
    }

    func testMultilineParagraph() {
        let html = renderer.convertToHTML("Hello\nworld")
        XCTAssertTrue(html.contains("<p>Hello world</p>"))
    }

    func testMultipleParagraphs() {
        let html = renderer.convertToHTML("First paragraph\n\nSecond paragraph")
        XCTAssertTrue(html.contains("<p>First paragraph</p>"))
        XCTAssertTrue(html.contains("<p>Second paragraph</p>"))
    }

    // MARK: - Inline Formatting

    func testBoldWithAsterisks() {
        let html = renderer.convertToHTML("Hello **world**")
        XCTAssertTrue(html.contains("<strong>world</strong>"))
    }

    func testBoldWithUnderscores() {
        let html = renderer.convertToHTML("Hello __world__")
        XCTAssertTrue(html.contains("<strong>world</strong>"))
    }

    func testItalicWithAsterisks() {
        let html = renderer.convertToHTML("Hello *world*")
        XCTAssertTrue(html.contains("<em>world</em>"))
    }

    func testItalicWithUnderscores() {
        let html = renderer.convertToHTML("Hello _world_")
        XCTAssertTrue(html.contains("<em>world</em>"))
    }

    func testStrikethrough() {
        let html = renderer.convertToHTML("Hello ~~world~~")
        XCTAssertTrue(html.contains("<del>world</del>"))
    }

    func testInlineCode() {
        let html = renderer.convertToHTML("Use `print()` function")
        XCTAssertTrue(html.contains("<code>print()</code>"))
    }

    func testCombinedFormatting() {
        let html = renderer.convertToHTML("**bold** and *italic* and `code`")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
    }

    func testNestedBoldItalic() {
        let html = renderer.convertToHTML("**bold *italic* bold**")
        XCTAssertTrue(html.contains("<strong>bold <em>italic</em> bold</strong>"))
    }

    func testBoldItalicCombined() {
        let html = renderer.convertToHTML("***bold italic***")
        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("<em>"))
        XCTAssertTrue(html.contains("bold italic"))
    }

    func testItalicInsideBold() {
        let html = renderer.convertToHTML("**check the *docs* first**")
        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("<em>docs</em>"))
    }

    // MARK: - Links and Images

    func testLink() {
        let html = renderer.convertToHTML("[Google](https://google.com)")
        XCTAssertTrue(html.contains("<a href=\"https://google.com\">Google</a>"))
    }

    func testImage() {
        let html = renderer.convertToHTML("![Alt text](image.png)")
        XCTAssertTrue(html.contains("<img src=\"image.png\" alt=\"Alt text\">"))
    }

    func testLinkWithFormattedText() {
        let html = renderer.convertToHTML("[**Bold link**](https://example.com)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\"><strong>Bold link</strong></a>"))
    }

    // MARK: - Unordered Lists

    func testUnorderedListWithDash() {
        let html = renderer.convertToHTML("- Item 1\n- Item 2\n- Item 3")
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>Item 1</li>"))
        XCTAssertTrue(html.contains("<li>Item 2</li>"))
        XCTAssertTrue(html.contains("<li>Item 3</li>"))
        XCTAssertTrue(html.contains("</ul>"))
    }

    func testUnorderedListWithAsterisk() {
        let html = renderer.convertToHTML("* Item 1\n* Item 2")
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>Item 1</li>"))
        XCTAssertTrue(html.contains("<li>Item 2</li>"))
    }

    func testUnorderedListWithPlus() {
        let html = renderer.convertToHTML("+ Item 1\n+ Item 2")
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>Item 1</li>"))
    }

    func testTaskListUnchecked() {
        let html = renderer.convertToHTML("- [ ] Todo item")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled>"))
        XCTAssertTrue(html.contains("Todo item"))
    }

    func testTaskListChecked() {
        let html = renderer.convertToHTML("- [x] Done item")
        XCTAssertTrue(html.contains("<input type=\"checkbox\" checked disabled>"))
        XCTAssertTrue(html.contains("Done item"))
    }

    // MARK: - Ordered Lists

    func testOrderedList() {
        let html = renderer.convertToHTML("1. First\n2. Second\n3. Third")
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>First</li>"))
        XCTAssertTrue(html.contains("<li>Second</li>"))
        XCTAssertTrue(html.contains("<li>Third</li>"))
        XCTAssertTrue(html.contains("</ol>"))
    }

    func testOrderedListStartingAtDifferentNumber() {
        let html = renderer.convertToHTML("5. Fifth\n6. Sixth")
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>Fifth</li>"))
    }

    // MARK: - Code Blocks

    func testFencedCodeBlock() {
        let markdown = "```\ncode here\n```"
        let html = renderer.convertToHTML(markdown)
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("code here"))
        XCTAssertTrue(html.contains("</code></pre>"))
    }

    func testFencedCodeBlockWithLanguage() {
        let markdown = "```swift\nlet x = 1\n```"
        let html = renderer.convertToHTML(markdown)
        XCTAssertTrue(html.contains("<code class=\"language-swift\">"))
        XCTAssertTrue(html.contains("let x = 1"))
    }

    func testCodeBlockPreservesNewlines() {
        let markdown = "```\nline1\nline2\nline3\n```"
        let html = renderer.convertToHTML(markdown)
        XCTAssertTrue(html.contains("line1\nline2\nline3"))
    }

    func testCodeBlockEscapesHTML() {
        let markdown = "```\n<div>test</div>\n```"
        let html = renderer.convertToHTML(markdown)
        XCTAssertTrue(html.contains("&lt;div&gt;"))
    }

    // MARK: - Blockquotes

    func testSimpleBlockquote() {
        let html = renderer.convertToHTML("> This is a quote")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("This is a quote"))
        XCTAssertTrue(html.contains("</blockquote>"))
    }

    func testMultilineBlockquote() {
        let html = renderer.convertToHTML("> Line 1\n> Line 2")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("Line 1"))
        XCTAssertTrue(html.contains("Line 2"))
    }

    func testNestedBlockquote() {
        let html = renderer.convertToHTML("> Outer\n> > Inner")
        XCTAssertTrue(html.contains("<blockquote>"))
    }

    // MARK: - Tables

    func testSimpleTable() {
        let markdown = """
        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |
        """
        let html = renderer.convertToHTML(markdown)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<thead>"))
        XCTAssertTrue(html.contains("<th>Header 1</th>"))
        XCTAssertTrue(html.contains("<th>Header 2</th>"))
        XCTAssertTrue(html.contains("<tbody>"))
        XCTAssertTrue(html.contains("<td>Cell 1</td>"))
        XCTAssertTrue(html.contains("<td>Cell 2</td>"))
        XCTAssertTrue(html.contains("</table>"))
    }

    func testTableWithAlignment() {
        let markdown = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | L    | C      | R     |
        """
        let html = renderer.convertToHTML(markdown)
        XCTAssertTrue(html.contains("text-align: left"))
        XCTAssertTrue(html.contains("text-align: center"))
        XCTAssertTrue(html.contains("text-align: right"))
    }

    // MARK: - Horizontal Rules

    func testHorizontalRuleWithDashes() {
        let html = renderer.convertToHTML("---")
        XCTAssertTrue(html.contains("<hr>"))
    }

    func testHorizontalRuleWithAsterisks() {
        let html = renderer.convertToHTML("***")
        XCTAssertTrue(html.contains("<hr>"))
    }

    func testHorizontalRuleWithUnderscores() {
        let html = renderer.convertToHTML("___")
        XCTAssertTrue(html.contains("<hr>"))
    }

    func testHorizontalRuleWithSpaces() {
        // "- - -" and "* * *" are treated as list items
        // Underscores with spaces work as horizontal rule
        let html = renderer.convertToHTML("_ _ _")
        XCTAssertTrue(html.contains("<hr>"))
    }

    // MARK: - HTML Escaping

    func testHTMLEscaping() {
        let html = renderer.convertToHTML("Use <div> and & symbols")
        XCTAssertTrue(html.contains("&lt;div&gt;"))
        XCTAssertTrue(html.contains("&amp;"))
    }

    func testScriptTagEscaping() {
        let html = renderer.convertToHTML("<script>alert('xss')</script>")
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    // MARK: - Thinking Blocks

    func testThinkingBlock() {
        let html = renderer.render(markdown: "<thinking>Internal thoughts</thinking>", css: "")
        XCTAssertTrue(html.contains("class=\"thinking-block\""))
        XCTAssertTrue(html.contains("Internal thoughts"))
    }

    func testThinkBlock() {
        let html = renderer.render(markdown: "<think>Internal thoughts</think>", css: "")
        XCTAssertTrue(html.contains("class=\"thinking-block\""))
    }

    func testThinkingBlockWithMarkdown() {
        let html = renderer.render(markdown: "<thinking>**Bold** inside thinking</thinking>", css: "")
        XCTAssertTrue(html.contains("<strong>Bold</strong>"))
    }

    // MARK: - Full Document

    func testRenderProducesFullHTML() {
        let html = renderer.render(markdown: "# Test", css: "body { color: red; }")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<html>"))
        XCTAssertTrue(html.contains("<head>"))
        XCTAssertTrue(html.contains("<style>"))
        XCTAssertTrue(html.contains("body { color: red; }"))
        XCTAssertTrue(html.contains("<body>"))
        XCTAssertTrue(html.contains("<h1>Test</h1>"))
    }

    // MARK: - Edge Cases

    func testEmptyInput() {
        let html = renderer.convertToHTML("")
        XCTAssertEqual(html, "")
    }

    func testOnlyWhitespace() {
        let html = renderer.convertToHTML("   \n\n   ")
        XCTAssertEqual(html, "")
    }

    func testHashWithoutSpace() {
        let html = renderer.convertToHTML("#NotAHeader")
        // The renderer treats this as a header (space not required)
        XCTAssertTrue(html.contains("<h1>NotAHeader</h1>"))
    }

    func testListItemWithoutSpace() {
        let html = renderer.convertToHTML("-NotAList")
        // Should not be treated as list since no space after -
        XCTAssertFalse(html.contains("<ul>"))
    }

    func testComplexDocument() {
        let markdown = """
        # Title

        This is a paragraph with **bold** and *italic*.

        ## Lists

        - Item 1
        - Item 2

        1. First
        2. Second

        ## Code

        ```swift
        let x = 1
        ```

        > A quote

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let html = renderer.convertToHTML(markdown)

        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<pre><code"))
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("<table>"))
    }
}
