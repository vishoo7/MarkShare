import Foundation

/// Pure Swift Markdown to HTML renderer
/// Supports CommonMark basics and GFM extensions
struct MarkdownRenderer {

    /// Converts markdown text to full HTML document with theme CSS
    func render(markdown: String, css: String) -> String {
        let (processedMarkdown, thinkingBlocks) = extractThinkingBlocks(markdown)
        var bodyHTML = convertToHTML(processedMarkdown)
        bodyHTML = restoreThinkingBlocks(bodyHTML, blocks: thinkingBlocks)
        return wrapInHTMLDocument(body: bodyHTML, css: css)
    }

    /// Converts conversation entries to full HTML document with theme CSS
    func renderConversation(entries: [ConversationEntry], css: String) -> String {
        var bodyHTML = "<div class=\"conversation\">\n"

        for entry in entries {
            let roleClass = entry.role.rawValue.lowercased()
            let (processedContent, thinkingBlocks) = extractThinkingBlocks(entry.content)
            var contentHTML = convertToHTML(processedContent)
            contentHTML = restoreThinkingBlocks(contentHTML, blocks: thinkingBlocks)

            bodyHTML += """
              <div class="conversation-entry \(roleClass)">
                <div class="role-label">\(entry.role.rawValue)</div>
                <div class="message-content">
            \(contentHTML)
                </div>
              </div>

            """
        }

        bodyHTML += "</div>"
        return wrapInHTMLDocument(body: bodyHTML, css: css)
    }

    // MARK: - Thinking Block Processing

    /// Extracts <thinking> and <think> blocks, replacing with placeholders
    private func extractThinkingBlocks(_ markdown: String) -> (String, [(id: String, content: String)]) {
        let pattern = #"<think(?:ing)?>([\s\S]*?)</think(?:ing)?>"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (markdown, [])
        }

        var result = markdown
        var blocks: [(id: String, content: String)] = []
        let nsRange = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, options: [], range: nsRange)

        // Process matches in reverse order to preserve indices
        for (index, match) in matches.reversed().enumerated() {
            guard let fullRange = Range(match.range, in: result),
                  let contentRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let thinkingContent = String(result[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let blockIndex = matches.count - 1 - index
            let placeholderId = "XTHINKINGBLOCKX\(blockIndex)XTHINKINGBLOCKX"

            blocks.insert((id: placeholderId, content: thinkingContent), at: 0)
            result.replaceSubrange(fullRange, with: placeholderId)
        }

        return (result, blocks)
    }

    /// Restores thinking blocks from placeholders with rendered HTML
    private func restoreThinkingBlocks(_ html: String, blocks: [(id: String, content: String)]) -> String {
        var result = html

        for block in blocks {
            // The placeholder might be wrapped in <p> tags
            let placeholderInParagraph = "<p>\(block.id)</p>"
            let innerHTML = convertToHTML(block.content)

            let replacement = """
            <div class="thinking-block">
              <div class="thinking-content">
            \(innerHTML)
              </div>
            </div>
            """

            // Try replacing with <p> wrapper first, then without
            if result.contains(placeholderInParagraph) {
                result = result.replacingOccurrences(of: placeholderInParagraph, with: replacement)
            } else {
                result = result.replacingOccurrences(of: block.id, with: replacement)
            }
        }

        return result
    }

    /// Converts markdown text to HTML body content
    func convertToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html = ""
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Fenced code blocks
            if line.hasPrefix("```") {
                let (codeHTML, newIndex) = parseFencedCodeBlock(lines: lines, startIndex: index)
                html += codeHTML
                index = newIndex
                continue
            }

            // Tables
            if index + 1 < lines.count && isTableDelimiter(lines[index + 1]) {
                let (tableHTML, newIndex) = parseTable(lines: lines, startIndex: index)
                html += tableHTML
                index = newIndex
                continue
            }

            // Blockquotes
            if line.hasPrefix(">") {
                let (blockquoteHTML, newIndex) = parseBlockquote(lines: lines, startIndex: index)
                html += blockquoteHTML
                index = newIndex
                continue
            }

            // Horizontal rule — checked before lists so "* * *" isn't read as a bullet
            if isHorizontalRule(line) {
                html += "<hr>\n"
                index += 1
                continue
            }

            // Lists (ordered, unordered, task — nested to any depth)
            if listMarker(line) != nil {
                let (listHTML, newIndex) = parseList(lines: lines, startIndex: index)
                html += listHTML
                index = max(newIndex, index + 1)
                continue
            }

            // Headers
            if let headerHTML = parseHeader(line) {
                html += headerHTML + "\n"
                index += 1
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            // Paragraph
            let (paragraphHTML, newIndex) = parseParagraph(lines: lines, startIndex: index)
            html += paragraphHTML
            index = newIndex
        }

        return html
    }

    // MARK: - Block Parsers

    private func parseHeader(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        var level = 0
        for char in trimmed {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }

        guard level >= 1, level <= 6 else { return nil }

        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: level)
        var content = String(trimmed[startIndex...]).trimmingCharacters(in: .whitespaces)

        // Remove trailing hashes
        while content.hasSuffix("#") {
            content = String(content.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        let inlineHTML = parseInline(content)
        return "<h\(level)>\(inlineHTML)</h\(level)>"
    }

    private func parseFencedCodeBlock(lines: [String], startIndex: Int) -> (String, Int) {
        let openingLine = lines[startIndex]
        let infoString = String(openingLine.dropFirst(3))
        let language = SyntaxHighlighter.canonicalLanguage(infoString)

        var codeLines: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("```") {
                index += 1
                break
            }
            codeLines.append(line)
            index += 1
        }

        let code = codeLines.joined(separator: "\n")
        let languageAttr = language.map { " class=\"language-\($0)\"" } ?? ""
        let body = language.flatMap { SyntaxHighlighter.highlight(code, language: $0) }
            ?? escapeHTML(code)

        return ("<pre><code\(languageAttr)>\(body)</code></pre>\n", index)
    }

    private func parseBlockquote(lines: [String], startIndex: Int) -> (String, Int) {
        var quotedLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix(">") {
                var content = String(line.dropFirst())
                if content.hasPrefix(" ") {
                    content = String(content.dropFirst())
                }
                quotedLines.append(content)
                index += 1
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty && !quotedLines.isEmpty {
                // Empty line might continue blockquote
                if index + 1 < lines.count && lines[index + 1].hasPrefix(">") {
                    quotedLines.append("")
                    index += 1
                } else {
                    break
                }
            } else {
                break
            }
        }

        let innerMarkdown = quotedLines.joined(separator: "\n")
        let innerHTML = convertToHTML(innerMarkdown)
        return ("<blockquote>\(innerHTML)</blockquote>\n", index)
    }

    /// Parses a list block starting at `startIndex`.
    ///
    /// Each item's lines are collected and dedented back to column zero, then run through
    /// `convertToHTML` recursively — so nested lists, multi-paragraph items, and fenced code
    /// inside a list item all work without special-casing.
    private func parseList(lines: [String], startIndex: Int) -> (String, Int) {
        guard let first = listMarker(lines[startIndex]) else {
            return ("", startIndex + 1)
        }

        let ordered = first.ordered
        let baseIndent = first.indent

        var items: [[String]] = []
        var currentItem: [String] = []
        var contentIndent = first.contentIndent
        var index = startIndex
        var blankRun = 0

        while index < lines.count {
            let line = lines[index]

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blankRun += 1
                index += 1
                continue
            }

            let indent = indentWidth(line)
            let marker = listMarker(line)

            // A marker at or left of the base indent is either a sibling item or the end of this list
            if let marker = marker, marker.indent <= baseIndent {
                if marker.indent < baseIndent { break }
                if marker.ordered != ordered { break }
                if blankRun >= 2 { break }

                if !currentItem.isEmpty {
                    items.append(currentItem)
                }
                currentItem = [marker.content]
                contentIndent = marker.contentIndent
                blankRun = 0
                index += 1
                continue
            }

            // Anything indented past the base belongs to the current item: a nested list,
            // a continuation paragraph, an indented code fence, etc.
            if indent > baseIndent && !currentItem.isEmpty {
                if blankRun > 0 { currentItem.append("") }
                currentItem.append(dedent(line, by: min(contentIndent, indent)))
                blankRun = 0
                index += 1
                continue
            }

            // Lazy continuation: unindented prose on the line right after item text
            if blankRun == 0 && !currentItem.isEmpty && marker == nil && !startsNewBlock(line) {
                currentItem.append(line.trimmingCharacters(in: .whitespaces))
                index += 1
                continue
            }

            break
        }

        if !currentItem.isEmpty {
            items.append(currentItem)
        }

        var html: String
        if ordered {
            let start = first.start ?? 1
            html = start == 1 ? "<ol>\n" : "<ol start=\"\(start)\">\n"
        } else {
            html = "<ul>\n"
        }

        for item in items {
            let (isTask, isChecked, itemLines) = parseTaskListItem(item)
            let inner = unwrapFirstParagraph(convertToHTML(itemLines.joined(separator: "\n")))

            if isTask {
                let checkbox = isChecked
                    ? "<input type=\"checkbox\" checked disabled>"
                    : "<input type=\"checkbox\" disabled>"
                html += "<li class=\"task-list-item\">\(checkbox) \(inner)</li>\n"
            } else {
                html += "<li>\(inner)</li>\n"
            }
        }

        html += ordered ? "</ol>\n" : "</ul>\n"

        return (html, index)
    }

    /// A list item's leading `<p>` is stripped so simple items render tight
    private func unwrapFirstParagraph(_ html: String) -> String {
        var result = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.hasPrefix("<p>"), let close = result.range(of: "</p>") else {
            return result
        }
        result.replaceSubrange(close, with: "")
        result.removeFirst(3)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseTable(lines: [String], startIndex: Int) -> (String, Int) {
        guard startIndex + 1 < lines.count else {
            return ("", startIndex)
        }

        let headerLine = lines[startIndex]
        let delimiterLine = lines[startIndex + 1]

        let headers = parseTableRow(headerLine)
        let alignments = parseTableAlignments(delimiterLine)

        var html = "<table>\n<thead>\n<tr>\n"
        for (i, header) in headers.enumerated() {
            let align = i < alignments.count ? alignments[i] : ""
            let alignAttr = align.isEmpty ? "" : " style=\"text-align: \(align)\""
            html += "<th\(alignAttr)>\(parseInline(header))</th>\n"
        }
        html += "</tr>\n</thead>\n<tbody>\n"

        var index = startIndex + 2
        while index < lines.count {
            let line = lines[index]
            if line.contains("|") {
                let cells = parseTableRow(line)
                html += "<tr>\n"
                for (i, cell) in cells.enumerated() {
                    let align = i < alignments.count ? alignments[i] : ""
                    let alignAttr = align.isEmpty ? "" : " style=\"text-align: \(align)\""
                    html += "<td\(alignAttr)>\(parseInline(cell))</td>\n"
                }
                html += "</tr>\n"
                index += 1
            } else {
                break
            }
        }

        html += "</tbody>\n</table>\n"
        return (html, index)
    }

    private func parseParagraph(lines: [String], startIndex: Int) -> (String, Int) {
        var paragraphLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty ||
               line.hasPrefix("#") ||
               line.hasPrefix("```") ||
               line.hasPrefix(">") ||
               listMarker(line) != nil ||
               isHorizontalRule(line) ||
               (index + 1 < lines.count && isTableDelimiter(lines[index + 1])) {
                break
            }

            paragraphLines.append(trimmed)
            index += 1
        }

        if paragraphLines.isEmpty {
            return ("", index)
        }

        let content = paragraphLines.joined(separator: " ")
        return ("<p>\(parseInline(content))</p>\n", index)
    }

    // MARK: - Inline Parser

    private func parseInline(_ text: String) -> String {
        var result = escapeHTML(text)

        // Images: ![alt](url) — with URL sanitization
        if let imageRegex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)") {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = imageRegex.matches(in: result, range: nsRange)
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let altRange = Range(match.range(at: 1), in: result),
                      let urlRange = Range(match.range(at: 2), in: result) else { continue }
                let alt = String(result[altRange])
                let url = sanitizeURL(String(result[urlRange]))
                result.replaceSubrange(fullRange, with: "<img src=\"\(url)\" alt=\"\(alt)\">")
            }
        }

        // Links: [text](url) — with URL sanitization
        if let linkRegex = try? NSRegularExpression(pattern: "\\[([^\\]]*)\\]\\(([^)]+)\\)") {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = linkRegex.matches(in: result, range: nsRange)
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let textRange = Range(match.range(at: 1), in: result),
                      let urlRange = Range(match.range(at: 2), in: result) else { continue }
                let linkText = String(result[textRange])
                let url = sanitizeURL(String(result[urlRange]))
                result.replaceSubrange(fullRange, with: "<a href=\"\(url)\">\(linkText)</a>")
            }
        }

        // Bold: **text** or __text__
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "__(.+?)__",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic: *text* or _text_
        result = result.replacingOccurrences(
            of: "\\*(.+?)\\*",
            with: "<em>$1</em>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?<![a-zA-Z0-9])_(.+?)_(?![a-zA-Z0-9])",
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Strikethrough: ~~text~~
        result = result.replacingOccurrences(
            of: "~~([^~]+)~~",
            with: "<del>$1</del>",
            options: .regularExpression
        )

        // Inline code: `code`
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Line breaks: two spaces at end of line
        result = result.replacingOccurrences(
            of: "  $",
            with: "<br>",
            options: .regularExpression
        )

        return result
    }

    // MARK: - Helpers

    /// A recognized list bullet or number at the start of a line
    private struct ListMarker {
        let ordered: Bool
        /// Width of the leading whitespace
        let indent: Int
        /// Column where the item's content starts — continuation lines are dedented to this
        let contentIndent: Int
        /// The number for ordered items, used for the `start` attribute
        let start: Int?
        /// Text following the marker
        let content: String
    }

    /// Recognizes `-`/`*`/`+` bullets and `1.`/`1)` numbers, at any indentation
    private func listMarker(_ line: String) -> ListMarker? {
        let indent = indentWidth(line)
        let body = dedent(line, by: indent)
        guard let firstChar = body.first else { return nil }

        var markerWidth = 0
        var ordered = false
        var start: Int?

        if firstChar == "-" || firstChar == "*" || firstChar == "+" {
            markerWidth = 1
        } else if firstChar.isNumber {
            var digits = ""
            var cursor = body.startIndex
            while cursor < body.endIndex, body[cursor].isNumber, digits.count < 9 {
                digits.append(body[cursor])
                cursor = body.index(after: cursor)
            }
            guard cursor < body.endIndex, body[cursor] == "." || body[cursor] == ")" else {
                return nil
            }
            ordered = true
            start = Int(digits)
            markerWidth = digits.count + 1
        } else {
            return nil
        }

        let rest = String(body.dropFirst(markerWidth))
        // A marker must be followed by whitespace, otherwise "*emphasis*" looks like a bullet
        guard rest.isEmpty || rest.hasPrefix(" ") || rest.hasPrefix("\t") else { return nil }

        let spacing = min(indentWidth(rest), 4)
        return ListMarker(
            ordered: ordered,
            indent: indent,
            contentIndent: indent + markerWidth + max(spacing, 1),
            start: start,
            content: dedent(rest, by: spacing)
        )
    }

    /// Splits a `[x]` / `[ ]` prefix off a list item's first line
    private func parseTaskListItem(_ lines: [String]) -> (isTask: Bool, isChecked: Bool, lines: [String]) {
        guard let first = lines.first else { return (false, false, lines) }
        let trimmed = first.trimmingCharacters(in: .whitespaces)

        let checked: Bool
        if trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") {
            checked = true
        } else if trimmed.hasPrefix("[ ] ") {
            checked = false
        } else {
            return (false, false, lines)
        }

        var result = lines
        result[0] = String(trimmed.dropFirst(4))
        return (true, checked, result)
    }

    /// Leading whitespace width, counting a tab as four columns
    private func indentWidth(_ line: String) -> Int {
        var width = 0
        for char in line {
            if char == " " {
                width += 1
            } else if char == "\t" {
                width += 4
            } else {
                break
            }
        }
        return width
    }

    /// Removes up to `amount` columns of leading whitespace
    private func dedent(_ line: String, by amount: Int) -> String {
        var remaining = amount
        var cursor = line.startIndex

        while remaining > 0, cursor < line.endIndex {
            let char = line[cursor]
            if char == " " {
                remaining -= 1
            } else if char == "\t" {
                remaining -= 4
            } else {
                break
            }
            cursor = line.index(after: cursor)
        }

        return String(line[cursor...])
    }

    /// Whether a line opens a block that a lazy list continuation must not swallow
    private func startsNewBlock(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("#")
            || trimmed.hasPrefix("```")
            || trimmed.hasPrefix(">")
            || isHorizontalRule(line)
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 { return false }

        let patterns = ["---", "***", "___"]
        for pattern in patterns {
            guard let char = pattern.first else { continue }
            let filtered = trimmed.filter { $0 == char || $0 == " " }
            if filtered == trimmed && trimmed.filter({ $0 == char }).count >= 3 {
                return true
            }
        }
        return false
    }

    private func isTableDelimiter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }

        // Set of characters that act as dashes in table delimiters
        let dashChars = CharacterSet(charactersIn: "-\u{2010}\u{2011}\u{2012}\u{2013}\u{2014}\u{2015}\u{2212}\u{2E3A}\u{2E3B}\u{FE58}\u{FE63}\u{FF0D}")

        let cells = trimmed.components(separatedBy: "|").filter { !$0.isEmpty }
        for cell in cells {
            let cellTrimmed = cell.trimmingCharacters(in: .whitespaces)

            // Remove optional colons at start/end
            var content = cellTrimmed
            if content.hasPrefix(":") { content = String(content.dropFirst()) }
            if content.hasSuffix(":") { content = String(content.dropLast()) }

            // Check if remaining content is all dash-like characters
            guard !content.isEmpty else { return false }
            for scalar in content.unicodeScalars {
                if !dashChars.contains(scalar) {
                    return false
                }
            }
        }
        return !cells.isEmpty
    }

    private func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }

        return trimmed.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private func parseTableAlignments(_ line: String) -> [String] {
        let cells = parseTableRow(line)
        return cells.map { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let hasLeftColon = trimmed.hasPrefix(":")
            let hasRightColon = trimmed.hasSuffix(":")

            if hasLeftColon && hasRightColon {
                return "center"
            } else if hasRightColon {
                return "right"
            } else if hasLeftColon {
                return "left"
            }
            return ""
        }
    }

    private func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }

    /// Validates URL scheme to prevent javascript: and other dangerous protocols
    private func sanitizeURL(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ||
           trimmed.hasPrefix("mailto:") || trimmed.hasPrefix("data:") ||
           trimmed.hasPrefix("#") || !trimmed.contains(":") {
            return url
        }
        return "#"
    }

    private func wrapInHTMLDocument(body: String, css: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            \(css)
            </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}
