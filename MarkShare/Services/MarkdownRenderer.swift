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
        var lines = markdown.components(separatedBy: "\n")
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

            // Unordered lists
            if isUnorderedListItem(line) {
                let (listHTML, newIndex) = parseUnorderedList(lines: lines, startIndex: index)
                html += listHTML
                index = newIndex
                continue
            }

            // Ordered lists
            if isOrderedListItem(line) {
                let (listHTML, newIndex) = parseOrderedList(lines: lines, startIndex: index)
                html += listHTML
                index = newIndex
                continue
            }

            // Headers
            if let headerHTML = parseHeader(line) {
                html += headerHTML + "\n"
                index += 1
                continue
            }

            // Horizontal rule
            if isHorizontalRule(line) {
                html += "<hr>\n"
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
        let language = String(openingLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)

        var codeLines: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("```") {
                index += 1
                break
            }
            codeLines.append(escapeHTML(line))
            index += 1
        }

        let code = codeLines.joined(separator: "\n")
        let languageAttr = language.isEmpty ? "" : " class=\"language-\(language)\""
        return ("<pre><code\(languageAttr)>\(code)</code></pre>\n", index)
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

    private func parseUnorderedList(lines: [String], startIndex: Int) -> (String, Int) {
        var items: [String] = []
        var index = startIndex
        var currentItem: [String] = []

        while index < lines.count {
            let line = lines[index]

            if isUnorderedListItem(line) {
                if !currentItem.isEmpty {
                    items.append(currentItem.joined(separator: "\n"))
                }
                currentItem = [extractListItemContent(line)]
                index += 1
            } else if line.hasPrefix("  ") || line.hasPrefix("\t") {
                // Continuation of current item
                currentItem.append(line.trimmingCharacters(in: .whitespaces))
                index += 1
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                if index < lines.count && !isUnorderedListItem(lines[index]) && !lines[index].hasPrefix("  ") {
                    break
                }
            } else {
                break
            }
        }

        if !currentItem.isEmpty {
            items.append(currentItem.joined(separator: "\n"))
        }

        var html = "<ul>\n"
        for item in items {
            let (isTask, isChecked, content) = parseTaskListItem(item)
            if isTask {
                let checkbox = isChecked
                    ? "<input type=\"checkbox\" checked disabled>"
                    : "<input type=\"checkbox\" disabled>"
                html += "<li class=\"task-list-item\">\(checkbox) \(parseInline(content))</li>\n"
            } else {
                html += "<li>\(parseInline(item))</li>\n"
            }
        }
        html += "</ul>\n"

        return (html, index)
    }

    private func parseOrderedList(lines: [String], startIndex: Int) -> (String, Int) {
        var items: [String] = []
        var index = startIndex
        var currentItem: [String] = []

        while index < lines.count {
            let line = lines[index]

            if isOrderedListItem(line) {
                if !currentItem.isEmpty {
                    items.append(currentItem.joined(separator: "\n"))
                }
                currentItem = [extractOrderedListItemContent(line)]
                index += 1
            } else if line.hasPrefix("  ") || line.hasPrefix("\t") {
                currentItem.append(line.trimmingCharacters(in: .whitespaces))
                index += 1
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                if index < lines.count && !isOrderedListItem(lines[index]) && !lines[index].hasPrefix("  ") {
                    break
                }
            } else {
                break
            }
        }

        if !currentItem.isEmpty {
            items.append(currentItem.joined(separator: "\n"))
        }

        var html = "<ol>\n"
        for item in items {
            html += "<li>\(parseInline(item))</li>\n"
        }
        html += "</ol>\n"

        return (html, index)
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
               isUnorderedListItem(line) ||
               isOrderedListItem(line) ||
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

    private func isUnorderedListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")
    }

    private func isOrderedListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let pattern = "^\\d+\\. "
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private func extractListItemContent(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return String(trimmed.dropFirst(2))
        }
        return trimmed
    }

    private func extractOrderedListItemContent(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: "^\\d+\\. ", options: .regularExpression) {
            return String(trimmed[range.upperBound...])
        }
        return trimmed
    }

    private func parseTaskListItem(_ content: String) -> (isTask: Bool, isChecked: Bool, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") {
            return (true, true, String(trimmed.dropFirst(4)))
        }
        if trimmed.hasPrefix("[ ] ") {
            return (true, false, String(trimmed.dropFirst(4)))
        }
        return (false, false, content)
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
