import SwiftUI

/// View for a single conversation message entry
struct ConversationEntryView: View {
    @Binding var entry: ConversationEntry
    let onDelete: () -> Void

    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Role", selection: $entry.role) {
                    ForEach(ConversationEntry.Role.allCases) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }

            TextEditor(text: $entry.content)
                .frame(minHeight: 80)
                .padding(8)
                .background(roleBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(roleBorderColor, lineWidth: 1)
                )
                .focused($isTextEditorFocused)
        }
        .padding(.vertical, 4)
    }

    private var roleBackgroundColor: Color {
        switch entry.role {
        case .user:
            return Color.blue.opacity(0.05)
        case .assistant:
            return Color.green.opacity(0.05)
        case .system:
            return Color.gray.opacity(0.05)
        }
    }

    private var roleBorderColor: Color {
        switch entry.role {
        case .user:
            return Color.blue.opacity(0.2)
        case .assistant:
            return Color.green.opacity(0.2)
        case .system:
            return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    @Previewable @State var entry = ConversationEntry(role: .user, content: "Hello, how are you?")
    ConversationEntryView(entry: $entry, onDelete: {})
        .padding()
}
