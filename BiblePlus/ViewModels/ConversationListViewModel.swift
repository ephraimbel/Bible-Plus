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

    // MARK: - Computed

    var userName: String {
        let descriptor = FetchDescriptor<UserProfile>()
        return (try? modelContext.fetch(descriptor))?.first?.firstName ?? ""
    }

    var pinnedConversations: [Conversation] {
        conversations.filter { $0.isPinned }
    }

    var unpinnedConversations: [Conversation] {
        conversations.filter { !$0.isPinned }
    }

    // MARK: - Loading

    func loadConversations() {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        var fetched = (try? modelContext.fetch(descriptor)) ?? []
        // Sort pinned first, then by updatedAt desc
        fetched.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
        conversations = fetched
    }

    // MARK: - Create

    func createNewConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        modelContext.insert(conversation)
        modelContext.safeSave()
        conversations.insert(conversation, at: pinnedConversations.count)
        return conversation
    }

    func createCharacterConversation(character: BiblicalCharacter) -> Conversation {
        let conversation = Conversation(
            title: "Conversation with \(character.displayName)",
            character: character
        )
        modelContext.insert(conversation)
        modelContext.safeSave()
        conversations.insert(conversation, at: pinnedConversations.count)
        return conversation
    }

    func createConversationWithMode(_ mode: ConversationMode) -> Conversation {
        let conversation = Conversation(title: "New Conversation", mode: mode)
        modelContext.insert(conversation)
        modelContext.safeSave()
        conversations.insert(conversation, at: pinnedConversations.count)
        return conversation
    }

    // MARK: - Pin

    func togglePin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        conversation.updatedAt = Date()
        modelContext.safeSave()
        loadConversations()
        HapticService.lightImpact()
    }

    // MARK: - Delete

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
        modelContext.safeSave()
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
