import UIKit
import Social
import UniformTypeIdentifiers
import WebKit

/// Share extension view controller for receiving markdown/text input
class ShareViewController: UIViewController {

    private var webView: WKWebView!
    private var markdownText: String = ""
    private var shareBarButton: UIBarButtonItem?

    /// The same renderer the main app uses, so shared content renders identically
    private let renderer = MarkdownRenderer()
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
            ("Gruvbox", #selector(selectGruvbox)),
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
        let url = Bundle.main.url(forResource: theme, withExtension: "css", subdirectory: "Themes")
            ?? Bundle.main.url(forResource: theme, withExtension: "css")
        guard let url = url,
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return Self.fallbackCSS
        }
        return css
    }

    /// Used only if a theme file is somehow missing from the extension bundle
    private static let fallbackCSS = """
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
    .tok-com { color: #6a737d; font-style: italic; }
    .tok-str { color: #032f62; }
    .tok-num { color: #005cc5; }
    .tok-kw { color: #d73a49; }
    .tok-typ { color: #6f42c1; }
    .tok-fn { color: #6f42c1; }
    .tok-key { color: #22863a; }
    """

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

    @objc private func selectGruvbox() {
        currentTheme = "gruvbox"
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
