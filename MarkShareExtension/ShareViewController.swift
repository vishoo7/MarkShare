import UIKit
import Social
import UniformTypeIdentifiers
import WebKit

/// Share extension view controller for receiving markdown/text input
class ShareViewController: UIViewController {

    private var webView: WKWebView!
    private var markdownText: String = ""
    private var shareBarButton: UIBarButtonItem?

    private let renderer = ExtensionMarkdownRenderer()
    private var currentTheme: String = "light"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSharedContent()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Navigation bar
        let navBar = UINavigationBar(frame: .zero)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        let navItem = UINavigationItem(title: "MarkShare")
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        let shareButton = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )
        navItem.rightBarButtonItem = shareButton
        self.shareBarButton = shareButton
        navBar.items = [navItem]

        // Web view for preview
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = false
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Theme bar with scrollable buttons
        let themeBar = UIView(frame: .zero)
        themeBar.translatesAutoresizingMaskIntoConstraints = false
        themeBar.backgroundColor = .secondarySystemBackground
        view.addSubview(themeBar)

        let scrollView = UIScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        themeBar.addSubview(scrollView)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        scrollView.addSubview(stack)

        let themeLabel = UILabel()
        themeLabel.text = "Theme:"
        themeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        themeLabel.textColor = .secondaryLabel
        themeLabel.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(themeLabel)

        let themes: [(String, Selector)] = [
            ("Light", #selector(selectLight)),
            ("GitHub", #selector(selectGithub)),
            ("Sepia", #selector(selectSepia)),
            ("Dark", #selector(selectDark)),
            ("Solarized", #selector(selectSolarized)),
            ("Nord", #selector(selectNord)),
            ("Dracula", #selector(selectDracula)),
        ]

        for (title, action) in themes {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.addTarget(self, action: action, for: .touchUpInside)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            themeBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            themeBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            themeBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            themeBar.heightAnchor.constraint(equalToConstant: 44),

            scrollView.topAnchor.constraint(equalTo: themeBar.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: themeBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: themeBar.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: themeBar.trailingAnchor, constant: -8),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            webView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: themeBar.topAnchor)
        ])
    }

    // MARK: - Load Shared Content

    private func loadSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments else {
            showError("No content received")
            return
        }

        // Try to load markdown first, then plain text
        let markdownType = UTType.init("net.daringfireball.markdown")?.identifier ?? "net.daringfireball.markdown"
        let textTypes = [markdownType, UTType.plainText.identifier, UTType.text.identifier]

        for provider in itemProviders {
            for type in textTypes {
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.showError(error.localizedDescription)
                                return
                            }

                            var text: String?
                            if let string = item as? String {
                                text = string
                            } else if let data = item as? Data {
                                text = String(data: data, encoding: .utf8)
                            } else if let url = item as? URL {
                                text = try? String(contentsOf: url, encoding: .utf8)
                            }

                            if let text = text {
                                self?.markdownText = text
                                self?.updatePreview()
                            } else {
                                self?.showError("Could not read content")
                            }
                        }
                    }
                    return
                }
            }
        }

        showError("No compatible content found")
    }

    // MARK: - Preview

    private func updatePreview() {
        let css = loadCSS(for: currentTheme)
        let html = renderer.render(markdown: markdownText, css: css)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func loadCSS(for theme: String) -> String {
        guard let url = Bundle.main.url(forResource: theme, withExtension: "css", subdirectory: "Themes"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return ExtensionMarkdownRenderer.fallbackCSS
        }
        return css
    }

    // MARK: - Theme Selection

    @objc private func selectLight() {
        currentTheme = "light"
        updatePreview()
    }

    @objc private func selectDark() {
        currentTheme = "dark"
        updatePreview()
    }

    @objc private func selectGithub() {
        currentTheme = "github"
        updatePreview()
    }

    @objc private func selectSepia() {
        currentTheme = "sepia"
        updatePreview()
    }

    @objc private func selectSolarized() {
        currentTheme = "solarized"
        updatePreview()
    }

    @objc private func selectNord() {
        currentTheme = "nord"
        updatePreview()
    }

    @objc private func selectDracula() {
        currentTheme = "dracula"
        updatePreview()
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func shareTapped() {
        // Generate PDF and share
        let css = loadCSS(for: currentTheme)
        let html = renderer.render(markdown: markdownText, css: css)

        generatePDF(from: html) { [weak self] url in
            guard let url = url else {
                self?.showError("Failed to generate PDF")
                return
            }

            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                if let button = self?.shareBarButton {
                    popover.barButtonItem = button
                } else {
                    popover.sourceView = self?.view
                    popover.sourceRect = CGRect(x: (self?.view.bounds.midX ?? 0), y: 0, width: 0, height: 0)
                }
            }

            activityVC.completionWithItemsHandler = { _, _, _, _ in
                // Clean up temp file
                try? FileManager.default.removeItem(at: url)
            }

            self?.present(activityVC, animated: true)
        }
    }

    private func generatePDF(from html: String, completion: @escaping (URL?) -> Void) {
        let printFormatter = UIMarkupTextPrintFormatter(markupText: html)

        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let printableRect = pageRect.insetBy(dx: 36, dy: 36)

        let renderer = PDFPageRenderer(paperRect: pageRect, printableRect: printableRect)
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)

        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }

        UIGraphicsEndPDFContext()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkShare_\(Date().timeIntervalSince1970).pdf")

        do {
            try pdfData.write(to: tempURL)
            completion(tempURL)
        } catch {
            completion(nil)
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
        present(alert, animated: true)
    }
}

// MARK: - Simplified Markdown Renderer for Extension

/// Lightweight markdown renderer for the share extension
struct ExtensionMarkdownRenderer {

    static let fallbackCSS = """
    body {
        font-family: -apple-system, sans-serif;
        font-size: 16px;
        line-height: 1.6;
        padding: 20px;
        max-width: 800px;
        margin: 0 auto;
    }
    pre, code { font-family: monospace; background: #f5f5f5; padding: 2px 4px; border-radius: 4px; }
    pre { padding: 1em; overflow-x: auto; }
    pre code { padding: 0; background: none; }
    blockquote { border-left: 4px solid #ddd; margin: 1em 0; padding-left: 1em; color: #666; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background: #f5f5f5; }
    """

    func render(markdown: String, css: String) -> String {
        let bodyHTML = convertToHTML(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>\(css)</style>
        </head>
        <body>\(bodyHTML)</body>
        </html>
        """
    }

    func convertToHTML(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var html = ""
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Code blocks
            if line.hasPrefix("```") {
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].hasPrefix("```") {
                    codeLines.append(escapeHTML(lines[index]))
                    index += 1
                }
                index += 1
                html += "<pre><code>\(codeLines.joined(separator: "\n"))</code></pre>\n"
                continue
            }

            // Headers
            if line.hasPrefix("#") {
                var level = 0
                for char in line { if char == "#" { level += 1 } else { break } }
                if level >= 1 && level <= 6 {
                    let content = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    html += "<h\(level)>\(parseInline(content))</h\(level)>\n"
                    index += 1
                    continue
                }
            }

            // Blockquotes
            if line.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count && lines[index].hasPrefix(">") {
                    quoteLines.append(String(lines[index].dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                html += "<blockquote><p>\(quoteLines.joined(separator: "<br>"))</p></blockquote>\n"
                continue
            }

            // Lists
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [String] = []
                while index < lines.count && (lines[index].hasPrefix("- ") || lines[index].hasPrefix("* ")) {
                    items.append(String(lines[index].dropFirst(2)))
                    index += 1
                }
                html += "<ul>\n" + items.map { "<li>\(parseInline($0))</li>" }.joined(separator: "\n") + "\n</ul>\n"
                continue
            }

            // Horizontal rule
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                html += "<hr>\n"
                index += 1
                continue
            }

            // Empty line
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // Paragraph
            html += "<p>\(parseInline(line))</p>\n"
            index += 1
        }

        return html
    }

    private func parseInline(_ text: String) -> String {
        var result = escapeHTML(text)
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)

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

        return result
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
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
}

// MARK: - PDF Page Renderer

private class PDFPageRenderer: UIPrintPageRenderer {
    private let _paperRect: CGRect
    private let _printableRect: CGRect

    init(paperRect: CGRect, printableRect: CGRect) {
        _paperRect = paperRect
        _printableRect = printableRect
        super.init()
    }

    override var paperRect: CGRect { _paperRect }
    override var printableRect: CGRect { _printableRect }
}
