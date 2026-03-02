import Foundation
import SwiftData

// MARK: - Prompt Category

enum PromptCategory: String, CaseIterable, Identifiable {
    case scripture
    case prayer
    case guidance
    case theology

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scripture: "book.fill"
        case .prayer: "hands.sparkles"
        case .guidance: "heart.fill"
        case .theology: "lightbulb.fill"
        }
    }

    var displayName: String {
        switch self {
        case .scripture: "Scripture"
        case .prayer: "Prayer"
        case .guidance: "Guidance"
        case .theology: "Theology"
        }
    }
}

@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var displayMessages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var errorMessage: String? = nil
    var initialContext: String? = nil
    var followUpSuggestions: [String] = []
    var shareText: String? = nil
    let conversationId: UUID

    // Premium enhancements
    var selectedPromptCategory: PromptCategory? = nil
    var promptSeed: Int = 0
    var failedMessageContent: String? = nil
    var failedMessageId: UUID? = nil
    var shouldShowPaywall: Bool = false

    // MARK: - Private

    private let modelContext: ModelContext
    private let personalizationService: PersonalizationService
    private var streamingTask: Task<Void, Never>?
    private var tokenBuffer: String = ""
    private var bufferDrainTask: Task<Void, Never>?
    private var isSending: Bool = false

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

    /// Count of user messages sent this week, queried with a date predicate to avoid loading all messages.
    private var userMessagesThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.createdAt >= startOfWeek }
        )
        let recentMessages = (try? modelContext.fetch(descriptor)) ?? []
        return recentMessages.filter { $0.role == .user }.count
    }

    var messagesUsedThisWeek: Int {
        userMessagesThisWeek
    }

    var isRateLimited: Bool {
        let limit = profile.isPro ? AIService.proMessagesPerWeek : AIService.freeMessagesPerWeek
        return userMessagesThisWeek >= limit
    }

    var remainingMessages: Int {
        max(0, AIService.freeMessagesPerWeek - userMessagesThisWeek)
    }

    // MARK: - Typing Context Label

    var typingContextLabel: String? {
        guard let lastUserMsg = messages.last(where: { $0.role == .user }) else { return nil }
        if AIService.detectsPrayerIntent(lastUserMsg.content) {
            return "Composing a prayer..."
        }
        let lower = lastUserMsg.content.lowercased()
        let scriptureKeywords = ["verse", "chapter", "genesis", "exodus", "psalm", "proverbs",
                                 "matthew", "john", "romans", "corinthians", "revelation", "scripture", "bible"]
        if scriptureKeywords.contains(where: { lower.contains($0) }) {
            return "Reflecting on Scripture..."
        }
        if let conv = fetchConversation(), conv.character != nil {
            return "Speaking as \(conv.character!.displayName)..."
        }
        return nil
    }

    // MARK: - Date Dividers

    func dateDividerLabel(for message: ChatMessage, at index: Int) -> String? {
        let calendar = Calendar.current
        let messageDate = message.createdAt

        if index == 0 {
            return formattedDateLabel(messageDate)
        }

        let previousDate = displayMessages[index - 1].createdAt
        if !calendar.isDate(messageDate, inSameDayAs: previousDate) {
            return formattedDateLabel(messageDate)
        }
        return nil
    }

    private func formattedDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    // MARK: - Quick Prompts (Dynamic, Engine-Driven)

    var quickPrompts: [(icon: String, text: String)] {
        // promptSeed is read to force SwiftUI re-evaluation on refresh
        _ = promptSeed
        let topics = QuickPromptEngine.extractRecentTopics(from: modelContext)
        return QuickPromptEngine.selectPrompts(
            for: profile,
            category: selectedPromptCategory,
            chatTopics: topics
        )
    }

    func refreshPrompts() {
        promptSeed += 1
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
        rebuildDisplayMessages()
    }

    private func rebuildDisplayMessages() {
        displayMessages = messages
    }

    // MARK: - Sending

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming, !isSending else { return }
        isSending = true
        defer { isSending = false }

        if isRateLimited {
            shouldShowPaywall = true
            return
        }

        errorMessage = nil
        failedMessageContent = nil
        failedMessageId = nil
        followUpSuggestions = []

        // Add user message
        let userMessage = ChatMessage(
            conversationId: conversationId,
            role: .user,
            content: text
        )
        modelContext.insert(userMessage)
        messages.append(userMessage)
        displayMessages.append(userMessage)
        inputText = ""

        // Update conversation title from first user message
        updateConversationMeta(from: text)

        do { try modelContext.save() } catch { print("[ChatVM] Save failed: \(error)") }
        ActivityService.log(.aiChatSent, detail: String(text.prefix(50)), in: modelContext)

        // Start streaming
        let assistantMessage = ChatMessage(
            conversationId: conversationId,
            role: .assistant,
            content: ""
        )
        modelContext.insert(assistantMessage)
        messages.append(assistantMessage)
        displayMessages.append(assistantMessage)
        isStreaming = true

        streamingTask?.cancel()
        streamingTask = Task {
            await streamResponse(for: assistantMessage)
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        bufferDrainTask?.cancel()
        bufferDrainTask = nil

        // Flush any remaining buffered tokens into the last assistant message
        if !tokenBuffer.isEmpty, let lastAssistant = messages.last(where: { $0.role == .assistant }) {
            lastAssistant.content += tokenBuffer
        }
        tokenBuffer = ""

        isStreaming = false
        do { try modelContext.save() } catch { print("[ChatVM] Save error on stop: \(error)") }
    }

    func sendQuickPrompt(_ prompt: String) {
        inputText = prompt
        send()
    }

    // MARK: - Retry

    func retryLastMessage() {
        guard let content = failedMessageContent else { return }
        failedMessageContent = nil
        failedMessageId = nil
        errorMessage = nil
        inputText = content
        send()
    }

    // MARK: - Mode & Character

    var conversationMode: ConversationMode? {
        fetchConversation()?.mode
    }

    var conversationCharacter: BiblicalCharacter? {
        fetchConversation()?.character
    }

    func setConversationMode(_ mode: ConversationMode) {
        guard let conversation = fetchConversation() else { return }
        conversation.mode = mode
        conversation.updatedAt = Date()
        do { try modelContext.save() } catch { print("[ChatVM] Save failed: \(error)") }
    }

    func startCharacterConversation(_ character: BiblicalCharacter) {
        guard let conversation = fetchConversation() else { return }
        conversation.character = character
        conversation.title = "Conversation with \(character.displayName)"
        conversation.updatedAt = Date()
        do { try modelContext.save() } catch { print("[ChatVM] Save failed: \(error)") }

        sendQuickPrompt("Hello \(character.displayName), I'd like to talk with you about what's on my heart.")
    }

    // MARK: - Context from Feed/Bible

    func applyInitialContext() {
        guard let context = initialContext, !context.isEmpty else { return }
        initialContext = nil
        sendQuickPrompt(context)
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
        do { try modelContext.save() } catch { print("[ChatVM] Save failed: \(error)") }
        HapticService.success()
    }

    func prepareShare(_ message: ChatMessage) {
        shareText = message.content
    }

    // MARK: - Scripture Navigation

    func navigateToScripture(bookName: String, chapter: Int, verse: Int = 0) {
        NotificationCenter.default.post(
            name: .scriptureDeepLink,
            object: nil,
            userInfo: ["bookName": bookName, "chapter": chapter, "verse": verse]
        )
    }

    // MARK: - Clear

    func clearConversation() {
        for message in messages {
            modelContext.delete(message)
        }
        messages.removeAll()
        displayMessages.removeAll()

        if let conv = fetchConversation() {
            modelContext.delete(conv)
        }
        do { try modelContext.save() } catch { print("[ChatVM] Save failed: \(error)") }
    }

    // MARK: - Streaming

    private func streamResponse(for assistantMessage: ChatMessage) async {
        var systemPrompt = AIService.buildSystemPrompt(for: profile)

        // Inject character persona (first priority)
        if let conversation = fetchConversation(), let character = conversation.character {
            systemPrompt += "\n\n" + AIService.characterPersona(for: character)
        }

        // Inject mode overlay (stacks with character)
        if let conversation = fetchConversation(), let mode = conversation.mode {
            let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
            systemPrompt += "\n\n" + AIService.modeOverlay(for: mode, name: name)
        }

        var apiMessages: [(role: String, content: String)] = [
            (role: "system", content: systemPrompt)
        ]

        let recentMessages = messages.suffix(11).dropLast()
        for msg in recentMessages {
            apiMessages.append((role: msg.role.rawValue, content: msg.content))
        }

        // Prayer intent detection
        if let lastUserMsg = recentMessages.last(where: { $0.role == .user }),
           AIService.detectsPrayerIntent(lastUserMsg.content) {
            let prayerPrompt = AIService.buildPrayerSystemPrompt(for: profile)
            apiMessages.append((role: "system", content: prayerPrompt))
        }

        do {
            // Start the buffer drain loop — releases characters smoothly
            startBufferDrain(into: assistantMessage)

            try await AIService.streamCompletion(messages: apiMessages) { token in
                self.tokenBuffer += token
            }

            // Wait for buffer to fully drain
            await drainRemainingBuffer(into: assistantMessage)

            let (cleaned, suggestions) = AIService.extractSuggestions(from: assistantMessage.content)
            if !suggestions.isEmpty {
                assistantMessage.content = cleaned
            }

            isStreaming = false

            if !suggestions.isEmpty {
                followUpSuggestions = suggestions
            }

            do { try modelContext.save() } catch { print("[ChatVM] Save failed: \(error)") }
        } catch {
            if assistantMessage.content.isEmpty {
                // Store the last user message content for retry
                let lastUserContent = messages.last(where: { $0.role == .user })?.content
                modelContext.delete(assistantMessage)
                if let idx = messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                    messages.remove(at: idx)
                }
                if let idx = displayMessages.lastIndex(where: { $0.id == assistantMessage.id }) {
                    displayMessages.remove(at: idx)
                }
                failedMessageContent = lastUserContent
                failedMessageId = messages.last(where: { $0.role == .user })?.id
            }
            errorMessage = error.localizedDescription
            isStreaming = false
            do { try modelContext.save() } catch { print("[ChatVM] Save failed: \(error)") }
        }
    }

    // MARK: - Token Buffer (smooth word-level reveal)

    /// Drains the token buffer one word at a time for a natural writing feel.
    private func startBufferDrain(into message: ChatMessage) {
        bufferDrainTask?.cancel()
        bufferDrainTask = Task {
            while !Task.isCancelled {
                if !tokenBuffer.isEmpty {
                    let word = extractNextWord()
                    if let word {
                        message.content += word
                    } else {
                        // Buffer has content but no word boundary yet — wait for more
                        try? await Task.sleep(nanoseconds: 25_000_000)
                        continue
                    }
                }
                // ~35ms between words ≈ natural reading pace
                try? await Task.sleep(nanoseconds: 35_000_000)
            }
        }
    }

    /// Pulls the next word (up to and including the space) from the buffer.
    private func extractNextWord() -> String? {
        guard !tokenBuffer.isEmpty else { return nil }
        // Look for a space to split on
        if let spaceIdx = tokenBuffer.firstIndex(of: " ") {
            let end = tokenBuffer.index(after: spaceIdx)
            let word = String(tokenBuffer[tokenBuffer.startIndex..<end])
            tokenBuffer.removeFirst(word.count)
            return word
        }
        // Look for newline
        if let nlIdx = tokenBuffer.firstIndex(of: "\n") {
            let end = tokenBuffer.index(after: nlIdx)
            let word = String(tokenBuffer[tokenBuffer.startIndex..<end])
            tokenBuffer.removeFirst(word.count)
            return word
        }
        // No boundary but buffer is large — flush a chunk to avoid stalling
        if tokenBuffer.count > 15 {
            let chunk = String(tokenBuffer.prefix(8))
            tokenBuffer.removeFirst(8)
            return chunk
        }
        return nil
    }

    /// Flushes remaining buffer after the stream finishes.
    private func drainRemainingBuffer(into message: ChatMessage) async {
        while !tokenBuffer.isEmpty {
            if let word = extractNextWord() {
                message.content += word
                try? await Task.sleep(nanoseconds: 35_000_000)
            } else {
                // Flush whatever's left
                message.content += tokenBuffer
                tokenBuffer = ""
            }
        }
        bufferDrainTask?.cancel()
        bufferDrainTask = nil
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
            conversation.title = text.count > 40
                ? String(text.prefix(40)) + "…"
                : text
        }
        conversation.updatedAt = Date()
    }
}
