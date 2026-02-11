import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: MessageRole = .user,
        content: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
