import Foundation

/// Represents a single message in a conversation
struct ConversationEntry: Identifiable {
    let id: UUID
    var role: Role
    var content: String

    /// The role of the message sender
    enum Role: String, CaseIterable, Identifiable {
        case user = "User"
        case assistant = "Assistant"
        case system = "System"

        var id: String { rawValue }
    }

    init(id: UUID = UUID(), role: Role = .user, content: String = "") {
        self.id = id
        self.role = role
        self.content = content
    }
}
