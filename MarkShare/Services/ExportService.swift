import UIKit
import WebKit

/// Handles exporting rendered markdown to various formats
@MainActor
final class ExportService: NSObject {

    enum ExportFormat: String, CaseIterable, Identifiable {
        case pdf = "PDF"
        case image = "PNG"
        case html = "HTML"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .image: return "png"
            case .html: return "html"
            }
        }

        var mimeType: String {
            switch self {
            case .pdf: return "application/pdf"
            case .image: return "image/png"
            case .html: return "text/html"
            }
        }

        var iconName: String {
            switch self {
            case .pdf: return "doc.fill"
            case .image: return "photo.fill"
            case .html: return "chevron.left.forwardslash.chevron.right"
            }
        }
    }

    private var webView: WKWebView?
    private var exportContinuation: CheckedContinuation<Data, Error>?

    /// Exports the HTML content to the specified format
    func export(html: String, format: ExportFormat, markdown: String = "") async throws -> URL {
        let data = try await generateData(html: html, format: format)
        return try saveToTemporaryFile(data: data, format: format, markdown: markdown)
    }

    /// Generates data for the specified format
    private func generateData(html: String, format: ExportFormat) async throws -> Data {
        switch format {
        case .pdf:
            return try await generatePDF(html: html)
        case .image:
            return try await generateImage(html: html)
        case .html:
            guard let data = html.data(using: .utf8) else {
                throw ExportError.encodingFailed
            }
            return data
        }
    }

    /// Generates PDF from HTML using WKWebView
    private func generatePDF(html: String) async throws -> Data {
        let webView = createWebView(enableJavaScript: true)
        self.webView = webView

        // Set webview to a reasonable width for PDF rendering
        let pdfWidth: CGFloat = 612 // US Letter width in points
        webView.frame = CGRect(x: 0, y: 0, width: pdfWidth, height: 792)

        // Load HTML and wait for it to finish
        try await loadHTML(html, in: webView)

        // Get actual content height
        let contentHeight = try await webView.evaluateJavaScript(
            "document.documentElement.scrollHeight"
        ) as? CGFloat ?? 792

        // Resize webview to fit all content
        webView.frame = CGRect(x: 0, y: 0, width: pdfWidth, height: contentHeight)

        // Wait for layout to settle
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Generate PDF - don't set rect to allow full content capture with pagination
        let configuration = WKPDFConfiguration()

        let data = try await webView.pdf(configuration: configuration)
        self.webView = nil
        return data
    }

    /// Generates PNG image from HTML using WKWebView snapshot
    private func generateImage(html: String) async throws -> Data {
        let webView = createWebView(enableJavaScript: true)
        self.webView = webView

        // Load HTML and wait for it to finish
        try await loadHTML(html, in: webView)

        // Get content size from the web view
        let contentHeight = try await webView.evaluateJavaScript(
            "document.documentElement.scrollHeight"
        ) as? CGFloat ?? 800

        let contentWidth = try await webView.evaluateJavaScript(
            "document.documentElement.scrollWidth"
        ) as? CGFloat ?? 600

        // Resize webview to content size
        webView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)

        // Wait a bit for layout to settle
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Take snapshot
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)

        let image = try await webView.takeSnapshot(configuration: configuration)

        guard let pngData = image.pngData() else {
            throw ExportError.imageGenerationFailed
        }

        self.webView = nil
        return pngData
    }

    /// Creates a configured WKWebView for rendering
    private func createWebView(enableJavaScript: Bool = false) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = enableJavaScript

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        webView.isOpaque = true
        return webView
    }

    /// Loads HTML into the web view and waits for it to finish
    private func loadHTML(_ html: String, in webView: WKWebView) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let navigationDelegate = NavigationDelegate { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Store delegate to prevent deallocation
            objc_setAssociatedObject(
                webView,
                "navigationDelegate",
                navigationDelegate,
                .OBJC_ASSOCIATION_RETAIN
            )

            webView.navigationDelegate = navigationDelegate
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    /// Extracts a filename from the first markdown heading, or falls back to a date-based name
    private func generateFileName(from markdown: String, format: ExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timeStamp = formatter.string(from: Date())

        // Look for the first heading (#, ##, ###, etc.)
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") || trimmed == "#" {
                // Strip the leading # and whitespace
                let title = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    // Sanitize: keep alphanumerics, spaces, hyphens; replace spaces with underscores
                    let sanitized = title
                        .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -")).inverted)
                        .joined()
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: " ", with: "_")
                    if !sanitized.isEmpty {
                        let truncated = String(sanitized.prefix(60))
                        return "\(truncated)_\(timeStamp).\(format.fileExtension)"
                    }
                }
            }
        }

        // Fallback: date-based name
        return "MarkShare_\(timeStamp).\(format.fileExtension)"
    }

    /// Saves data to a temporary file and returns its URL
    private func saveToTemporaryFile(data: Data, format: ExportFormat, markdown: String = "") throws -> URL {
        let fileName = generateFileName(from: markdown, format: format)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Navigation Delegate

private class NavigationDelegate: NSObject, WKNavigationDelegate {
    private let completion: (Result<Void, Error>) -> Void

    init(completion: @escaping (Result<Void, Error>) -> Void) {
        self.completion = completion
    }

    // Block remote resource loads (images, fonts, stylesheets)
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let scheme = navigationAction.request.url?.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give the page a moment to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.completion(.success(()))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case encodingFailed
    case pdfGenerationFailed
    case imageGenerationFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode HTML content"
        case .pdfGenerationFailed:
            return "Failed to generate PDF"
        case .imageGenerationFailed:
            return "Failed to generate image"
        case .saveFailed:
            return "Failed to save exported file"
        }
    }
}
