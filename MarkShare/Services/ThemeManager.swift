import SwiftUI

/// Manages the current theme selection with persistence
@MainActor
final class ThemeManager: ObservableObject {

    private static let themeKey = "selectedTheme"

    /// The currently selected theme
    @Published var currentTheme: Theme {
        didSet {
            saveTheme()
        }
    }

    init() {
        // Load saved theme or default to light
        if let savedThemeName = UserDefaults.standard.string(forKey: Self.themeKey),
           let savedTheme = Theme(rawValue: savedThemeName) {
            self.currentTheme = savedTheme
        } else {
            self.currentTheme = .light
        }
    }

    /// Saves the current theme to UserDefaults
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.themeKey)
    }

    /// Loads CSS content for the current theme from the bundle
    func loadCurrentThemeCSS() -> String {
        loadCSS(for: currentTheme)
    }

    /// Loads CSS content for a specific theme
    func loadCSS(for theme: Theme) -> String {
        // Try with subdirectory first, then without (depending on how Xcode copies resources)
        let url = Bundle.main.url(forResource: theme.rawValue, withExtension: "css", subdirectory: "Themes")
            ?? Bundle.main.url(forResource: theme.rawValue, withExtension: "css")

        guard let url else {
            // Fallback to embedded minimal CSS
            return Self.fallbackCSS
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            return Self.fallbackCSS
        }
    }

    /// Minimal fallback CSS if theme file cannot be loaded
    private static let fallbackCSS = """
    body {
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        font-size: 16px;
        line-height: 1.6;
        padding: 20px;
        max-width: 800px;
        margin: 0 auto;
    }
    pre, code {
        font-family: monospace;
        background-color: #f5f5f5;
        padding: 2px 4px;
        border-radius: 4px;
    }
    pre {
        padding: 1em;
        overflow-x: auto;
    }
    pre code {
        padding: 0;
        background: none;
    }
    blockquote {
        border-left: 4px solid #ddd;
        margin: 1em 0;
        padding-left: 1em;
        color: #666;
    }
    table {
        border-collapse: collapse;
        width: 100%;
    }
    th, td {
        border: 1px solid #ddd;
        padding: 8px;
        text-align: left;
    }
    th {
        background-color: #f5f5f5;
    }
    """
}
