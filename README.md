# MarkShare

A privacy-focused iOS app for rendering and sharing Markdown as PDF, PNG, or HTML.

## Features

- **Pure Swift Markdown Renderer** - No external dependencies. Supports CommonMark and GitHub Flavored Markdown:
  - Headers (h1-h6)
  - Bold, italic, strikethrough
  - Links and images
  - Ordered and unordered lists
  - Task lists (checkboxes)
  - Code blocks (fenced with language support)
  - Inline code
  - Blockquotes
  - Tables (GFM style)
  - Horizontal rules

- **4 Beautiful Themes**
  - Light
  - Dark
  - GitHub
  - Sepia

- **Multiple Export Formats**
  - PDF - Full document with pagination
  - PNG - Image snapshot of rendered content
  - HTML - Raw HTML file with embedded CSS

- **Adaptive Layout**
  - iPhone: Toggle between editor and preview
  - iPad: Side-by-side editor and live preview

- **Share Extension**
  - Accept markdown or plain text from other apps
  - Preview and re-share in your preferred format

## Privacy

MarkShare is designed with privacy as a core principle:

- **No network access** - All processing happens on-device
- **No analytics or tracking** - Your content stays yours
- **No account required** - Just open and use
- **JavaScript disabled** in preview (enabled only for export measurements)

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Building

1. Clone the repository
2. Open `MarkShare.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on your device or simulator

## Usage

1. **Write** - Enter your markdown in the editor
2. **Preview** - Tap the eye icon to see rendered output
3. **Theme** - Use the theme picker to change the look
4. **Share** - Tap the share button and choose PDF, PNG, or HTML

## Project Structure

```
MarkShare/
├── App/
│   └── MarkShareApp.swift          # App entry point
├── Views/
│   ├── ContentView.swift           # Main container view
│   ├── MarkdownInputView.swift     # Text editor with placeholder
│   ├── PreviewWebView.swift        # WKWebView wrapper for preview
│   └── ThemePicker.swift           # Theme selection UI
├── Services/
│   ├── MarkdownRenderer.swift      # Markdown to HTML converter
│   ├── ExportService.swift         # PDF/PNG/HTML export
│   └── ThemeManager.swift          # Theme persistence
├── Models/
│   └── Theme.swift                 # Theme enum and properties
└── Resources/
    └── Themes/                     # CSS theme files
        ├── light.css
        ├── dark.css
        ├── github.css
        └── sepia.css
```

## License

MIT License
