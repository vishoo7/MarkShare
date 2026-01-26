# Claude Code Instructions for MarkShare

## Project Overview
Privacy-focused iOS app for rendering and sharing Markdown as PDF, PNG, or HTML. Built with SwiftUI and WKWebView. No external dependencies - uses a pure Swift Markdown renderer.

## Development Workflow
- Use `main` branch for development
- Push after features are complete and tested

## Release Workflow (Xcode Cloud)
Xcode Cloud is configured for **tag-based builds only** (pattern: `v*`).

- **"ship it"** = commit and push to main (no build triggered)
- **"release it"** or **"tag it"** = also create and push a version tag to trigger Xcode Cloud build

To create a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

Beta/TestFlight builds:
```bash
git tag v1.0.0-beta.1
git push origin v1.0.0-beta.1
```

To check existing tags: `git tag`
To delete a tag: `git tag -d v1.0.X && git push origin --delete v1.0.X`

## Versioning Strategy

**Version format:** `MAJOR.MINOR.PATCH` (e.g., 1.2.3)

| Change Type | Example | When to use |
|-------------|---------|-------------|
| PATCH (1.0.X) | 1.0.0 → 1.0.1 | Bug fixes, minor tweaks |
| MINOR (1.X.0) | 1.0.1 → 1.1.0 | New features, non-breaking changes |
| MAJOR (X.0.0) | 1.1.0 → 2.0.0 | Major overhaul, breaking changes |

**Current phase:** Initial development at 1.0.0

**Guidelines:**
- Use beta tags for TestFlight builds: `v1.0.0-beta.1`, `v1.0.0-beta.2`
- First public App Store release = `v1.0.0` (final)
- After public release, bump version for each App Store update
- Xcode Cloud auto-increments build numbers, no manual management needed

**To update version:** Change MARKETING_VERSION in Xcode (Target → General → Version) or in project.pbxproj

**Claude: Before creating a release tag:**
1. Ask the current release status (TestFlight beta, public release, etc.) if not recently confirmed
2. Infer change type (bug fix → patch, new feature → minor, major overhaul → major) - only ask if uncertain
3. Suggest the appropriate version/tag based on context - only ask if uncertain

## Preferences
- Update README.md when adding/changing features that affect user-facing functionality
- Commit messages should be descriptive with bullet points for multiple changes
- Include `Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>` in commits

## Build Command
```bash
xcodebuild -project MarkShare.xcodeproj -scheme MarkShare -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Key Files
- `MarkShare/App/MarkShareApp.swift` - App entry point
- `MarkShare/Views/ContentView.swift` - Main container with editor/preview
- `MarkShare/Views/PreviewWebView.swift` - WKWebView wrapper for rendering
- `MarkShare/Services/MarkdownRenderer.swift` - Pure Swift Markdown → HTML converter
- `MarkShare/Services/ExportService.swift` - PDF/PNG/HTML export functionality
- `MarkShare/Services/ThemeManager.swift` - Theme persistence and CSS loading
- `MarkShare/Models/Theme.swift` - Theme enum with colors and CSS filenames
- `MarkShare/Resources/Themes/*.css` - CSS theme files (light, dark, github, sepia)
- `MarkShareExtension/ShareViewController.swift` - Share extension for receiving text/markdown

## Adding New Swift Files
New `.swift` files must be added to `MarkShare.xcodeproj/project.pbxproj` in 4 places:
1. PBXBuildFile section
2. PBXFileReference section
3. Appropriate PBXGroup (Views, Models, Services, etc.)
4. PBXSourcesBuildPhase

## Architecture Notes
- **No network access** - All processing on-device for privacy
- **No external dependencies** - Pure Swift markdown parsing
- **JavaScript disabled** in preview WebView (enabled only in export for content measurement)
- **Share extension** has its own simplified MarkdownRenderer to avoid framework dependencies

## AI Thinking Block Handling
The app specially handles `<thinking>` and `<think>` tags from AI-generated content:

- Renders as visually muted blocks with a "Thinking" label
- Uses placeholder extraction to avoid HTML escaping issues
- Content inside thinking blocks is rendered as markdown
- CSS styles in all 4 theme files (.thinking-block class)
