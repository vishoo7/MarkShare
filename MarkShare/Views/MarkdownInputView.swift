import SwiftUI

/// Text editor for markdown input with placeholder support
struct MarkdownInputView: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

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

            // Text Editor
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    MarkdownInputView(text: .constant(""))
        .padding()
}
