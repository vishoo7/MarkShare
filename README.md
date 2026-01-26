# MarkShare

AI tools like Claude and ChatGPT give you responses in Markdown. If you want to share those results nicely formatted, you typically have to use their "share" feature — which uploads your conversation to their servers and generates a public link.

**MarkShare lets you skip that.** Paste the Markdown, see it rendered, share it as a PDF, image, or HTML file — all on-device. Your content never leaves your phone.

## Who It's For

- People sharing AI-generated content without creating public links
- Anyone sharing notes or docs with non-technical folks who don't read raw Markdown
- Privacy-conscious users who want zero server involvement

## Features

- **Pure Swift Markdown Renderer** — No external dependencies. Supports CommonMark and GitHub Flavored Markdown:
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
  - PDF — Full document with pagination
  - PNG — Image snapshot of rendered content
  - HTML — Raw HTML file with embedded CSS

- **Adaptive Layout**
  - iPhone: Toggle between editor and preview
  - iPad: Side-by-side editor and live preview

## Privacy

MarkShare is designed with privacy as a core principle:

- **No network access** — All processing happens on-device
- **No analytics or tracking** — Your content stays yours
- **No account required** — Just open and use
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

1. **Write** — Enter or paste your markdown in the editor
2. **Preview** — Tap the eye icon to see rendered output
3. **Theme** — Use the theme picker to change the look
4. **Share** — Tap the share button and choose PDF, PNG, or HTML

## Open Source & Transparency

- Full source code available in this repository
- All App Store builds are compiled by Xcode Cloud directly from this public repository
- Each release is tagged (e.g., `v1.0.0`) so you can verify the exact source for any version

## Project Structure

```
MarkShare/
├── App/
│   └── MarkShareApp.swift          # App entry point
├── Views/
│   ├── ContentView.swift           # Main container view
│   ├── MarkdownInputView.swift     # Text editor with placeholder
│   ├── PreviewWebView.swift        # WKWebView wrapper for preview
│   ├── ThemePicker.swift           # Theme selection UI
│   └── WelcomeView.swift           # First-launch welcome screen
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

## Contributing

Found a bug? Have a feature idea? Contributions are welcome! Please open an issue or submit a pull request.

## Support Development

If you find MarkShare useful, consider supporting development. Donations big or small are appreciated.

**Bitcoin:** `bc1qudwqcfajt976mk55cx8372w8s4f2s343wlhhdk`

<img src="bitcoin_address.png" alt="Bitcoin QR Code" width="200">

## License

MIT License
