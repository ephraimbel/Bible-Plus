import Foundation
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var errorMessage: String? = nil
    var initialContext: String? = nil
    var followUpSuggestions: [String] = []
    var shareText: String? = nil
    let conversationId: UUID

    // MARK: - Private

    private let modelContext: ModelContext
    private let personalizationService: PersonalizationService
    private var streamingTask: Task<Void, Never>?

    // MARK: - Computed

    var profile: UserProfile {
        personalizationService.getOrCreateProfile()
    }

    var userName: String {
        let name = profile.firstName
        return name.isEmpty ? "Friend" : name
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isStreaming
    }

    private var allMessages: [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var messagesUsedThisWeek: Int {
        AIService.messagesUsedThisWeek(messages: allMessages)
    }

    var isRateLimited: Bool {
        !AIService.canSendMessage(messages: allMessages, isPro: profile.isPro)
    }

    var remainingMessages: Int {
        max(0, AIService.freeMessagesPerWeek - messagesUsedThisWeek)
    }

    var quickPrompts: [String] {
        var prompts: [String] = []
        if let burden = profile.currentBurdens.first, burden != .none {
            prompts.append("I'm struggling with \(burden.displayName.lowercased()). What does God say about this?")
        }
        if let season = profile.lifeSeasons.first {
            prompts.append("Pray with me for this season of \(season.displayName.lowercased()).")
        }
        prompts.append("Pray with me \u{2014} I just need to talk to God right now.")
        prompts.append("Where should I start reading the Bible today?")
        return Array(prompts.prefix(4))
    }

    // MARK: - Init

    init(modelContext: ModelContext, conversationId: UUID, initialContext: String? = nil) {
        self.modelContext = modelContext
        self.conversationId = conversationId
        self.personalizationService = PersonalizationService(modelContext: modelContext)
        self.initialContext = initialContext
        loadMessages()
    }

    // MARK: - Message Loading

    func loadMessages() {
        let convId = conversationId
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.conversationId == convId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        messages = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Sending

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        if isRateLimited {
            errorMessage = AIError.rateLimited.errorDescription
            return
        }

        errorMessage = nil
        followUpSuggestions = []

        // Add user message
        let userMessage = ChatMessage(
            conversationId: conversationId,
            role: .user,
            content: text
        )
        modelContext.insert(userMessage)
        messages.append(userMessage)
        inputText = ""

        // Update conversation title from first user message
        updateConversationMeta(from: text)

        try? modelContext.save()

        // Start streaming
        let assistantMessage = ChatMessage(
            conversationId: conversationId,
            role: .assistant,
            content: ""
        )
        modelContext.insert(assistantMessage)
        messages.append(assistantMessage)
        isStreaming = true

        streamingTask?.cancel()
        streamingTask = Task {
            await streamResponse(for: assistantMessage)
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        try? modelContext.save()
    }

    func sendQuickPrompt(_ prompt: String) {
        inputText = prompt
        send()
    }

    // MARK: - Context from Feed/Bible

    func applyInitialContext() {
        guard let context = initialContext, !context.isEmpty else { return }
        initialContext = nil
        inputText = context
    }

    // MARK: - Save / Share AI Response

    func saveResponse(_ message: ChatMessage) {
        let content = PrayerContent(
            type: .devotional,
            templateText: message.content,
            category: "AI Companion",
            isSaved: true
        )
        modelContext.insert(content)
        try? modelContext.save()
        HapticService.success()
    }

    func prepareShare(_ message: ChatMessage) {
        shareText = message.content
    }

    // MARK: - Scripture Navigation

    func navigateToScripture(bookName: String, chapter: Int) {
        // Post notification for ContentView to handle tab switch + navigation
        NotificationCenter.default.post(
            name: .scriptureDeepLink,
            object: nil,
            userInfo: ["bookName": bookName, "chapter": chapter]
        )
    }

    // MARK: - Clear

    func clearConversation() {
        for message in messages {
            modelContext.delete(message)
        }
        messages.removeAll()

        if let conv = fetchConversation() {
            modelContext.delete(conv)
        }
        try? modelContext.save()
    }

    // MARK: - Streaming

    private func streamResponse(for assistantMessage: ChatMessage) async {
        let systemPrompt = AIService.buildSystemPrompt(for: profile)

        // Build message history (last 20 messages + system prompt)
        var apiMessages: [(role: String, content: String)] = [
            (role: "system", content: systemPrompt)
        ]

        let recentMessages = messages.suffix(21).dropLast() // Exclude the empty assistant message
        for msg in recentMessages {
            apiMessages.append((role: msg.role.rawValue, content: msg.content))
        }

        // Prayer intent detection: inject prayer-mode system message
        if let lastUserMsg = recentMessages.last(where: { $0.role == .user }),
           AIService.detectsPrayerIntent(lastUserMsg.content) {
            let prayerPrompt = AIService.buildPrayerSystemPrompt(for: profile)
            apiMessages.append((role: "system", content: prayerPrompt))
        }

        do {
            try await AIService.streamCompletion(messages: apiMessages) { token in
                assistantMessage.content += token
            }

            // Extract follow-up suggestions from the response
            let (cleaned, suggestions) = AIService.extractSuggestions(from: assistantMessage.content)
            if !suggestions.isEmpty {
                assistantMessage.content = cleaned
                followUpSuggestions = suggestions
            }
        } catch {
            if assistantMessage.content.isEmpty {
                assistantMessage.content = "I'm sorry, I couldn't respond right now. Please try again."
            }
            errorMessage = error.localizedDescription
        }

        isStreaming = false
        try? modelContext.save()
    }

    // MARK: - Private

    private func fetchConversation() -> Conversation? {
        let convId = conversationId
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == convId }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func updateConversationMeta(from text: String) {
        guard let conversation = fetchConversation() else { return }

        if conversation.title == "New Conversation" {
            conversation.title = String(text.prefix(40))
        }
        conversation.updatedAt = Date()
    }
}
