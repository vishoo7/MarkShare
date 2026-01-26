import SwiftUI

/// First-launch welcome screen showing the app's value proposition
struct WelcomeView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Headline
            Text("Welcome to MarkShare")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Subhead
            Text("Paste Markdown. Preview it. Share it as PDF, image, or HTML — all without leaving your device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Bullets
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(emoji: "🔒", title: "Private", description: "No servers, no tracking, no network calls")
                FeatureRow(emoji: "⚡", title: "Fast", description: "Paste, preview, share")
                FeatureRow(emoji: "🎨", title: "Themed", description: "Pick a style that fits")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Spacer()

            // Button
            Button {
                isPresented = false
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

/// A single feature row with emoji, title, and description
private struct FeatureRow: View {
    let emoji: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(emoji)
                .font(.title)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView(isPresented: .constant(true))
}
