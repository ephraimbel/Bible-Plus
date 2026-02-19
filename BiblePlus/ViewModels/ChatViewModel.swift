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

// MARK: - Chat Reaction

enum ChatReaction: String, CaseIterable {
    case heart
    case pray
    case bookmark

    var icon: String {
        switch self {
        case .heart: "heart.fill"
        case .pray: "hands.sparkles.fill"
        case .bookmark: "bookmark.fill"
        }
    }

    var label: String {
        switch self {
        case .heart: "Love"
        case .pray: "Pray"
        case .bookmark: "Save"
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
    var isChunkTyping: Bool = false
    var errorMessage: String? = nil
    var initialContext: String? = nil
    var followUpSuggestions: [String] = []
    var shareText: String? = nil
    let conversationId: UUID

    // Reactions (in-memory, display-only)
    var messageReactions: [UUID: ChatReaction] = [:]

    // Premium enhancements
    var selectedPromptCategory: PromptCategory? = nil
    var failedMessageContent: String? = nil
    var failedMessageId: UUID? = nil
    var savedToJournalMessageIDs: Set<UUID> = []
    var showSavedToJournalToast: Bool = false

    // MARK: - Private

    private let modelContext: ModelContext
    private let personalizationService: PersonalizationService
    private var streamingTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var chunkTask: Task<Void, Never>?

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
            && !isChunkTyping
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

    // MARK: - Quick Prompts (Category-Aware)

    var quickPrompts: [(icon: String, text: String)] {
        if let category = selectedPromptCategory {
            return categoryPrompts(for: category)
        }
        // Default: 1 from each category
        return PromptCategory.allCases.compactMap { categoryPrompts(for: $0).first }
    }

    private func categoryPrompts(for category: PromptCategory) -> [(icon: String, text: String)] {
        let burden = profile.currentBurdens.first ?? .none
        let season = profile.lifeSeasons.first

        switch category {
        case .scripture:
            return [
                (icon: "book.fill", text: "Where should I start reading the Bible today?"),
                (icon: "text.magnifyingglass", text: "Explain a difficult passage to me in simple terms."),
                (icon: "bookmark.fill", text: "What are the most comforting verses for \(burden.displayName.lowercased())?"),
                (icon: "sparkles", text: "Show me a verse that will strengthen my faith right now."),
            ]
        case .prayer:
            var prompts: [(icon: String, text: String)] = [
                (icon: "hands.sparkles", text: "Pray with me \u{2014} I just need to talk to God right now."),
            ]
            if let s = season {
                prompts.append((icon: "person.fill", text: "Pray with me for this season of \(s.displayName.lowercased())."))
            } else {
                prompts.append((icon: "person.fill", text: "Write a prayer of gratitude for today's blessings."))
            }
            prompts.append((icon: "moon.stars", text: "Help me write an evening prayer before bed."))
            prompts.append((icon: "sunrise", text: "Lead me in a morning prayer to start the day."))
            return prompts
        case .guidance:
            var prompts: [(icon: String, text: String)] = []
            if burden != .none {
                prompts.append((icon: "heart.fill", text: "I'm struggling with \(burden.displayName.lowercased()). What does God say about this?"))
            } else {
                prompts.append((icon: "heart.fill", text: "How do I hear God's voice in my daily life?"))
            }
            prompts.append((icon: "arrow.triangle.branch", text: "I'm facing a tough decision. Help me think through it biblically."))
            prompts.append((icon: "figure.walk", text: "How do I grow closer to God in this season?"))
            prompts.append((icon: "shield.checkered", text: "What does the Bible say about overcoming fear?"))
            return prompts
        case .theology:
            return [
                (icon: "lightbulb.fill", text: "What is the significance of grace in the Bible?"),
                (icon: "questionmark.circle", text: "Help me understand the Trinity in simple terms."),
                (icon: "text.book.closed", text: "What's the difference between the Old and New Covenant?"),
                (icon: "brain.head.profile", text: "Why does God allow suffering?"),
            ]
        }
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

    // MARK: - Reactions

    func toggleReaction(_ reaction: ChatReaction, for messageId: UUID) {
        if messageReactions[messageId] == reaction {
            messageReactions[messageId] = nil
        } else {
            messageReactions[messageId] = reaction
            HapticService.lightImpact()
        }
    }

    // MARK: - Sending

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming, !isChunkTyping else { return }

        if isRateLimited {
            errorMessage = AIError.rateLimited.errorDescription
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

        try? modelContext.save()
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
        chunkTask?.cancel()
        chunkTask = nil
        isStreaming = false
        isChunkTyping = false
        try? modelContext.save()
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

    // MARK: - Prayer Detection & Save to Journal

    func messageContainsPrayer(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant,
              !isStreaming,
              !isChunkTyping,
              !savedToJournalMessageIDs.contains(message.id)
        else { return false }

        let lower = message.content.lowercased()
        let prayerMarkers = [
            "amen", "heavenly father", "dear god", "dear lord",
            "in jesus' name", "in jesus\u{2019} name", "in christ's name",
            "we pray", "i pray", "lord, we", "lord, i",
            "gracious god", "almighty god", "holy spirit",
        ]
        return prayerMarkers.contains { lower.contains($0) }
    }

    func savePrayerToJournal(_ message: ChatMessage) {
        let content = message.content
        let title = extractPrayerTitle(from: content)
        let category = detectPrayerCategory(content)

        // Extract verse reference if present
        let refPattern = #"(?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?"#
        let verseRef: String?
        if let regex = try? NSRegularExpression(pattern: refPattern),
           let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)),
           let range = Range(match.range, in: content) {
            verseRef = String(content[range])
        } else {
            verseRef = nil
        }

        let entry = PrayerEntry(
            title: title,
            body: content,
            category: category,
            verseReference: verseRef
        )
        modelContext.insert(entry)
        savedToJournalMessageIDs.insert(message.id)
        try? modelContext.save()

        ActivityService.log(.prayerWritten, detail: title, in: modelContext)
        HapticService.success()

        showSavedToJournalToast = true
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showSavedToJournalToast = false
        }
    }

    private func extractPrayerTitle(from content: String) -> String {
        // Use first meaningful line, stripped of markdown
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let first = lines.first {
            var title = first
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if title.count > 50 {
                title = String(title.prefix(47)) + "..."
            }
            return title
        }
        return "Prayer from AI Companion"
    }

    private func detectPrayerCategory(_ content: String) -> PrayerCategory {
        let lower = content.lowercased()

        let patterns: [(PrayerCategory, [String])] = [
            (.gratitude, ["thank you", "grateful", "thankful", "gratitude", "bless", "appreciate"]),
            (.praise, ["praise", "worship", "glory", "hallelujah", "magnify", "exalt"]),
            (.confession, ["forgive", "confess", "repent", "sorry", "fallen short", "mercy"]),
            (.intercession, ["pray for", "lift up", "on behalf", "intercede", "watch over them"]),
            (.lament, ["weep", "sorrow", "grief", "pain", "suffering", "broken", "cry out"]),
        ]

        var bestMatch: PrayerCategory = .petition
        var bestCount = 0

        for (category, keywords) in patterns {
            let count = keywords.filter { lower.contains($0) }.count
            if count > bestCount {
                bestCount = count
                bestMatch = category
            }
        }

        return bestMatch
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
        try? modelContext.save()
    }

    // MARK: - Streaming

    private func streamResponse(for assistantMessage: ChatMessage) async {
        let systemPrompt = AIService.buildSystemPrompt(for: profile)

        var apiMessages: [(role: String, content: String)] = [
            (role: "system", content: systemPrompt)
        ]

        let recentMessages = messages.suffix(21).dropLast()
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
            try await AIService.streamCompletion(messages: apiMessages) { token in
                assistantMessage.content += token
            }

            let (cleaned, suggestions) = AIService.extractSuggestions(from: assistantMessage.content)
            if !suggestions.isEmpty {
                assistantMessage.content = cleaned
                followUpSuggestions = suggestions
            }

            isStreaming = false
            try? modelContext.save()

            // Chunked delivery
            await deliverChunked(assistantMessage: assistantMessage)
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
            try? modelContext.save()
        }
    }

    // MARK: - Chunked Delivery

    private func deliverChunked(assistantMessage: ChatMessage) async {
        let fullContent = assistantMessage.content
        let paragraphs = fullContent
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Only chunk if 3+ paragraphs
        guard paragraphs.count >= 3 else { return }

        // Group into 2-3 chunks
        let chunks: [String]
        if paragraphs.count <= 4 {
            // 3-4 paragraphs → 2 chunks
            let mid = paragraphs.count / 2
            chunks = [
                paragraphs[0..<mid].joined(separator: "\n\n"),
                paragraphs[mid...].joined(separator: "\n\n"),
            ]
        } else {
            // 5+ paragraphs → 3 chunks
            let third = paragraphs.count / 3
            let twoThirds = third * 2
            chunks = [
                paragraphs[0..<third].joined(separator: "\n\n"),
                paragraphs[third..<twoThirds].joined(separator: "\n\n"),
                paragraphs[twoThirds...].joined(separator: "\n\n"),
            ]
        }

        guard chunks.count >= 2 else { return }

        // Remove the full assistant message from display
        if let idx = displayMessages.lastIndex(where: { $0.id == assistantMessage.id }) {
            displayMessages.remove(at: idx)
        }

        // Show first chunk immediately (same ID as original)
        assistantMessage.content = chunks[0]
        displayMessages.append(assistantMessage)

        // Deliver remaining chunks with typing indicator between each
        for (i, chunk) in chunks.dropFirst().enumerated() {
            isChunkTyping = true

            let delay = UInt64.random(in: 600_000_000...1_200_000_000) // 600-1200ms
            try? await Task.sleep(nanoseconds: delay)

            guard !Task.isCancelled else {
                isChunkTyping = false
                // Restore full content if cancelled
                assistantMessage.content = fullContent
                rebuildDisplayMessages()
                return
            }

            isChunkTyping = false

            let isLast = i == chunks.count - 2

            if isLast {
                // Last chunk: create a virtual message but keep original ID for prayer detection
                let virtualMessage = ChatMessage(
                    conversationId: conversationId,
                    role: .assistant,
                    content: chunk
                )
                // Don't persist — display only
                displayMessages.append(virtualMessage)
            } else {
                let virtualMessage = ChatMessage(
                    conversationId: conversationId,
                    role: .assistant,
                    content: chunk
                )
                displayMessages.append(virtualMessage)
            }
        }

        // Restore full content in the persisted message for future loads
        assistantMessage.content = fullContent
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
