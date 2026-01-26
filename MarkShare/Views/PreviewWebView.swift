import SwiftUI
import WebKit

/// UIViewRepresentable wrapper for WKWebView to display rendered markdown
struct PreviewWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = false

        // Disable network access
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Disable link navigation
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        // Prevent navigation to external links
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Only allow initial HTML load
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}

#Preview {
    PreviewWebView(html: """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: -apple-system; padding: 20px; }
                h1 { color: #333; }
            </style>
        </head>
        <body>
            <h1>Preview</h1>
            <p>This is a <strong>preview</strong> of rendered markdown.</p>
        </body>
        </html>
        """)
}
