import SwiftUI

/// Text editor for markdown input with placeholder support and HTML paste conversion
struct MarkdownInputView: View {
    @Binding var text: String

    private let placeholder = "Enter your markdown here...\n\n# Heading 1\n## Heading 2\n\n**Bold** and *italic* text\n\n- List item 1\n- List item 2\n\n```\ncode block\n```"

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            // Paste-aware Text Editor that converts HTML to Markdown
            PasteAwareTextEditor(text: $text)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    MarkdownInputView(text: .constant(""))
        .padding()
}
