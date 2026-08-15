import Foundation

/// Pure Swift syntax highlighter for fenced code blocks.
///
/// Scans code character by character and wraps tokens in `tok-*` spans that the theme CSS
/// colors. Unrecognized languages return `nil` so the caller can fall back to plain escaped
/// text rather than guessing.
struct SyntaxHighlighter {

    /// Token classes. Raw values are the CSS class names defined in every theme file.
    private enum TokenKind: String {
        case comment = "tok-com"
        case string = "tok-str"
        case number = "tok-num"
        case keyword = "tok-kw"
        case type = "tok-typ"
        case function = "tok-fn"
        case key = "tok-key"
    }

    private struct Grammar {
        var lineComments: [String] = []
        var blockComment: (open: String, close: String)?
        var stringDelimiters: [String] = ["\"", "'"]
        /// Delimiters that may span newlines, tried before `stringDelimiters`
        var multilineStringDelimiters: [String] = []
        var escape: Character? = "\\"
        var keywords: Set<String> = []
        var types: Set<String> = []
        /// Prefixes that introduce a variable reference, e.g. `$name` in shell
        var variablePrefixes: [Character] = []
        /// Whether `name(` should be highlighted as a call
        var highlightsCalls = true
        /// Whether `"name":` should be highlighted as an object key
        var highlightsKeys = false
        /// Whether keyword matching ignores case, as in SQL
        var ignoresCase = false
    }

    // MARK: - Public API

    /// Reduces a fence's info string to a canonical, safe-to-interpolate language id.
    ///
    /// Also used for the `class="language-…"` attribute, so it strips anything that could
    /// break out of the attribute.
    static func canonicalLanguage(_ info: String) -> String? {
        let firstToken = info
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .first ?? ""

        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789+#._-")
        let cleaned = String(firstToken.lowercased().filter { allowed.contains($0) })
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Highlights `code`, returning HTML-escaped markup, or `nil` if the language is unknown.
    static func highlight(_ code: String, language: String) -> String? {
        guard let grammar = grammar(for: language) else { return nil }

        let chars = Array(code)
        let lineComments = grammar.lineComments.map { Array($0) }
        let blockOpen = grammar.blockComment.map { Array($0.open) }
        let blockClose = grammar.blockComment.map { Array($0.close) }
        let multilineStrings = grammar.multilineStringDelimiters.map { Array($0) }
        let strings = grammar.stringDelimiters.map { Array($0) }

        var output = ""
        var plain = ""
        var index = 0

        func flushPlain() {
            guard !plain.isEmpty else { return }
            output += escapeHTML(plain)
            plain = ""
        }

        func emit(_ text: String, as kind: TokenKind) {
            flushPlain()
            output += "<span class=\"\(kind.rawValue)\">\(escapeHTML(text))</span>"
        }

        func matches(_ token: [Character], at position: Int) -> Bool {
            guard position + token.count <= chars.count else { return false }
            for (offset, char) in token.enumerated() where chars[position + offset] != char {
                return false
            }
            return true
        }

        /// Next character that isn't a space or tab, not crossing into the next line's content
        func nextSignificant(from position: Int) -> Character? {
            var cursor = position
            while cursor < chars.count, chars[cursor] == " " || chars[cursor] == "\t" {
                cursor += 1
            }
            return cursor < chars.count ? chars[cursor] : nil
        }

        while index < chars.count {
            let char = chars[index]

            // Block comments
            if let open = blockOpen, let close = blockClose, matches(open, at: index) {
                let start = index
                index += open.count
                while index < chars.count, !matches(close, at: index) {
                    index += 1
                }
                index = min(index + close.count, chars.count)
                emit(String(chars[start..<index]), as: .comment)
                continue
            }

            // Line comments
            if let delimiter = lineComments.first(where: { matches($0, at: index) }) {
                let start = index
                index += delimiter.count
                while index < chars.count, chars[index] != "\n" {
                    index += 1
                }
                emit(String(chars[start..<index]), as: .comment)
                continue
            }

            // Multi-line strings (Python's triple quotes, Swift's """)
            if let delimiter = multilineStrings.first(where: { matches($0, at: index) }) {
                let start = index
                index += delimiter.count
                while index < chars.count, !matches(delimiter, at: index) {
                    if chars[index] == grammar.escape { index += 1 }
                    index += 1
                }
                index = min(index + delimiter.count, chars.count)
                emit(String(chars[start..<index]), as: .string)
                continue
            }

            // Single-line strings — stop at a newline so an unterminated quote doesn't run away
            if let delimiter = strings.first(where: { matches($0, at: index) }) {
                let start = index
                index += delimiter.count
                while index < chars.count, chars[index] != "\n", !matches(delimiter, at: index) {
                    if chars[index] == grammar.escape { index += 1 }
                    index += 1
                }
                if index < chars.count, matches(delimiter, at: index) {
                    index += delimiter.count
                }
                let text = String(chars[start..<index])
                let isKey = grammar.highlightsKeys && nextSignificant(from: index) == ":"
                emit(text, as: isKey ? .key : .string)
                continue
            }

            // Shell / PHP style variables: $name, ${name}
            if grammar.variablePrefixes.contains(char), index + 1 < chars.count {
                let start = index
                var cursor = index + 1
                let braced = chars[cursor] == "{"
                if braced { cursor += 1 }

                let nameStart = cursor
                while cursor < chars.count, isIdentifierCharacter(chars[cursor]) {
                    cursor += 1
                }

                if cursor > nameStart {
                    if braced, cursor < chars.count, chars[cursor] == "}" { cursor += 1 }
                    index = cursor
                    emit(String(chars[start..<index]), as: .type)
                    continue
                }
            }

            // Numbers
            if char.isNumber {
                let start = index
                index += 1
                while index < chars.count {
                    let digit = chars[index]
                    if digit == "." {
                        guard index + 1 < chars.count, chars[index + 1].isNumber else { break }
                        index += 1
                    } else if digit == "e" || digit == "E",
                              index + 2 < chars.count,
                              chars[index + 1] == "+" || chars[index + 1] == "-",
                              chars[index + 2].isNumber {
                        index += 2
                    } else if digit.isHexDigit || digit == "_" || "xXoObB".contains(digit) {
                        index += 1
                    } else {
                        break
                    }
                }
                emit(String(chars[start..<index]), as: .number)
                continue
            }

            // Identifiers, keywords, types, calls
            if isIdentifierStart(char) {
                let start = index
                while index < chars.count, isIdentifierCharacter(chars[index]) {
                    index += 1
                }
                let word = String(chars[start..<index])
                let lookup = grammar.ignoresCase ? word.lowercased() : word

                if grammar.keywords.contains(lookup) {
                    emit(word, as: .keyword)
                } else if grammar.types.contains(lookup) {
                    emit(word, as: .type)
                } else if grammar.highlightsCalls, nextSignificant(from: index) == "(" {
                    emit(word, as: .function)
                } else {
                    plain += word
                }
                continue
            }

            plain.append(char)
            index += 1
        }

        flushPlain()
        return output
    }

    // MARK: - Character Classes

    private static func isIdentifierStart(_ char: Character) -> Bool {
        char.isLetter || char == "_" || char == "$"
    }

    private static func isIdentifierCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_" || char == "$"
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Grammars

    private static func grammar(for language: String) -> Grammar? {
        switch language {
        case "swift":
            return Grammar(
                lineComments: ["//"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\""],
                multilineStringDelimiters: ["\"\"\""],
                keywords: [
                    "associatedtype", "async", "await", "break", "case", "catch", "class",
                    "continue", "default", "defer", "deinit", "do", "else", "enum", "extension",
                    "fallthrough", "false", "fileprivate", "final", "for", "func", "get", "guard",
                    "if", "import", "in", "indirect", "init", "inout", "internal", "is", "lazy",
                    "let", "mutating", "nil", "nonisolated", "open", "operator", "override",
                    "private", "protocol", "public", "repeat", "rethrows", "return", "self",
                    "set", "some", "static", "struct", "subscript", "super", "switch", "throw",
                    "throws", "true", "try", "typealias", "unowned", "var", "weak", "where",
                    "while", "willSet", "didSet",
                ],
                types: [
                    "Any", "AnyObject", "Array", "Bool", "Character", "Data", "Date", "Dictionary",
                    "Double", "Error", "Float", "Int", "Optional", "Result", "Self", "Set",
                    "String", "Task", "UInt", "URL", "Void",
                ]
            )

        case "javascript", "js", "jsx", "mjs", "cjs", "typescript", "ts", "tsx":
            return Grammar(
                lineComments: ["//"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\"", "'", "`"],
                keywords: [
                    "as", "async", "await", "break", "case", "catch", "class", "const",
                    "continue", "debugger", "default", "delete", "do", "else", "enum", "export",
                    "extends", "false", "finally", "for", "from", "function", "get", "if",
                    "implements", "import", "in", "instanceof", "interface", "let", "new", "null",
                    "of", "private", "protected", "public", "readonly", "return", "satisfies",
                    "static", "super", "switch", "this", "throw", "true", "try", "type", "typeof",
                    "undefined", "var", "void", "while", "yield",
                ],
                types: [
                    "Array", "Boolean", "Date", "Error", "JSON", "Map", "Math", "Number",
                    "Object", "Promise", "RegExp", "Set", "String", "Symbol", "any", "boolean",
                    "never", "number", "string", "unknown",
                ]
            )

        case "python", "py":
            return Grammar(
                lineComments: ["#"],
                stringDelimiters: ["\"", "'"],
                multilineStringDelimiters: ["\"\"\"", "'''"],
                keywords: [
                    "and", "as", "assert", "async", "await", "break", "case", "class",
                    "continue", "def", "del", "elif", "else", "except", "False", "finally",
                    "for", "from", "global", "if", "import", "in", "is", "lambda", "match",
                    "None", "nonlocal", "not", "or", "pass", "raise", "return", "self", "True",
                    "try", "while", "with", "yield",
                ],
                types: [
                    "bool", "bytes", "dict", "Exception", "float", "int", "list", "object",
                    "set", "str", "tuple", "type",
                ]
            )

        case "json", "jsonc", "json5":
            return Grammar(
                lineComments: ["//"],
                stringDelimiters: ["\""],
                keywords: ["true", "false", "null"],
                highlightsCalls: false,
                highlightsKeys: true
            )

        case "bash", "sh", "shell", "zsh", "console", "terminal":
            return Grammar(
                lineComments: ["#"],
                stringDelimiters: ["\"", "'"],
                keywords: [
                    "alias", "break", "case", "cd", "continue", "do", "done", "elif", "else",
                    "esac", "eval", "exec", "exit", "export", "fi", "for", "function", "if",
                    "in", "local", "readonly", "return", "set", "shift", "source", "then",
                    "trap", "unset", "until", "while",
                ],
                variablePrefixes: ["$"],
                highlightsCalls: false
            )

        case "go", "golang":
            return Grammar(
                lineComments: ["//"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\"", "`"],
                keywords: [
                    "break", "case", "chan", "const", "continue", "default", "defer", "else",
                    "fallthrough", "false", "for", "func", "go", "goto", "if", "import",
                    "interface", "map", "nil", "package", "range", "return", "select", "struct",
                    "switch", "true", "type", "var",
                ],
                types: [
                    "bool", "byte", "error", "float32", "float64", "int", "int32", "int64",
                    "rune", "string", "uint", "uint8",
                ]
            )

        case "rust", "rs":
            return Grammar(
                lineComments: ["//"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\""],
                keywords: [
                    "as", "async", "await", "break", "const", "continue", "crate", "dyn",
                    "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let",
                    "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self",
                    "static", "struct", "super", "trait", "true", "type", "unsafe", "use",
                    "where", "while",
                ],
                types: [
                    "bool", "char", "f32", "f64", "i32", "i64", "Option", "Result", "String",
                    "str", "u8", "u32", "u64", "usize", "Vec",
                ]
            )

        case "java", "kotlin", "kt":
            return Grammar(
                lineComments: ["//"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\"", "'"],
                multilineStringDelimiters: ["\"\"\""],
                keywords: [
                    "abstract", "as", "break", "case", "catch", "class", "companion", "const",
                    "continue", "data", "default", "do", "else", "enum", "extends", "false",
                    "final", "finally", "for", "fun", "if", "implements", "import", "in",
                    "instanceof", "interface", "internal", "is", "it", "lateinit", "native",
                    "new", "null", "object", "open", "override", "package", "private",
                    "protected", "public", "return", "static", "super", "suspend", "switch",
                    "synchronized", "this", "throw", "throws", "true", "try", "val", "var",
                    "when", "while",
                ],
                types: [
                    "Any", "Boolean", "Double", "Float", "Int", "Integer", "List", "Long",
                    "Map", "Object", "Set", "String", "Unit", "boolean", "byte", "char",
                    "double", "float", "int", "long", "void",
                ]
            )

        case "c", "h", "cc", "cpp", "c++", "hpp", "objective-c", "objc", "csharp", "cs", "c#":
            return Grammar(
                lineComments: ["//"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\"", "'"],
                keywords: [
                    "auto", "break", "case", "catch", "class", "const", "constexpr", "continue",
                    "default", "delete", "do", "else", "enum", "explicit", "extern", "false",
                    "for", "friend", "goto", "if", "inline", "namespace", "new", "nullptr",
                    "operator", "private", "protected", "public", "return", "sizeof", "static",
                    "struct", "switch", "template", "this", "throw", "true", "try", "typedef",
                    "typename", "union", "using", "virtual", "volatile", "while",
                ],
                types: [
                    "bool", "char", "double", "float", "int", "long", "short", "signed",
                    "size_t", "string", "unsigned", "var", "void",
                ]
            )

        case "ruby", "rb":
            return Grammar(
                lineComments: ["#"],
                stringDelimiters: ["\"", "'"],
                keywords: [
                    "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do",
                    "else", "elsif", "end", "ensure", "false", "for", "if", "in", "module",
                    "next", "nil", "not", "or", "redo", "require", "rescue", "retry", "return",
                    "self", "super", "then", "true", "unless", "until", "when", "while", "yield",
                ],
                types: ["Array", "Float", "Hash", "Integer", "String", "Symbol"]
            )

        case "php":
            return Grammar(
                lineComments: ["//", "#"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\"", "'"],
                keywords: [
                    "abstract", "array", "as", "break", "case", "catch", "class", "const",
                    "continue", "declare", "default", "do", "echo", "else", "elseif", "empty",
                    "endif", "extends", "false", "final", "finally", "fn", "for", "foreach",
                    "function", "global", "if", "implements", "include", "instanceof",
                    "interface", "isset", "namespace", "new", "null", "private", "protected",
                    "public", "require", "return", "static", "switch", "throw", "trait", "true",
                    "try", "unset", "use", "var", "while", "yield",
                ],
                variablePrefixes: ["$"]
            )

        case "sql":
            return Grammar(
                lineComments: ["--"],
                blockComment: ("/*", "*/"),
                stringDelimiters: ["'", "\""],
                keywords: [
                    "add", "all", "alter", "and", "as", "asc", "begin", "between", "by",
                    "case", "column", "commit", "constraint", "create", "cross", "delete",
                    "desc", "distinct", "drop", "else", "end", "exists", "foreign", "from",
                    "full", "group", "having", "in", "index", "inner", "insert", "into", "is",
                    "join", "key", "left", "like", "limit", "not", "null", "offset", "on",
                    "or", "order", "outer", "primary", "references", "right", "rollback",
                    "select", "set", "table", "then", "transaction", "union", "unique",
                    "update", "values", "view", "when", "where", "with",
                ],
                types: [
                    "bigint", "boolean", "char", "date", "decimal", "float", "int", "integer",
                    "numeric", "serial", "text", "timestamp", "uuid", "varchar",
                ],
                ignoresCase: true
            )

        default:
            return nil
        }
    }
}
