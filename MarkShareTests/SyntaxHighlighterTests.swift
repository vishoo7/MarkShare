import XCTest
@testable import MarkShare

final class SyntaxHighlighterTests: XCTestCase {

    // MARK: - Language Detection

    func testCanonicalLanguageLowercasesAndTrims() {
        XCTAssertEqual(SyntaxHighlighter.canonicalLanguage("  Swift  "), "swift")
    }

    func testCanonicalLanguageTakesFirstToken() {
        XCTAssertEqual(SyntaxHighlighter.canonicalLanguage("python showLineNumbers"), "python")
    }

    func testCanonicalLanguageStripsUnsafeCharacters() {
        // The value lands in a class attribute, so quotes and brackets must not survive
        let language = SyntaxHighlighter.canonicalLanguage("\"><script>")
        XCTAssertEqual(language, "script")
    }

    func testCanonicalLanguageIsNilWhenEmpty() {
        XCTAssertNil(SyntaxHighlighter.canonicalLanguage("   "))
    }

    func testUnknownLanguageIsNotHighlighted() {
        XCTAssertNil(SyntaxHighlighter.highlight("some code", language: "brainfuck"))
    }

    // MARK: - Tokens

    func testSwiftKeywordsAndTypes() {
        let html = SyntaxHighlighter.highlight("let name: String = value", language: "swift")
        XCTAssertEqual(html?.contains("<span class=\"tok-kw\">let</span>"), true)
        XCTAssertEqual(html?.contains("<span class=\"tok-typ\">String</span>"), true)
    }

    func testSwiftLineComment() {
        let html = SyntaxHighlighter.highlight("let x = 1 // trailing note", language: "swift")
        XCTAssertEqual(html?.contains("<span class=\"tok-com\">// trailing note</span>"), true)
    }

    func testBlockComment() {
        let html = SyntaxHighlighter.highlight("/* note */ let x = 1", language: "swift")
        XCTAssertEqual(html?.contains("<span class=\"tok-com\">/* note */</span>"), true)
    }

    func testStringLiteral() {
        let html = SyntaxHighlighter.highlight("let s = \"hello\"", language: "swift")
        XCTAssertEqual(html?.contains("<span class=\"tok-str\">&quot;hello&quot;</span>"), true)
    }

    func testNumberLiteral() {
        let html = SyntaxHighlighter.highlight("let n = 3.14", language: "swift")
        XCTAssertEqual(html?.contains("<span class=\"tok-num\">3.14</span>"), true)
    }

    func testFunctionCall() {
        let html = SyntaxHighlighter.highlight("render(input)", language: "swift")
        XCTAssertEqual(html?.contains("<span class=\"tok-fn\">render</span>"), true)
    }

    func testPythonTripleQuotedString() {
        let html = SyntaxHighlighter.highlight("\"\"\"doc\nstring\"\"\"", language: "python")
        XCTAssertEqual(html?.contains("<span class=\"tok-str\">&quot;&quot;&quot;doc\nstring&quot;&quot;&quot;</span>"), true)
    }

    func testJSONKeysAreDistinctFromStringValues() {
        let html = SyntaxHighlighter.highlight("{\"theme\": \"dark\"}", language: "json")
        XCTAssertEqual(html?.contains("<span class=\"tok-key\">&quot;theme&quot;</span>"), true)
        XCTAssertEqual(html?.contains("<span class=\"tok-str\">&quot;dark&quot;</span>"), true)
    }

    func testShellVariable() {
        let html = SyntaxHighlighter.highlight("echo ${HOME}", language: "bash")
        XCTAssertEqual(html?.contains("<span class=\"tok-typ\">${HOME}</span>"), true)
    }

    func testSQLKeywordsAreCaseInsensitive() {
        let html = SyntaxHighlighter.highlight("SELECT * from users", language: "sql")
        XCTAssertEqual(html?.contains("<span class=\"tok-kw\">SELECT</span>"), true)
        XCTAssertEqual(html?.contains("<span class=\"tok-kw\">from</span>"), true)
    }

    func testUnterminatedStringStopsAtNewline() {
        let html = SyntaxHighlighter.highlight("let a = \"oops\nlet b = 1", language: "swift")
        // The second line must still be highlighted normally
        XCTAssertEqual(html?.contains("<span class=\"tok-num\">1</span>"), true)
    }

    // MARK: - Escaping

    func testHighlightedOutputIsEscaped() {
        let html = SyntaxHighlighter.highlight("if a < b && c > d {}", language: "swift")
        XCTAssertEqual(html?.contains("&lt;"), true)
        XCTAssertEqual(html?.contains("&amp;&amp;"), true)
        XCTAssertEqual(html?.contains("&gt;"), true)
    }

    func testMarkupInsideCommentsIsEscaped() {
        let html = SyntaxHighlighter.highlight("// <script>alert(1)</script>", language: "swift")
        XCTAssertEqual(html?.contains("<script>"), false)
        XCTAssertEqual(html?.contains("&lt;script&gt;"), true)
    }

    // MARK: - Renderer Integration

    func testFencedCodeBlockIsHighlighted() {
        let html = MarkdownRenderer().convertToHTML("```swift\nlet x = 1\n```")
        XCTAssertTrue(html.contains("class=\"language-swift\""))
        XCTAssertTrue(html.contains("<span class=\"tok-kw\">let</span>"))
    }

    func testFencedCodeBlockWithoutLanguageIsPlain() {
        let html = MarkdownRenderer().convertToHTML("```\na < b\n```")
        XCTAssertTrue(html.contains("<pre><code>a &lt; b</code></pre>"))
        XCTAssertFalse(html.contains("tok-"))
    }

    func testUnknownFenceLanguageStillEscapes() {
        let html = MarkdownRenderer().convertToHTML("```brainfuck\na < b\n```")
        XCTAssertTrue(html.contains("class=\"language-brainfuck\""))
        XCTAssertTrue(html.contains("a &lt; b"))
    }

    func testFenceLanguageCannotEscapeTheClassAttribute() {
        let html = MarkdownRenderer().convertToHTML("```\"><script>\ncode\n```")
        XCTAssertFalse(html.contains("<script>"))
    }
}
