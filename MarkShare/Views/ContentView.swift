import SwiftUI
import StoreKit

/// Main content view with markdown editor and preview
struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.requestReview) var requestReview

    @AppStorage("exportCount") private var exportCount = 0
    @State private var markdownText = ""
    @State private var showingPreview = false
    @State private var showingExportOptions = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingError = false
    @State private var showingClearConfirmation = false
    @State private var showingAbout = false

    // Conversation mode state
    @State private var isConversationMode = false
    @State private var conversationEntries: [ConversationEntry] = []

    private let renderer = MarkdownRenderer()
    private let exportService = ExportService()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > 700 {
                    // iPad / large screen: side-by-side layout
                    HStack(spacing: 0) {
                        if isConversationMode {
                            ConversationView(entries: $conversationEntries)
                                .frame(width: geometry.size.width / 2)
                        } else {
                            editorView
                                .frame(width: geometry.size.width / 2)
                        }

                        Divider()

                        previewView
                            .frame(width: geometry.size.width / 2)
                    }
                } else {
                    // iPhone / compact: toggle between views
                    if showingPreview {
                        previewView
                    } else {
                        if isConversationMode {
                            ConversationView(entries: $conversationEntries)
                        } else {
                            editorView
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThemePicker(selectedTheme: $themeManager.currentTheme)
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image("AppIconImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .accessibilityLabel("About MarkShare")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    clearButton
                    toggleButton
                    conversationModeButton
                    shareButton
                }
            }
            .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
                ForEach(ExportService.ExportFormat.allCases) { format in
                    Button(format.rawValue) {
                        Task {
                            await exportAs(format)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Clear Content", isPresented: $showingClearConfirmation) {
                Button("Clear", role: .destructive) {
                    if isConversationMode {
                        conversationEntries = []
                    } else {
                        markdownText = ""
                    }
                    showingPreview = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(isConversationMode
                     ? "Are you sure you want to clear all conversation entries?"
                     : "Are you sure you want to clear all text?")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "An unknown error occurred")
            }
            .overlay {
                if isExporting {
                    ProgressView("Exporting...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Subviews

    private var editorView: some View {
        VStack(spacing: 0) {
            MarkdownInputView(text: $markdownText)
                .padding(.horizontal, 8)
        }
    }

    private var previewView: some View {
        PreviewWebView(html: renderedHTML)
    }

    private var clearButton: some View {
        Button {
            showingClearConfirmation = true
        } label: {
            Image(systemName: "trash")
        }
        .disabled(isConversationMode ? conversationEntries.isEmpty : markdownText.isEmpty)
        .accessibilityLabel("Clear")
    }

    private var toggleButton: some View {
        Button {
            withAnimation {
                showingPreview.toggle()
            }
        } label: {
            Image(systemName: showingPreview ? "pencil" : "eye")
        }
        .accessibilityLabel(showingPreview ? "Edit" : "Preview")
    }

    private var conversationModeButton: some View {
        Button {
            withAnimation {
                isConversationMode.toggle()
            }
        } label: {
            Image(systemName: isConversationMode
                  ? "doc.text"
                  : "bubble.left.and.bubble.right")
        }
        .accessibilityLabel(isConversationMode ? "Markdown Mode" : "Conversation Mode")
    }

    private var shareButton: some View {
        Button {
            showingExportOptions = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(isConversationMode ? conversationEntries.isEmpty : markdownText.isEmpty)
        .accessibilityLabel("Share")
    }

    // MARK: - Computed Properties

    private var renderedHTML: String {
        let css = themeManager.loadCurrentThemeCSS()
        if isConversationMode {
            return renderer.renderConversation(entries: conversationEntries, css: css)
        } else {
            return renderer.render(markdown: markdownText, css: css)
        }
    }

    // MARK: - Export

    private func exportAs(_ format: ExportService.ExportFormat) async {
        isExporting = true

        do {
            let url = try await exportService.export(html: renderedHTML, format: format, markdown: markdownText)
            exportedFileURL = url
            showingShareSheet = true
            exportCount += 1
            if exportCount == 100 {
                requestReview()
            }
        } catch {
            exportError = error.localizedDescription
            showingError = true
        }

        isExporting = false
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}
