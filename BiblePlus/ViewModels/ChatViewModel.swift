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

    var messagesUsedToday: Int {
        AIService.messagesUsedToday(messages: messages)
    }

    var isRateLimited: Bool {
        !AIService.canSendMessage(messages: messages, isPro: profile.isPro)
    }

    var remainingMessages: Int {
        max(0, AIService.freeMessageLimit - messagesUsedToday)
    }

    var quickPrompts: [String] {
        var prompts: [String] = []
        if let burden = profile.currentBurdens.first, burden != .none {
            prompts.append("What does the Bible say about \(burden.displayName.lowercased())?")
        }
        if let season = profile.lifeSeasons.first {
            prompts.append("Give me a prayer for a \(season.displayName.lowercased()).")
        }
        prompts.append("What should I read in the Bible today?")
        prompts.append("Help me understand God's love for me.")
        return Array(prompts.prefix(4))
    }

    // MARK: - Init

    init(modelContext: ModelContext, initialContext: String? = nil) {
        self.modelContext = modelContext
        self.personalizationService = PersonalizationService(modelContext: modelContext)
        self.initialContext = initialContext
        loadMessages()
    }

    // MARK: - Message Loading

    func loadMessages() {
        let descriptor = FetchDescriptor<ChatMessage>(
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

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        modelContext.insert(userMessage)
        messages.append(userMessage)
        inputText = ""
        try? modelContext.save()

        // Start streaming
        let assistantMessage = ChatMessage(role: .assistant, content: "")
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

    // MARK: - Context from Feed

    func applyInitialContext() {
        guard let context = initialContext, !context.isEmpty else { return }
        initialContext = nil
        inputText = context
    }

    // MARK: - Clear

    func clearConversation() {
        for message in messages {
            modelContext.delete(message)
        }
        messages.removeAll()
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

        do {
            try await AIService.streamCompletion(messages: apiMessages) { token in
                assistantMessage.content += token
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
}
