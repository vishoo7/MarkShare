import SwiftUI

/// Available themes for markdown rendering
enum Theme: String, CaseIterable, Identifiable {
    case light
    case github
    case sepia
    case dark
    case solarized
    case nord
    case dracula

    var id: String { rawValue }

    /// Display name for the theme
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .github: return "GitHub"
        case .sepia: return "Sepia"
        case .solarized: return "Solarized"
        case .nord: return "Nord"
        case .dracula: return "Dracula"
        }
    }

    /// CSS filename in the bundle
    var cssFilename: String {
        return "\(rawValue).css"
    }

    /// Preview background color for theme picker
    var previewBackgroundColor: Color {
        switch self {
        case .light: return Color(red: 1.0, green: 1.0, blue: 1.0)
        case .dark: return Color(red: 0.1, green: 0.1, blue: 0.1)
        case .github: return Color(red: 1.0, green: 1.0, blue: 1.0)
        case .sepia: return Color(red: 0.96, green: 0.94, blue: 0.90)
        case .solarized: return Color(red: 0.0, green: 0.169, blue: 0.212)
        case .nord: return Color(red: 0.180, green: 0.204, blue: 0.251)
        case .dracula: return Color(red: 0.157, green: 0.165, blue: 0.212)
        }
    }

    /// Preview text color for theme picker
    var previewTextColor: Color {
        switch self {
        case .light: return Color(red: 0.2, green: 0.2, blue: 0.2)
        case .dark: return Color(red: 0.88, green: 0.88, blue: 0.88)
        case .github: return Color(red: 0.14, green: 0.16, blue: 0.18)
        case .sepia: return Color(red: 0.36, green: 0.29, blue: 0.22)
        case .solarized: return Color(red: 0.514, green: 0.580, blue: 0.588)
        case .nord: return Color(red: 0.847, green: 0.871, blue: 0.914)
        case .dracula: return Color(red: 0.973, green: 0.973, blue: 0.949)
        }
    }

    /// Preview accent color for theme picker
    var previewAccentColor: Color {
        switch self {
        case .light: return Color(red: 0.0, green: 0.4, blue: 0.8)
        case .dark: return Color(red: 0.34, green: 0.65, blue: 1.0)
        case .github: return Color(red: 0.04, green: 0.41, blue: 0.85)
        case .sepia: return Color(red: 0.55, green: 0.35, blue: 0.17)
        case .solarized: return Color(red: 0.149, green: 0.545, blue: 0.824)
        case .nord: return Color(red: 0.533, green: 0.753, blue: 0.816)
        case .dracula: return Color(red: 0.741, green: 0.576, blue: 0.976)
        }
    }

    /// System icon name for the theme
    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .github: return "doc.text.fill"
        case .sepia: return "book.fill"
        case .solarized: return "sunset.fill"
        case .nord: return "snowflake"
        case .dracula: return "wand.and.stars"
        }
    }
}
