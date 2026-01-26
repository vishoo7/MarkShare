import SwiftUI

/// Main content view with markdown editor and preview
struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @State private var markdownText = ""
    @State private var showingPreview = false
    @State private var showingExportOptions = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingError = false
    @State private var showingClearConfirmation = false

    private let renderer = MarkdownRenderer()
    private let exportService = ExportService()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > 700 {
                    // iPad / large screen: side-by-side layout
                    HStack(spacing: 0) {
                        editorView
                            .frame(width: geometry.size.width / 2)

                        Divider()

                        previewView
                            .frame(width: geometry.size.width / 2)
                    }
                } else {
                    // iPhone / compact: toggle between views
                    if showingPreview {
                        previewView
                    } else {
                        editorView
                    }
                }
            }
            .navigationTitle("MarkShare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThemePicker(selectedTheme: $themeManager.currentTheme)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    clearButton
                    toggleButton
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
            .confirmationDialog("Clear Text", isPresented: $showingClearConfirmation) {
                Button("Clear", role: .destructive) {
                    markdownText = ""
                    showingPreview = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to clear all text?")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
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
        .disabled(markdownText.isEmpty)
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

    private var shareButton: some View {
        Button {
            showingExportOptions = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(markdownText.isEmpty)
        .accessibilityLabel("Share")
    }

    // MARK: - Computed Properties

    private var renderedHTML: String {
        let css = themeManager.loadCurrentThemeCSS()
        return renderer.render(markdown: markdownText, css: css)
    }

    // MARK: - Export

    private func exportAs(_ format: ExportService.ExportFormat) async {
        isExporting = true

        do {
            let url = try await exportService.export(html: renderedHTML, format: format)
            exportedFileURL = url
            showingShareSheet = true
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
