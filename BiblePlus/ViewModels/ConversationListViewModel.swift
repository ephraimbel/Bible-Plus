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

    /// Time-grouped buckets used by the journal-style conversation list.
    /// Pinned stays separate (it's always shown first regardless of date).
    /// Unpinned items fall into Today / This Week / Earlier buckets based
    /// on their `updatedAt` so the list reads like a chronological journal.
    struct GroupedConversations {
        let pinned: [Conversation]
        let today: [Conversation]
        let thisWeek: [Conversation]
        let earlier: [Conversation]

        var hasAny: Bool {
            !pinned.isEmpty || !today.isEmpty || !thisWeek.isEmpty || !earlier.isEmpty
        }
    }

    var groupedConversations: GroupedConversations {
        let calendar = Calendar.current
        let now = Date()
        var today: [Conversation] = []
        var thisWeek: [Conversation] = []
        var earlier: [Conversation] = []

        for conv in unpinnedConversations {
            if calendar.isDateInToday(conv.updatedAt) {
                today.append(conv)
            } else if let days = calendar.dateComponents([.day], from: conv.updatedAt, to: now).day,
                      days >= 0, days < 7 {
                thisWeek.append(conv)
            } else {
                earlier.append(conv)
            }
        }

        return GroupedConversations(
            pinned: pinnedConversations,
            today: today,
            thisWeek: thisWeek,
            earlier: earlier
        )
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

        // Strip card markup, markdown decoration, and the trailing follow-ups
        // marker so the preview reads as clean prose. The raw content has things
        // like `[SCRIPTURE img="..."]"For God so loved..."[/SCRIPTURE]` and
        // `## SECTION HEADINGS` which look ugly in a journal-style list.
        var cleaned = msg.content

        // Strip trailing |||suggestion||| follow-ups
        if let pipeRange = cleaned.range(of: "|||") {
            cleaned = String(cleaned[..<pipeRange.lowerBound])
        }

        // Strip [TOOLRESULT]...[/TOOLRESULT] blocks ENTIRELY (open + body + close).
        // These are agent action notes, not user-facing prose, and they make
        // previews say things like "Verse Philippians 4:19 not found" which
        // looks like the AI's actual answer.
        cleaned = cleaned.replacingOccurrences(
            of: #"\[TOOLRESULT(?:\s+[^\]]*)?\][\s\S]*?\[/TOOLRESULT\]"#,
            with: " ",
            options: .regularExpression
        )

        // Strip all OTHER card tags (open + close), keeping body content
        cleaned = cleaned.replacingOccurrences(
            of: #"\[/?[A-Z]+(?:\s+[^\]]*)?\]"#,
            with: " ",
            options: .regularExpression
        )

        // Strip markdown bold/italic markers
        cleaned = cleaned.replacingOccurrences(
            of: #"\*{1,2}([^*]+)\*{1,2}"#,
            with: "$1",
            options: .regularExpression
        )

        // Strip ## section headings (just remove the # marks, keep the text)
        cleaned = cleaned.replacingOccurrences(
            of: #"^#{1,3}\s*"#,
            with: "",
            options: [.regularExpression, .anchored]
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\n#{1,3}\s*"#,
            with: " ",
            options: .regularExpression
        )

        // Collapse whitespace + trim
        cleaned = cleaned
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "New conversation" }
        return String(cleaned.prefix(140))
    }
}
