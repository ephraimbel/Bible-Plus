import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var conversationId: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date

    /// Sentinel UUID used for legacy messages that predate conversation threading.
    static let legacyConversationId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    init(
        id: UUID = UUID(),
        conversationId: UUID = ChatMessage.legacyConversationId,
        role: MessageRole = .user,
        content: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
