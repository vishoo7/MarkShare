import SwiftUI

/// Theme selection picker with visual previews
struct ThemePicker: View {
    @Binding var selectedTheme: Theme

    var body: some View {
        Menu {
            ForEach(Theme.allCases) { theme in
                Button {
                    selectedTheme = theme
                } label: {
                    Label {
                        Text(theme.displayName)
                    } icon: {
                        Image(systemName: theme.iconName)
                    }
                }
            }
        } label: {
            Label {
                Text(selectedTheme.displayName)
            } icon: {
                Image(systemName: selectedTheme.iconName)
            }
            .labelStyle(.titleAndIcon)
        }
    }
}

/// Compact theme picker showing color swatches
struct ThemePickerCompact: View {
    @Binding var selectedTheme: Theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Theme.allCases) { theme in
                ThemeButton(
                    theme: theme,
                    isSelected: selectedTheme == theme
                ) {
                    selectedTheme = theme
                }
            }
        }
    }
}

/// Individual theme button with preview colors
struct ThemeButton: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.previewBackgroundColor)
                    .frame(width: 44, height: 44)

                VStack(spacing: 2) {
                    Circle()
                        .fill(theme.previewTextColor)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(theme.previewAccentColor)
                        .frame(width: 20, height: 4)
                        .cornerRadius(2)
                    Rectangle()
                        .fill(theme.previewTextColor.opacity(0.5))
                        .frame(width: 16, height: 3)
                        .cornerRadius(1.5)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: 20) {
        ThemePicker(selectedTheme: .constant(.light))

        ThemePickerCompact(selectedTheme: .constant(.github))
    }
    .padding()
}
