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

    /// Count of user messages sent today across all conversations.
    /// Used for the Pro daily safety cap (200/day) — NOT for the free
    /// quota, which is now lifetime instead of per-day.
    private var userMessagesToday: Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.createdAt >= startOfDay }
        )
        let recentMessages = (try? modelContext.fetch(descriptor)) ?? []
        return recentMessages.filter { $0.role == .user }.count
    }

    /// All-time user messages that count toward the lifetime free quota.
    /// Every user message counts — including replies in the welcome
    /// conversation — so users hit the paywall while their first-session
    /// attachment is peaking instead of days later when they've cooled off.
    private var freeQuotaUsed: Int {
        let descriptor = FetchDescriptor<ChatMessage>()
        let allMessages = (try? modelContext.fetch(descriptor)) ?? []
        return allMessages.filter { $0.role == .user }.count
    }

    /// Surface for chat UI. For free users this is "lifetime quota used",
    /// for pro users it's "messages today" — the UI labels handle the
    /// distinction.
    var messagesUsedToday: Int {
        profile.isPro ? userMessagesToday : freeQuotaUsed
    }

    var isRateLimited: Bool {
        if profile.isPro {
            return userMessagesToday >= AIService.proMessagesPerDay
        }
        return freeQuotaUsed >= AIService.freeMessagesLifetime
    }

    var remainingMessages: Int {
        if profile.isPro {
            return max(0, AIService.proMessagesPerDay - userMessagesToday)
        }
        return max(0, AIService.freeMessagesLifetime - freeQuotaUsed)
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
        if let conv = fetchConversation() {
            if conv.character != nil {
                return "Speaking as \(conv.character!.displayName)..."
            }
            if conv.mode == .story {
                return "Narrating the story..."
            }
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
        let continuations = fetchRecentTopics()
        return QuickPromptEngine.selectPrompts(
            for: profile,
            category: selectedPromptCategory,
            chatTopics: topics,
            continuations: continuations
        )
    }

    private func fetchRecentTopics() -> [ConversationTopic] {
        var descriptor = FetchDescriptor<ConversationTopic>(
            sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        return (try? modelContext.fetch(descriptor)) ?? []
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
        // First-load detection: if this is the seeded welcome conversation
        // and its placeholder assistant message is still empty, kick off
        // the typewriter so the greeting streams in like a real reply.
        playWelcomeGreetingIfNeeded()
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

    // MARK: - Welcome Greeting Typewriter
    //
    // The seeded welcome conversation lands with ZERO ChatMessages — we
    // deliberately don't pre-create one in onboarding. When the user first
    // opens it, we detect (isOnboarding && messages.empty), build the
    // personalized greeting locally, and create a placeholder ChatMessage
    // **in memory only** — never inserted into the model context until
    // the typewriter completes.
    //
    // This guarantees the half-typed-message edge case can't happen:
    // - Mid-flight back-out → task continues in background, completes,
    //   inserts the finished message. User sees full message on reopen.
    // - App killed mid-flight → in-memory placeholder is destroyed without
    //   ever being persisted. On next launch the conversation is still
    //   empty → typewriter cleanly replays from scratch.
    // - Normal completion → message is inserted + saved at the end.

    private func playWelcomeGreetingIfNeeded() {
        guard let conversation = fetchConversation(),
              conversation.isOnboarding,
              messages.isEmpty
        else { return }

        let greeting = buildWelcomeGreetingText()
        guard !greeting.isEmpty else { return }

        Analytics.track(.welcomeConversationOpened)

        // Build the placeholder in-memory ONLY. Not inserted into the
        // model context — that happens at the end of the typewriter once
        // we know the full content is ready.
        let placeholder = ChatMessage(
            conversationId: conversationId,
            role: .assistant,
            content: ""
        )
        // Add to displayMessages so the UI renders it. NOT to `messages`
        // (that array is the persisted source of truth and should stay
        // empty until the typewriter completes and we insert).
        displayMessages.append(placeholder)
        isStreaming = true

        streamingTask?.cancel()
        streamingTask = Task { @MainActor in
            // Brief beat so the user sees the typing-dots state before the
            // first character lands. Feels intentional, not jarring.
            try? await Task.sleep(nanoseconds: 650_000_000)
            if Task.isCancelled { isStreaming = false; return }

            for char in greeting {
                if Task.isCancelled { return }
                placeholder.content.append(char)
                // Force the displayMessages slot to refresh — mutating the
                // @Model object alone doesn't trigger SwiftUI updates when
                // it isn't yet in a model context. Reassigning the array
                // slot bumps the @Observable change.
                if let idx = displayMessages.firstIndex(where: { $0.id == placeholder.id }) {
                    displayMessages[idx] = placeholder
                }

                // Natural cadence: longer pauses at sentence breaks, short
                // beats at commas, ~22ms per regular character. Same
                // rhythm as `TypewriterText` so the feel is consistent
                // with the onboarding chat bubbles.
                let delay: UInt64
                switch char {
                case ".", "!", "?": delay = 240_000_000
                case ",", ";", ":": delay = 100_000_000
                case "\n":          delay = 300_000_000
                default:            delay = 22_000_000
                }
                try? await Task.sleep(nanoseconds: delay)
            }

            // Typewriter finished cleanly — NOW persist. Insert the same
            // placeholder instance into the model context (its content is
            // already populated), append to the messages array so the
            // source of truth catches up, then save.
            modelContext.insert(placeholder)
            messages.append(placeholder)
            try? modelContext.save()
            isStreaming = false
            Analytics.track(.welcomeTypewriterCompleted)

            // Populate follow-up suggestions tailored to the user's
            // burden so they can tap to respond without thinking of
            // what to say. These show as the existing suggestion
            // bubbles below the message.
            followUpSuggestions = Self.welcomeSuggestions(for: profile)
        }
    }

    /// Returns 3 tap-to-reply suggestions tailored to the user's top
    /// burden. Each one is a natural first message that feels like a
    /// real person responding to the AI's greeting.
    private static func welcomeSuggestions(for profile: UserProfile) -> [String] {
        let topBurden = profile.currentBurdens
            .sorted(by: { $0.rawValue < $1.rawValue })
            .first ?? .none

        switch topBurden {
        case .anxiety:
            return [
                "I've been really anxious lately",
                "Send me a verse about peace",
                "Pray with me about my worry",
            ]
        case .grief:
            return [
                "I'm walking through a loss right now",
                "Send me a verse about comfort",
                "Pray with me about my grief",
            ]
        case .doubt:
            return [
                "I've been struggling with doubt",
                "Help me understand faith better",
                "Send me a verse about trust",
            ]
        case .loneliness:
            return [
                "I've been feeling really alone",
                "Send me a verse about God's presence",
                "Pray with me about loneliness",
            ]
        case .anger:
            return [
                "I've been carrying a lot of anger",
                "Send me a verse about patience",
                "Help me work through this frustration",
            ]
        case .temptation:
            return [
                "I'm struggling with temptation",
                "Send me a verse about strength",
                "Pray with me for self-control",
            ]
        case .health:
            return [
                "I'm dealing with health concerns",
                "Send me a verse about healing",
                "Pray with me about my health",
            ]
        case .financial:
            return [
                "I'm stressed about finances",
                "Send me a verse about provision",
                "Help me trust God with money",
            ]
        case .relationship:
            return [
                "I'm going through relationship pain",
                "Send me a verse about love",
                "Pray with me about my relationships",
            ]
        case .purpose:
            return [
                "I'm searching for my purpose",
                "Send me a verse about calling",
                "Help me find direction",
            ]
        case .none:
            return [
                "Send me a verse to start my day",
                "Tell me a story from the Bible",
                "Pray with me",
            ]
        }
    }

    /// Builds the personalized welcome greeting from the user's profile.
    /// Generated locally — no API call. Every burden and life season has
    /// its own hand-tuned phrase so the sentence reads naturally for any
    /// combination the user might pick. Two top-level templates: one for
    /// users carrying something specific, one for users who selected
    /// "nothing specific" (the latter gets a no-agenda welcome instead of
    /// the "that's a lot to hold" line).
    private func buildWelcomeGreetingText() -> String {
        let p = profile
        let name = p.firstName.trimmingCharacters(in: .whitespaces)
        let safeName = name.isEmpty ? "friend" : name

        let topBurden = p.currentBurdens
            .sorted(by: { $0.rawValue < $1.rawValue })
            .first
        let topSeason = p.lifeSeasons
            .sorted(by: { $0.rawValue < $1.rawValue })
            .first

        let seasonClause = topSeason.map { Self.welcomeSeasonClause(for: $0) } ?? ""

        if let burden = topBurden, burden != .none {
            let burdenClause = Self.welcomeBurdenClause(for: burden)
            return """
            Hey \(safeName). I noticed you came in \(burdenClause)\(seasonClause). That's not nothing — and it's exactly why I'm here.

            Want to talk about what's on your heart right now, or would you rather I just send you a verse to start with?
            """
        } else {
            return """
            Hey \(safeName). I'm glad you're here\(seasonClause). No agenda — just whatever you need today.

            Want me to send you a verse to start with, or would you rather just talk?
            """
        }
    }

    /// Verb-led fragment that follows "I noticed you came in...". Each
    /// burden gets its own natural phrasing so the sentence never reads
    /// as awkward template-fill ("carrying purpose" doesn't work,
    /// "searching for purpose" does).
    private static func welcomeBurdenClause(for burden: Burden) -> String {
        switch burden {
        case .anxiety:      return "carrying some anxiety"
        case .grief:        return "walking through grief"
        case .doubt:        return "wrestling with doubt"
        case .loneliness:   return "sitting with loneliness"
        case .anger:        return "carrying some anger"
        case .temptation:   return "wrestling with temptation"
        case .health:       return "carrying health concerns"
        case .financial:    return "carrying financial stress"
        case .relationship: return "walking through relationship pain"
        case .purpose:      return "searching for purpose"
        case .none:         return "open to whatever this becomes"
        }
    }

    /// Connector phrase appended after the burden clause (or after
    /// "I'm glad you're here" in the no-burden template). Each life
    /// season gets its own natural connector so the sentence never reads
    /// as "in a season of married".
    private static func welcomeSeasonClause(for season: LifeSeason) -> String {
        switch season {
        case .student:             return " as a student"
        case .workingProfessional: return " while navigating working life"
        case .parent:              return " while raising a family"
        case .single:              return " in single life"
        case .married:             return " in marriage"
        case .retired:             return " in a season of rest"
        case .hardSeason:          return " through a hard season"
        case .startingOver:        return " while starting over"
        }
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
            Analytics.track(.aiRateLimitHit)
            shouldShowPaywall = true
            return
        }

        Analytics.track(.aiMessageSent)
        // First reply inside the seeded welcome conversation is the
        // single most important retention signal we measure — it tells us
        // the user actually engaged with the personalized greeting
        // instead of bouncing. Fires once per session at most because
        // we check `messages.isEmpty` before any user message exists.
        if let conv = fetchConversation(),
           conv.isOnboarding,
           messages.contains(where: { $0.role == .user }) == false {
            Analytics.track(.welcomeReplied)
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

        do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save failed: \(error)")
            #endif
        }
        ActivityService.log(.aiChatSent, detail: String(text.prefix(50)), in: modelContext)

        // Ask for review after the user's FIRST AI message — they've now
        // experienced the AI's response and can give an informed rating.
        // ReviewService internally gates frequency so this won't fire on
        // every message, just the first eligible one.
        let userMsgCount = messages.filter { $0.role == .user }.count
        if userMsgCount == 1 {
            ReviewService.shared.requestIfAppropriate()
        }

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
        do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save error on stop: \(error)")
            #endif
        }
    }

    func sendQuickPrompt(_ prompt: String) {
        inputText = prompt
        send()
    }

    // MARK: - Retry

    /// Retries the assistant response for the most recently failed message.
    /// Importantly: does NOT re-insert the user message — that message is
    /// already in the conversation from the original failed `send()`. We just
    /// spin up a fresh assistant message and re-stream against the existing
    /// history. (The previous implementation called `send()` which created a
    /// duplicate user message.)
    func retryLastMessage() {
        guard failedMessageContent != nil else { return }
        guard !isStreaming, !isSending else { return }

        // Confirm the failed user message is still present in the conversation.
        // If it's been deleted (e.g. clear conversation), bail out.
        guard messages.contains(where: { $0.role == .user && $0.id == failedMessageId }) else {
            failedMessageContent = nil
            failedMessageId = nil
            return
        }

        // Reset failure state so the retry banner disappears
        failedMessageContent = nil
        failedMessageId = nil
        errorMessage = nil

        if isRateLimited {
            Analytics.track(.aiRateLimitHit)
            shouldShowPaywall = true
            return
        }

        // Insert a fresh empty assistant message and start streaming
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
        do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save failed: \(error)")
            #endif
        }

        // Story mode gets an automatic opening prompt
        if mode == .story && messages.isEmpty {
            sendQuickPrompt("Take me into a biblical story. What do you recommend?")
        }
    }

    func startCharacterConversation(_ character: BiblicalCharacter) {
        guard let conversation = fetchConversation() else { return }
        conversation.character = character
        conversation.title = "Conversation with \(character.displayName)"
        conversation.updatedAt = Date()
        do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save failed: \(error)")
            #endif
        }

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
        let cleaned = Self.stripMarkup(message.content)
        guard !cleaned.isEmpty else { return }

        let content = PrayerContent(
            type: .devotional,
            templateText: cleaned,
            category: "AI Companion",
            isSaved: true
        )
        modelContext.insert(content)
        do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save failed: \(error)")
            #endif
        }
        HapticService.success()
    }

    /// Strips all card markup, tool results, markdown, follow-up markers,
    /// and section headings from raw AI content so saved items read as
    /// clean prose — not raw tag soup.
    static func stripMarkup(_ raw: String) -> String {
        var s = raw

        // Strip trailing |||suggestion||| follow-ups
        if let pipeRange = s.range(of: "|||") {
            s = String(s[..<pipeRange.lowerBound])
        }

        // Strip [TOOLRESULT]...[/TOOLRESULT] blocks entirely
        s = s.replacingOccurrences(
            of: #"\[TOOLRESULT(?:\s+[^\]]*)?\][\s\S]*?\[/TOOLRESULT\]"#,
            with: " ",
            options: .regularExpression
        )

        // Strip all other card tags (open + close), keeping body content
        s = s.replacingOccurrences(
            of: #"\[/?[A-Z]+(?:\s+[^\]]*)?\]"#,
            with: " ",
            options: .regularExpression
        )

        // Strip markdown bold/italic markers
        s = s.replacingOccurrences(
            of: #"\*{1,2}([^*]+)\*{1,2}"#,
            with: "$1",
            options: .regularExpression
        )

        // Strip ## section headings
        s = s.replacingOccurrences(
            of: #"^#{1,3}\s*"#,
            with: "",
            options: [.regularExpression, .anchored]
        )
        s = s.replacingOccurrences(
            of: #"\n#{1,3}\s*"#,
            with: "\n",
            options: .regularExpression
        )

        // Collapse whitespace + trim
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return s
    }

    func prepareShare(_ message: ChatMessage) {
        shareText = Self.stripMarkup(message.content)
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
        do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save failed: \(error)")
            #endif
        }
    }

    // MARK: - Streaming

    private func streamResponse(for assistantMessage: ChatMessage) async {
        var systemPrompt = AIService.buildSystemPrompt(for: profile)
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName

        // Inject long-term memory digest + pinned facts (the "what I know
        // about you" block). Takes priority over the topic-counter memory
        // because it's relational, not statistical. Pinned facts are
        // load-bearing — they appear in every system prompt forever.
        if let digestContext = AIService.buildMemoryDigestContext(
            digest: profile.aiMemoryDigest,
            pinnedFacts: profile.aiPinnedFacts,
            name: name
        ) {
            systemPrompt += "\n\n" + digestContext
        }

        // Inject pre-conversation briefing (today's date, current plan, last
        // read passage, recent thread titles). Refreshed every message — small
        // payload but keeps the AI grounded in what's happening right now.
        if let briefing = AIService.buildPreConversationBriefing(
            profile: profile,
            modelContext: modelContext,
            currentConversationId: conversationId,
            name: name
        ) {
            systemPrompt += "\n\n" + briefing
        }

        // Inject conversation memory (topic history) as a complement
        if let memory = AIService.buildMemoryContext(from: modelContext, name: name) {
            systemPrompt += "\n\n" + memory
        }

        // Inject character persona (first priority)
        if let conversation = fetchConversation(), let character = conversation.character {
            systemPrompt += "\n\n" + AIService.characterPersona(for: character)
        }

        // Inject mode overlay (stacks with character)
        if let conversation = fetchConversation(), let mode = conversation.mode {
            systemPrompt += "\n\n" + AIService.modeOverlay(for: mode, name: name)
            // Per-mode follow-up tightening — tailors the |||...||| line to
            // the emotional register of the current mode (comfort/teach/etc).
            if let followUpRules = AIService.followUpRules(for: mode, name: name) {
                systemPrompt += "\n\n" + followUpRules
            }
        }

        // Build the API conversation context as APIMessage values so the
        // tool-aware streaming path can splice in assistant tool_calls and
        // tool result messages between turns.
        var apiMessages: [APIMessage] = [.system(systemPrompt)]

        let recentMessages = messages.suffix(11).dropLast()
        for msg in recentMessages {
            switch msg.role {
            case .user:
                apiMessages.append(.user(msg.content))
            case .assistant:
                apiMessages.append(.assistant(msg.content))
            case .system:
                apiMessages.append(.system(msg.content))
            }
        }

        // Prayer intent detection
        if let lastUserMsg = recentMessages.last(where: { $0.role == .user }),
           AIService.detectsPrayerIntent(lastUserMsg.content) {
            let prayerPrompt = AIService.buildPrayerSystemPrompt(for: profile)
            apiMessages.append(.system(prayerPrompt))
        }

        // Multi-turn tool loop. Each iteration calls the model once. If the
        // model returns finish_reason="tool_calls", we execute each tool,
        // append the human summary as a [TOOLRESULT] marker to the streamed
        // content (so it renders as an inline card), feed the tool result
        // back into the API context, and loop. Capped to keep the agent from
        // chasing its tail forever.
        let maxToolRoundtrips = 4
        var roundtrip = 0

        do {
            // Start the buffer drain loop — releases characters smoothly
            startBufferDrain(into: assistantMessage)

            while true {
                let streamResult = try await AIService.streamCompletionWithTools(
                    messages: apiMessages,
                    tools: ChatTools.allDefinitions
                ) { token in
                    self.tokenBuffer += token
                }

                // No tool calls (or model decided to stop) → done streaming
                guard streamResult.finishReason == "tool_calls",
                      !streamResult.toolCalls.isEmpty
                else { break }

                roundtrip += 1
                if roundtrip > maxToolRoundtrips { break }

                // Record the assistant's tool_calls in the API history.
                // OpenAI requires the tool_calls message to come BEFORE the
                // matching tool result messages.
                apiMessages.append(.assistantWithToolCalls(
                    content: nil,
                    toolCalls: streamResult.toolCalls
                ))

                // Execute each tool, append a [TOOLRESULT] marker to the
                // streamed content via the token buffer (so it appears in the
                // right place relative to whatever text was streamed before
                // it), and add the tool result to the API context.
                for call in streamResult.toolCalls {
                    let toolResult = await ChatToolDispatcher.execute(
                        call: call,
                        modelContext: modelContext
                    )

                    // Sanitize the human summary so it can't break the
                    // marker syntax (e.g. a literal `[/TOOLRESULT]` in user
                    // content would close the tag prematurely).
                    let safeSummary = toolResult.humanSummary
                        .replacingOccurrences(of: "[", with: "(")
                        .replacingOccurrences(of: "]", with: ")")
                    let statusAttr = toolResult.isError ? "error" : "ok"
                    let marker = "\n\n[TOOLRESULT name=\"\(call.name)\" status=\"\(statusAttr)\"]\(safeSummary)[/TOOLRESULT]\n\n"
                    self.tokenBuffer += marker

                    apiMessages.append(.toolResult(toolResult.modelContent, callId: call.id))
                }
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

            // Extract and save conversation topics from the user's message
            if let lastUserMsg = messages.last(where: { $0.role == .user }) {
                AIService.extractAndSaveTopics(from: lastUserMsg.content, in: modelContext)
            }

            do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save failed: \(error)")
            #endif
        }

            // Background polish jobs — fire-and-forget so they don't delay
            // the user-visible response.
            scheduleAutoTitleIfNeeded(assistantContent: assistantMessage.content)
            scheduleMemoryDigestRefreshIfNeeded()
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
            do { try modelContext.save() } catch {
            #if DEBUG
            print("[ChatVM] Save failed: \(error)")
            #endif
        }
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

    // MARK: - Background Polish Jobs

    /// Fires an AI-generated conversation title after the FIRST assistant
    /// response completes. Only runs if the title is still the auto-truncation
    /// from the first user message (i.e. it hasn't been customized by other
    /// code paths). Idempotent: re-running on a conversation that already has
    /// a generated title is a no-op because the condition no longer holds.
    private func scheduleAutoTitleIfNeeded(assistantContent: String) {
        guard let conversation = fetchConversation() else { return }

        // Only generate a title once per conversation. We treat any title
        // distinct from the truncated first message as "already curated".
        let userMessageCount = messages.filter { $0.role == .user }.count
        guard userMessageCount == 1 else { return }

        guard let firstUser = messages.first(where: { $0.role == .user })?.content,
              !firstUser.isEmpty else { return }

        // Skip if user already manually titled, or if the conversation is a
        // character/mode-specific one (those have their own title formats).
        if conversation.character != nil { return }

        let conversationId = self.conversationId
        let cleanContent = assistantContent
        let firstUserCopy = firstUser

        Task.detached(priority: .background) { [weak self] in
            guard let title = await AIService.generateConversationTitle(
                userMessage: firstUserCopy,
                assistantReply: cleanContent
            ) else { return }

            await MainActor.run {
                guard let self else { return }
                // Re-fetch on the main actor — the conversation may have been
                // mutated or deleted while the title call was in flight.
                let descriptor = FetchDescriptor<Conversation>(
                    predicate: #Predicate { $0.id == conversationId }
                )
                guard let conv = (try? self.modelContext.fetch(descriptor))?.first else { return }
                conv.title = title
                conv.updatedAt = Date()
                try? self.modelContext.save()
            }
        }
    }

    /// Refreshes the user's long-term memory digest using messages from
    /// **all** conversations, not just the current thread. This is the
    /// difference between "memory within a session" and real cross-
    /// conversation memory. Throttled to keep cost minimal — runs on the
    /// cheap nano utility tier and is fire-and-forget.
    private func scheduleMemoryDigestRefreshIfNeeded() {
        // Bump the global counter every time we're called (after a user
        // message has been sent). The counter lives on the profile so it
        // crosses conversations naturally.
        profile.aiMessagesSinceDigestRefresh += 1
        try? modelContext.save()

        let sinceLast = profile.aiMessagesSinceDigestRefresh
        let hasNoDigest = (profile.aiMemoryDigest?.isEmpty ?? true)

        // Refresh cadence:
        //   - First-ever digest fires after 2 user messages (so the AI
        //     starts to "know" the user almost immediately).
        //   - After that, every 5 user messages globally — across all
        //     conversations, not just the current one.
        let shouldFire: Bool = hasNoDigest ? sinceLast >= 2 : sinceLast >= 5
        guard shouldFire else { return }

        // Snapshot the most recent 30 messages across ALL conversations,
        // sorted chronologically. This is the actual cross-conversation
        // memory: the digest model now sees the user's whole chat life,
        // not just the thread it happens to be running in.
        let descriptor: FetchDescriptor<ChatMessage> = {
            var d = FetchDescriptor<ChatMessage>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            d.fetchLimit = 30
            return d
        }()
        let recentReversed = (try? modelContext.fetch(descriptor)) ?? []
        let snapshot: [(role: String, content: String)] = recentReversed
            .reversed() // back to chronological order for the model
            .map { ($0.role.rawValue, $0.content) }

        guard !snapshot.isEmpty else { return }

        let firstNameCopy = profile.firstName.isEmpty ? "Friend" : profile.firstName
        let currentDigest = profile.aiMemoryDigest

        Task.detached(priority: .background) { [weak self] in
            let updated = await AIService.refreshMemoryDigest(
                firstName: firstNameCopy,
                currentDigest: currentDigest,
                recentExchanges: snapshot
            )
            guard let updated, updated != currentDigest else { return }

            await MainActor.run {
                guard let self else { return }
                let profile = self.profile
                profile.aiMemoryDigest = updated
                profile.aiMemoryDigestUpdatedAt = Date()
                profile.aiMessagesSinceDigestRefresh = 0
                try? self.modelContext.save()
            }
        }
    }
}
