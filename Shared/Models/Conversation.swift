import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var characterRaw: String? = nil
    var modeRaw: String? = nil
    var isPinned: Bool = false

    var character: BiblicalCharacter? {
        get { characterRaw.flatMap { BiblicalCharacter(rawValue: $0) } }
        set { characterRaw = newValue?.rawValue }
    }

    var mode: ConversationMode? {
        get { modeRaw.flatMap { ConversationMode(rawValue: $0) } }
        set { modeRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        character: BiblicalCharacter? = nil,
        mode: ConversationMode? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.characterRaw = character?.rawValue
        self.modeRaw = mode?.rawValue
        self.isPinned = isPinned
    }
}
