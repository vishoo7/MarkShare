import SwiftUI
import CoreImage.CIFilterBuiltins

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copiedBTC = false

    private let btcAddress = "bc1qudwqcfajt976mk55cx8372w8s4f2s343wlhhdk"
    private let githubURL = "https://github.com/vishoo7/MarkShare"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    whatItDoesSection
                    contributeSection
                    supportSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("MarkShare")
                .font(.title.bold())

            Text("Render & share Markdown beautifully")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - What It Does

    private var whatItDoesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("What It Does", systemImage: "doc.richtext")
                    .font(.headline)

                Text("Had an amazing conversation with ChatGPT or Claude? MarkShare lets you turn it into a beautifully formatted PDF, PNG, or HTML — ready to share with anyone. Paste an AI conversation or any Markdown, pick a theme, and export a stunning document in seconds. No accounts, no cloud uploads — everything happens on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Contribute

    private var contributeSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Contribute", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)

                Text("MarkShare is open source. Report bugs, suggest features, or submit a pull request.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: githubURL)!) {
                    HStack {
                        Text("View on GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Support Development

    private var supportSection: some View {
        sectionCard {
            VStack(spacing: 12) {
                Label("Support Development", systemImage: "heart")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("If you find MarkShare useful, consider sending a tip via Bitcoin. Every contribution helps keep development going.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let qrImage = generateQRCode(from: "bitcoin:\(btcAddress)") {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                }

                Text("Bitcoin Address")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(btcAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    UIPasteboard.general.string = btcAddress
                    copiedBTC = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedBTC = false
                    }
                } label: {
                    HStack {
                        Image(systemName: copiedBTC ? "checkmark" : "doc.on.doc")
                        Text(copiedBTC ? "Copied!" : "Copy Address")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 256.0 / outputImage.extent.size.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    AboutView()
}
