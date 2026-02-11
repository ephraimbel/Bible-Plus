import Foundation
import SwiftData

@MainActor
@Observable
final class ConversationListViewModel {
    var conversations: [Conversation] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadConversations()
    }

    func loadConversations() {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        conversations = (try? modelContext.fetch(descriptor)) ?? []
    }

    func createNewConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        modelContext.insert(conversation)
        try? modelContext.save()
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        let convId = conversation.id
        let msgDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.conversationId == convId }
        )
        if let messages = try? modelContext.fetch(msgDescriptor) {
            for msg in messages {
                modelContext.delete(msg)
            }
        }
        modelContext.delete(conversation)
        try? modelContext.save()
        conversations.removeAll { $0.id == conversation.id }
    }

    func lastMessagePreview(for conversation: Conversation) -> String {
        let convId = conversation.id
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.conversationId == convId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let msg = (try? modelContext.fetch(descriptor))?.first,
              !msg.content.isEmpty else {
            return "New conversation"
        }
        return String(msg.content.prefix(80))
    }
}
