import SwiftUI

/// Main container for conversation mode with list of message entries
struct ConversationView: View {
    @Binding var entries: [ConversationEntry]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach($entries) { $entry in
                    ConversationEntryView(
                        entry: $entry,
                        onDelete: {
                            deleteEntry(entry)
                        }
                    )
                    .padding(.horizontal)
                }

                addEntryButton
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
    }

    private var addEntryButton: some View {
        Button {
            addEntry()
        } label: {
            Label("Add Message", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func addEntry() {
        let newRole: ConversationEntry.Role
        if let lastEntry = entries.last {
            // Alternate between user and assistant
            newRole = lastEntry.role == .user ? .assistant : .user
        } else {
            newRole = .user
        }
        let newEntry = ConversationEntry(role: newRole)
        entries.append(newEntry)
    }

    private func deleteEntry(_ entry: ConversationEntry) {
        entries.removeAll { $0.id == entry.id }
    }
}

#Preview {
    @Previewable @State var entries = [
        ConversationEntry(role: .user, content: "Hello!"),
        ConversationEntry(role: .assistant, content: "Hi there! How can I help you?")
    ]
    ConversationView(entries: $entries)
}
