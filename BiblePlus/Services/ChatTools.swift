import Foundation
import SwiftData

// MARK: - Chat Tools
//
// The set of function tools the AI can call. Each tool has:
//   1. A `ToolDefinition` exposed to OpenAI describing its name + JSON schema
//   2. A Swift handler that executes against the local app state
//   3. A short, human-readable summary used in the rendered TOOLRESULT card
//
// The dispatcher (`ChatToolDispatcher`) takes an `APIToolCall` from the
// streaming response, decodes its arguments, runs the matching handler, and
// returns a `ChatToolResult` containing both:
//   - the structured result the model needs in its tool reply
//   - a human-readable summary the bubble view renders as a small inline card
//
// MVP set:
//   • lookup_verse        — fetches the actual verse text from BibleRepository
//                           (eliminates verse hallucination)
//   • save_to_collection  — saves a piece of content to the user's collection
//   • open_bible          — programmatically navigates to a verse in the reader

enum ChatTools {

    // MARK: - Definitions exposed to the model

    /// All tool definitions, ready to be JSON-serialized into the API request.
    static let allDefinitions: [ToolDefinition] = [
        lookupVerseDefinition,
        searchScriptureDefinition,
        saveToCollectionDefinition,
        openBibleDefinition,
        startReadingPlanDefinition,
        setSanctuaryDefinition,
        rememberFactDefinition,
    ]

    static let rememberFactDefinition = ToolDefinition(
        name: "remember_fact",
        description: """
        Pin a SHORT, SPECIFIC fact about the user that you should never forget across \
        future conversations — a name, relationship, life event, ongoing situation, \
        stated preference, or named person in their life. Use ONLY when the user shares \
        something genuinely worth remembering long-term ("my daughter Sarah is sick", \
        "I lost my mom last year", "I'm a youth pastor", "I struggle with porn"). \
        Never use for things you can re-derive from the conversation. Never use to \
        record opinions or interpretations — only first-person facts the user told you. \
        The user trusts these as 'remembered forever' and can see them in settings.
        """,
        parameters: [
            "type": "object",
            "properties": [
                "fact": [
                    "type": "string",
                    "description": "One short fact, max 140 chars. Phrase it as a third-person statement: 'Has a daughter named Sarah', 'Lost his father in October 2024', 'Is going through deconstruction', 'Works as a youth pastor at a small church'.",
                ],
            ],
            "required": ["fact"],
        ]
    )

    static let lookupVerseDefinition = ToolDefinition(
        name: "lookup_verse",
        description: """
        Fetch the EXACT text of ONE specific Bible verse from the user's \
        preferred translation. Use this any time you would otherwise quote \
        scripture from memory — it eliminates hallucinated verses.

        STRICT USAGE RULES:
        • Call this AT MOST ONCE per user turn.
        • Pick THE single best verse for the moment before calling — never \
          chain multiple lookups to "browse" candidates.
        • If you just called search_scripture, the result already includes the \
          verse text for every candidate. Do NOT call lookup_verse on those \
          results — choose the single best one and present it directly.
        """,
        parameters: [
            "type": "object",
            "properties": [
                "book": [
                    "type": "string",
                    "description": "Book name in English, e.g. 'Romans', 'John', 'Genesis', '1 Corinthians'.",
                ],
                "chapter": [
                    "type": "integer",
                    "description": "Chapter number, 1-indexed.",
                ],
                "verse": [
                    "type": "integer",
                    "description": "Verse number, 1-indexed.",
                ],
            ],
            "required": ["book", "chapter", "verse"],
        ]
    )

    static let saveToCollectionDefinition = ToolDefinition(
        name: "save_to_collection",
        description: """
        Save a piece of content (a verse, prayer, insight, or short reflection) \
        to the user's saved collection so they can return to it later. Use \
        when the user explicitly asks you to save something or when something \
        in the conversation is clearly worth keeping.
        """,
        parameters: [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "A short, evocative title for the saved item (3-7 words).",
                ],
                "content": [
                    "type": "string",
                    "description": "The actual content to save — verse text, prayer, insight, or reflection.",
                ],
                "category": [
                    "type": "string",
                    "description": "Optional category like 'Prayer', 'Verse', 'Reflection', 'Insight'.",
                ],
            ],
            "required": ["title", "content"],
        ]
    )

    static let openBibleDefinition = ToolDefinition(
        name: "open_bible",
        description: """
        Navigate the user's Bible reader to a specific verse. Use when the user \
        explicitly wants to read a passage or when you're suggesting they spend \
        time in a chapter. Pairs well with a brief one-sentence intro before the call.
        """,
        parameters: [
            "type": "object",
            "properties": [
                "book": [
                    "type": "string",
                    "description": "Book name in English, e.g. 'Romans', 'Psalms'.",
                ],
                "chapter": [
                    "type": "integer",
                    "description": "Chapter number.",
                ],
                "verse": [
                    "type": "integer",
                    "description": "Optional verse number to scroll to. Use 0 if just opening the chapter.",
                ],
            ],
            "required": ["book", "chapter"],
        ]
    )

    static let searchScriptureDefinition = ToolDefinition(
        name: "search_scripture",
        description: """
        Find verses by theme or emotion. Returns a curated list of 3-5 \
        candidate references **with their full verse text already included**. \
        Use this when you want to suggest a passage but you're not sure which \
        one is best.

        STRICT USAGE RULES:
        • The text for every candidate is in the result — DO NOT call \
          lookup_verse on these references afterwards. The model already has \
          everything it needs.
        • From the candidates, pick THE SINGLE best fit for the user's exact \
          situation. Do not present a list of verses to the user — choose one.
        • Call search_scripture at most once per user turn.

        Common themes: anxiety, fear, hope, comfort, grief, doubt, prayer, \
        love, forgiveness, peace, suffering, joy, identity, faith, courage, \
        rest, calling.
        """,
        parameters: [
            "type": "object",
            "properties": [
                "theme": [
                    "type": "string",
                    "description": "A short theme keyword (e.g. 'anxiety', 'grief', 'identity in Christ').",
                ],
            ],
            "required": ["theme"],
        ]
    )

    static let startReadingPlanDefinition = ToolDefinition(
        name: "start_reading_plan",
        description: """
        Enroll the user in a reading plan that matches a theme or burden they're carrying. \
        Searches the catalog for the best fit (anxiety, grief, doubt, identity, prayer, etc.) and \
        marks it active. Use ONLY when the user has expressed clear interest in starting a structured plan, \
        not as a generic suggestion. Confirm they want to commit before calling.
        """,
        parameters: [
            "type": "object",
            "properties": [
                "theme": [
                    "type": "string",
                    "description": "Theme or burden the plan should address — e.g. 'peace', 'grief', 'doubt', 'identity'.",
                ],
            ],
            "required": ["theme"],
        ]
    )

    static let setSanctuaryDefinition = ToolDefinition(
        name: "set_sanctuary",
        description: """
        Start a sanctuary session — quiet ambient soundscape for prayer, rest, or reflection. \
        Use when the user explicitly wants to rest, slow down, breathe, or sit quietly with God. \
        Available soundscapes include: stillWaters, morningLight, eveningRest, pureSilence, forestBirds, gentleWaves, peacefulPiano, gardenPrayer, mountainTop, fireplace.
        """,
        parameters: [
            "type": "object",
            "properties": [
                "soundscape": [
                    "type": "string",
                    "description": "One of the soundscape identifiers (e.g. 'stillWaters', 'gardenPrayer', 'eveningRest'). Pick what fits the moment.",
                ],
                "minutes": [
                    "type": "integer",
                    "description": "Optional sleep timer in minutes (5, 10, 15, 30). Use 0 for no timer.",
                ],
            ],
            "required": ["soundscape"],
        ]
    )
}

// MARK: - Chat Tool Result

/// Result of executing a single tool call. Contains both the structured
/// content the model receives back via the tool message AND a human summary
/// the chat bubble renders as a small inline card.
struct ChatToolResult {
    /// What gets sent back to the model as the tool message content.
    /// Should be plain text (not JSON) for best model comprehension.
    let modelContent: String

    /// One-line human summary, e.g. "Looked up Romans 8:28 in your KJV Bible".
    /// Rendered in the chat as an inline TOOLRESULT card.
    let humanSummary: String

    /// True if execution failed. The model still gets a result message
    /// (containing the error) but the card is styled differently.
    let isError: Bool

    static func success(modelContent: String, summary: String) -> ChatToolResult {
        ChatToolResult(modelContent: modelContent, humanSummary: summary, isError: false)
    }

    static func failure(_ message: String) -> ChatToolResult {
        ChatToolResult(modelContent: "Error: \(message)", humanSummary: message, isError: true)
    }
}

// MARK: - Chat Tool Dispatcher

@MainActor
enum ChatToolDispatcher {

    /// Executes a tool call and returns the result. The caller should:
    ///   1. Append the result's `humanSummary` to the assistant message as a
    ///      [TOOLRESULT] marker so it persists and renders in the bubble.
    ///   2. Send the `modelContent` back to the model as a tool result
    ///      message keyed on `call.id`.
    static func execute(
        call: APIToolCall,
        modelContext: ModelContext
    ) async -> ChatToolResult {
        switch call.name {
        case ChatTools.lookupVerseDefinition.name:
            return await executeLookupVerse(call: call)
        case ChatTools.searchScriptureDefinition.name:
            return await executeSearchScripture(call: call)
        case ChatTools.saveToCollectionDefinition.name:
            return executeSaveToCollection(call: call, modelContext: modelContext)
        case ChatTools.openBibleDefinition.name:
            return executeOpenBible(call: call)
        case ChatTools.startReadingPlanDefinition.name:
            return executeStartReadingPlan(call: call, modelContext: modelContext)
        case ChatTools.setSanctuaryDefinition.name:
            return executeSetSanctuary(call: call)
        case ChatTools.rememberFactDefinition.name:
            return executeRememberFact(call: call, modelContext: modelContext)
        default:
            return .failure("Unknown tool: \(call.name)")
        }
    }

    // MARK: - remember_fact

    private static func executeRememberFact(
        call: APIToolCall,
        modelContext: ModelContext
    ) -> ChatToolResult {
        guard let args = decodeArguments(call.arguments),
              let raw = (args["fact"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return .failure("remember_fact requires a fact")
        }

        // Hard length cap — pinned facts go in every system prompt forever, so
        // a runaway entry would balloon prompt cost.
        guard raw.count <= 200 else {
            return .failure("Fact too long — keep it under 200 characters")
        }

        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = (try? modelContext.fetch(descriptor))?.first else {
            return .failure("No user profile found")
        }

        var current = profile.aiPinnedFacts

        // Dedupe (case-insensitive). If we already have it, no-op gracefully.
        if current.contains(where: { $0.lowercased() == raw.lowercased() }) {
            return .success(
                modelContent: "Already in long-term memory: \"\(raw)\". No change.",
                summary: "Already remembered"
            )
        }

        current.append(raw)
        // Keep the pin list bounded — drop oldest first.
        let maxFacts = 20
        if current.count > maxFacts {
            current.removeFirst(current.count - maxFacts)
        }
        profile.aiPinnedFacts = current

        do {
            try modelContext.save()
        } catch {
            return .failure("Could not save the fact")
        }

        return .success(
            modelContent: "Pinned to long-term memory: \"\(raw)\". This will be visible to you in every future conversation with this user.",
            summary: "Remembered: \(raw)"
        )
    }

    // MARK: - lookup_verse

    private static func executeLookupVerse(call: APIToolCall) async -> ChatToolResult {
        guard let args = decodeArguments(call.arguments) else {
            return .failure("Invalid arguments to lookup_verse")
        }
        guard let bookInput = args["book"] as? String,
              let chapter = args["chapter"] as? Int,
              let verse = args["verse"] as? Int
        else {
            return .failure("lookup_verse requires book, chapter, verse")
        }

        // The AI passes book NAMES ("Philippians", "1 Corinthians", "Phil")
        // but BibleRepository.bundledFallback indexes the JSON by 3-letter
        // book IDs ("PHP", "1CO"). Resolve the name to a canonical book first
        // so the bundled lookup actually hits.
        guard let book = resolveBookName(bookInput) else {
            return .failure("Couldn't find book '\(bookInput)'")
        }

        let translation = BibleRepository.shared.currentTranslation

        do {
            let verses = try await BibleRepository.shared.verses(
                book: book.id,
                chapter: chapter,
                translation: translation
            )
            guard let match = verses.first(where: { $0.number == verse }) else {
                return .failure("\(book.name) \(chapter):\(verse) isn't available offline")
            }

            let modelContent = """
            \(book.name) \(chapter):\(verse) (\(translation.abbreviation)):
            "\(match.text)"
            """
            let summary = "Looked up \(book.name) \(chapter):\(verse) in \(translation.abbreviation)"
            return .success(modelContent: modelContent, summary: summary)
        } catch {
            return .failure("Could not load \(book.name) \(chapter):\(verse)")
        }
    }

    /// Forgiving book resolver — accepts a name, abbreviation, or partial
    /// match and returns the canonical `BibleBook` if found. The AI emits
    /// names like "Philippians", "1 Corinthians", "John", "Phil", "1 Cor".
    private static func resolveBookName(_ raw: String) -> BibleBook? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.lowercased()

        // 1. Exact ID match (rare from AI but possible)
        if let exactID = BibleData.allBooks.first(where: { $0.id.lowercased() == normalized }) {
            return exactID
        }

        // 2. Exact name match (case insensitive)
        if let exactName = BibleData.allBooks.first(where: { $0.name.lowercased() == normalized }) {
            return exactName
        }

        // 3. Common variations / abbreviations the AI might emit. We don't
        //    enumerate every possibility — just the ambiguous ones the
        //    fallback prefix match would otherwise miss.
        let aliases: [String: String] = [
            "psalm": "PSA",
            "psalms": "PSA",
            "song of songs": "SNG",
            "canticles": "SNG",
            "qoheleth": "ECC",
            "revelation": "REV",
            "revelations": "REV",
            "the revelation": "REV",
            "apocalypse": "REV",
            "1st samuel": "1SA", "first samuel": "1SA",
            "2nd samuel": "2SA", "second samuel": "2SA",
            "1st kings": "1KI", "first kings": "1KI",
            "2nd kings": "2KI", "second kings": "2KI",
            "1st chronicles": "1CH", "first chronicles": "1CH",
            "2nd chronicles": "2CH", "second chronicles": "2CH",
            "1st corinthians": "1CO", "first corinthians": "1CO",
            "2nd corinthians": "2CO", "second corinthians": "2CO",
            "1st thessalonians": "1TH", "first thessalonians": "1TH",
            "2nd thessalonians": "2TH", "second thessalonians": "2TH",
            "1st timothy": "1TI", "first timothy": "1TI",
            "2nd timothy": "2TI", "second timothy": "2TI",
            "1st peter": "1PE", "first peter": "1PE",
            "2nd peter": "2PE", "second peter": "2PE",
            "1st john": "1JN", "first john": "1JN",
            "2nd john": "2JN", "second john": "2JN",
            "3rd john": "3JN", "third john": "3JN",
        ]
        if let aliasID = aliases[normalized],
           let book = BibleData.allBooks.first(where: { $0.id == aliasID }) {
            return book
        }

        // 4. Prefix match against canonical names — handles "Phil",
        //    "Philippians" being typed as "Philip", etc. Pick the SHORTEST
        //    matching book name to break ties (e.g. "John" should match
        //    "John" before "1 John").
        let prefixMatches = BibleData.allBooks
            .filter { $0.name.lowercased().hasPrefix(normalized) }
            .sorted { $0.name.count < $1.name.count }
        if let first = prefixMatches.first {
            return first
        }

        // 5. Substring fallback — last resort for things like "the gospel of John"
        if let contained = BibleData.allBooks.first(where: {
            normalized.contains($0.name.lowercased())
        }) {
            return contained
        }

        return nil
    }

    // MARK: - save_to_collection

    private static func executeSaveToCollection(
        call: APIToolCall,
        modelContext: ModelContext
    ) -> ChatToolResult {
        guard let args = decodeArguments(call.arguments) else {
            return .failure("Invalid arguments to save_to_collection")
        }
        guard let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              let content = (args["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty
        else {
            return .failure("save_to_collection requires title and content")
        }

        let category = (args["category"] as? String) ?? "AI Companion"

        let item = PrayerContent(
            type: .prayer,
            templateText: content,
            category: category,
            isSaved: true
        )
        modelContext.insert(item)

        do {
            try modelContext.save()
        } catch {
            return .failure("Could not save '\(title)'")
        }

        let modelContent = "Saved '\(title)' to the user's collection."
        let summary = "Saved '\(title)' to your collection"
        return .success(modelContent: modelContent, summary: summary)
    }

    // MARK: - open_bible

    private static func executeOpenBible(call: APIToolCall) -> ChatToolResult {
        guard let args = decodeArguments(call.arguments) else {
            return .failure("Invalid arguments to open_bible")
        }
        guard let bookInput = args["book"] as? String,
              let chapter = args["chapter"] as? Int
        else {
            return .failure("open_bible requires book and chapter")
        }
        let verse = (args["verse"] as? Int) ?? 0

        guard let book = resolveBookName(bookInput) else {
            return .failure("Couldn't find book '\(bookInput)'")
        }

        // Post the existing scripture deep link notification — same machinery
        // used by inline citation taps and the popover's "Open in Bible" CTA.
        // The Bible reader's deep-link handler accepts the canonical book name.
        NotificationCenter.default.post(
            name: .scriptureDeepLink,
            object: nil,
            userInfo: [
                "bookName": book.name,
                "chapter": chapter,
                "verse": verse,
            ]
        )

        let summary: String
        let modelContent: String
        if verse > 0 {
            summary = "Opened \(book.name) \(chapter):\(verse) in your Bible"
            modelContent = "Opened \(book.name) \(chapter):\(verse) in the user's Bible reader."
        } else {
            summary = "Opened \(book.name) \(chapter) in your Bible"
            modelContent = "Opened \(book.name) \(chapter) in the user's Bible reader."
        }
        return .success(modelContent: modelContent, summary: summary)
    }

    // MARK: - search_scripture

    /// Curated theme→verses map. Hand-tuned for the most common topics a
    /// Bible-app user actually asks about. The matching pipeline (exact →
    /// alias → substring → keyword → fallback) means almost any reasonable
    /// query lands on a relevant set, and even unknown queries fall through
    /// to a versatile default — so the tool **never returns failure**.
    private static let scriptureThemes: [String: [String]] = [
        // — Emotions & inner states —
        "anxiety": ["Philippians 4:6-7", "Matthew 6:25-27", "1 Peter 5:7", "Psalm 94:19", "Isaiah 41:10"],
        "fear": ["Joshua 1:9", "Isaiah 41:10", "Psalm 27:1", "2 Timothy 1:7", "Psalm 23:4"],
        "worry": ["Matthew 6:25-34", "Philippians 4:6-7", "1 Peter 5:7", "Luke 12:22-26", "Psalm 55:22"],
        "stress": ["Matthew 11:28-30", "Psalm 55:22", "Philippians 4:6-7", "John 14:27", "1 Peter 5:7"],
        "depression": ["Psalm 42:11", "Psalm 34:17-18", "Lamentations 3:21-23", "Isaiah 41:10", "2 Corinthians 4:8-9"],
        "sadness": ["Psalm 30:5", "Psalm 34:18", "Matthew 5:4", "Revelation 21:4", "John 16:22"],
        "despair": ["Psalm 42:5", "Romans 8:38-39", "2 Corinthians 4:8-9", "Lamentations 3:21-23", "Psalm 34:17"],
        "hope": ["Romans 15:13", "Lamentations 3:21-23", "Hebrews 11:1", "Romans 5:3-5", "Jeremiah 29:11"],
        "comfort": ["2 Corinthians 1:3-4", "Psalm 23:4", "Matthew 11:28", "Psalm 34:18", "Isaiah 40:1"],
        "joy": ["Psalm 16:11", "Nehemiah 8:10", "James 1:2", "Philippians 4:4", "John 15:11"],
        "happiness": ["Psalm 16:11", "Proverbs 16:20", "Psalm 144:15", "Ecclesiastes 3:12-13", "John 15:11"],
        "peace": ["John 14:27", "Philippians 4:7", "Isaiah 26:3", "Romans 5:1", "Colossians 3:15"],
        "rest": ["Matthew 11:28-30", "Psalm 23:1-3", "Exodus 33:14", "Hebrews 4:9-11", "Psalm 46:10"],
        "anger": ["Ephesians 4:26-27", "James 1:19-20", "Proverbs 15:1", "Proverbs 14:29", "Colossians 3:8"],
        "frustration": ["Psalm 37:7-8", "Proverbs 14:29", "James 1:19-20", "Ecclesiastes 7:9", "Romans 12:19"],
        "bitterness": ["Hebrews 12:15", "Ephesians 4:31", "Colossians 3:13", "Romans 12:19", "Psalm 73:21-26"],
        "jealousy": ["James 3:14-16", "Proverbs 14:30", "Galatians 5:26", "1 Corinthians 13:4", "Exodus 20:17"],
        "envy": ["James 3:14-16", "Proverbs 14:30", "Psalm 37:1-2", "1 Peter 2:1", "Galatians 5:26"],
        "shame": ["Romans 8:1", "Isaiah 61:7", "Psalm 34:5", "1 John 1:9", "Hebrews 12:2"],
        "guilt": ["1 John 1:9", "Psalm 103:12", "Romans 8:1", "Isaiah 1:18", "Hebrews 10:22"],
        "pride": ["Proverbs 16:18", "James 4:6", "Philippians 2:3", "1 Peter 5:5-6", "Proverbs 11:2"],
        "humility": ["James 4:10", "Philippians 2:3-8", "1 Peter 5:6", "Micah 6:8", "Matthew 23:12"],
        "loneliness": ["Hebrews 13:5", "Psalm 68:6", "Isaiah 41:10", "Matthew 28:20", "Deuteronomy 31:6"],
        "isolation": ["Hebrews 10:24-25", "Psalm 68:6", "Hebrews 13:5", "Ecclesiastes 4:9-12", "Matthew 18:20"],
        "rejection": ["1 Peter 2:4", "John 15:18-19", "Psalm 27:10", "Isaiah 53:3", "Matthew 5:11-12"],
        "betrayal": ["Psalm 41:9", "Psalm 55:12-14", "Matthew 26:50", "Romans 12:19", "Proverbs 17:9"],
        "grief": ["Psalm 34:18", "Matthew 5:4", "Revelation 21:4", "John 11:35", "Lamentations 3:32"],
        "loss": ["Psalm 23:4", "1 Thessalonians 4:13-18", "John 14:1-3", "Matthew 5:4", "Revelation 21:4"],
        "doubt": ["Mark 9:24", "James 1:5-6", "John 20:27-29", "Matthew 14:31", "Psalm 13:1-2"],
        "confusion": ["1 Corinthians 14:33", "James 1:5", "Proverbs 3:5-6", "Isaiah 55:8-9", "Psalm 32:8"],
        "uncertainty": ["Proverbs 3:5-6", "Jeremiah 29:11", "Psalm 32:8", "Isaiah 55:8-9", "James 1:5"],

        // — Health, body, healing —
        "health": ["3 John 1:2", "Proverbs 17:22", "Jeremiah 30:17", "Exodus 15:26", "1 Corinthians 6:19-20"],
        "healing": ["Jeremiah 17:14", "Psalm 103:2-4", "Isaiah 53:5", "James 5:14-16", "Matthew 8:16-17"],
        "sickness": ["James 5:14-16", "Psalm 41:3", "Matthew 8:16-17", "Isaiah 53:4-5", "Exodus 23:25"],
        "illness": ["Psalm 41:3", "James 5:14-16", "Jeremiah 17:14", "2 Corinthians 12:9", "Isaiah 53:4-5"],
        "pain": ["Psalm 34:18", "Revelation 21:4", "2 Corinthians 12:9", "Romans 8:18", "Isaiah 41:10"],
        "body": ["1 Corinthians 6:19-20", "Romans 12:1", "1 Corinthians 3:16-17", "Psalm 139:14", "1 Corinthians 9:27"],
        "recovery": ["Psalm 30:2", "Jeremiah 30:17", "Psalm 23:3", "Isaiah 38:16", "Joel 2:25"],

        // — Strength & weakness —
        "strength": ["Isaiah 40:29-31", "Philippians 4:13", "Psalm 28:7", "Habakkuk 3:19", "2 Corinthians 12:9-10"],
        "weakness": ["2 Corinthians 12:9-10", "Isaiah 40:29", "Romans 8:26", "Psalm 73:26", "Hebrews 4:15-16"],
        "perseverance": ["Romans 5:3-5", "James 1:2-4", "Hebrews 12:1-2", "Galatians 6:9", "2 Timothy 4:7"],
        "endurance": ["Hebrews 12:1-2", "James 1:12", "Romans 5:3-5", "2 Timothy 2:3", "Revelation 14:12"],

        // — Money, work, calling —
        "money": ["1 Timothy 6:10", "Hebrews 13:5", "Matthew 6:19-21", "Proverbs 3:9-10", "Philippians 4:19"],
        "finances": ["Philippians 4:19", "Proverbs 3:9-10", "Malachi 3:10", "Luke 14:28", "1 Timothy 6:17-19"],
        "provision": ["Philippians 4:19", "Matthew 6:31-33", "Psalm 23:1", "2 Corinthians 9:8", "Psalm 37:25"],
        "wealth": ["1 Timothy 6:17-19", "Proverbs 11:28", "Matthew 6:19-21", "Ecclesiastes 5:10", "Luke 12:15"],
        "poverty": ["Proverbs 19:17", "Psalm 34:6", "James 2:5", "Proverbs 22:9", "2 Corinthians 8:9"],
        "work": ["Colossians 3:23-24", "Ecclesiastes 9:10", "Proverbs 16:3", "1 Corinthians 10:31", "2 Thessalonians 3:10"],
        "career": ["Colossians 3:23-24", "Jeremiah 29:11", "Proverbs 16:3", "Ecclesiastes 9:10", "Romans 12:6-8"],
        "calling": ["Jeremiah 29:11", "Ephesians 2:10", "Romans 8:28", "1 Peter 2:9", "Esther 4:14"],
        "purpose": ["Jeremiah 29:11", "Ephesians 2:10", "Romans 8:28", "Proverbs 19:21", "Philippians 1:6"],
        "success": ["Joshua 1:8", "Proverbs 16:3", "Psalm 1:1-3", "Proverbs 3:5-6", "Colossians 3:23-24"],
        "failure": ["Proverbs 24:16", "Romans 8:28", "Philippians 3:13-14", "2 Corinthians 12:9", "Psalm 37:23-24"],

        // — Relationships —
        "marriage": ["Ephesians 5:22-33", "Genesis 2:24", "1 Corinthians 13:4-7", "Mark 10:6-9", "Proverbs 18:22"],
        "divorce": ["Malachi 2:16", "Matthew 19:6", "1 Corinthians 7:10-11", "Mark 10:9", "Romans 7:2-3"],
        "parenting": ["Proverbs 22:6", "Ephesians 6:4", "Deuteronomy 6:6-7", "Psalm 127:3-5", "Colossians 3:21"],
        "children": ["Psalm 127:3-5", "Proverbs 22:6", "Mark 10:14", "Matthew 18:5-6", "Ephesians 6:1-3"],
        "family": ["Joshua 24:15", "Psalm 127:3-5", "1 Timothy 5:8", "Ephesians 6:1-4", "Proverbs 22:6"],
        "friendship": ["Proverbs 17:17", "Proverbs 18:24", "Ecclesiastes 4:9-12", "John 15:13-15", "Proverbs 27:17"],
        "love": ["1 Corinthians 13:4-7", "1 John 4:19", "John 15:13", "Romans 8:38-39", "1 John 4:7-8"],
        "forgiveness": ["1 John 1:9", "Ephesians 4:32", "Matthew 6:14-15", "Colossians 3:13", "Psalm 103:12"],
        "reconciliation": ["2 Corinthians 5:18-19", "Matthew 5:23-24", "Romans 5:10-11", "Ephesians 2:14-16", "Colossians 1:20"],

        // — Spiritual life —
        "prayer": ["Philippians 4:6", "1 Thessalonians 5:17", "Matthew 6:9-13", "James 5:16", "Romans 8:26"],
        "worship": ["John 4:23-24", "Psalm 95:6", "Romans 12:1", "Psalm 100:1-5", "Hebrews 13:15"],
        "praise": ["Psalm 150:6", "Hebrews 13:15", "Psalm 34:1", "Psalm 100:4", "Ephesians 5:19"],
        "gratitude": ["1 Thessalonians 5:18", "Colossians 3:17", "Psalm 107:1", "Ephesians 5:20", "Philippians 4:6"],
        "thanksgiving": ["1 Thessalonians 5:18", "Psalm 100:4", "Colossians 3:17", "Psalm 107:1", "Philippians 4:6"],
        "faith": ["Hebrews 11:1", "Romans 10:17", "Mark 11:22-24", "James 2:17", "2 Corinthians 5:7"],
        "trust": ["Proverbs 3:5-6", "Psalm 56:3", "Isaiah 26:3", "Nahum 1:7", "Psalm 9:10"],
        "salvation": ["Romans 10:9-10", "Ephesians 2:8-9", "John 3:16", "Acts 4:12", "Romans 6:23"],
        "grace": ["Ephesians 2:8-9", "2 Corinthians 12:9", "Romans 5:20-21", "Titus 2:11", "Hebrews 4:16"],
        "mercy": ["Lamentations 3:22-23", "Ephesians 2:4-5", "Titus 3:5", "Hebrews 4:16", "Micah 6:8"],
        "righteousness": ["Romans 3:22", "2 Corinthians 5:21", "Matthew 6:33", "Romans 5:17", "Proverbs 21:21"],
        "obedience": ["John 14:15", "1 Samuel 15:22", "James 1:22", "Deuteronomy 11:1", "Romans 6:16"],

        // — Sin & temptation —
        "sin": ["Romans 3:23", "1 John 1:9", "Romans 6:23", "James 4:17", "Psalm 51:10"],
        "temptation": ["1 Corinthians 10:13", "James 1:12-15", "Matthew 26:41", "Hebrews 4:15-16", "James 4:7"],
        "addiction": ["1 Corinthians 10:13", "Romans 7:15-25", "2 Corinthians 5:17", "Galatians 5:1", "Philippians 4:13"],
        "lust": ["Matthew 5:28", "1 Corinthians 6:18", "1 John 2:16", "2 Timothy 2:22", "Job 31:1"],

        // — Wisdom, guidance, decisions —
        "wisdom": ["James 1:5", "Proverbs 9:10", "Proverbs 3:13-18", "1 Corinthians 1:25", "Colossians 2:3"],
        "guidance": ["Proverbs 3:5-6", "Psalm 32:8", "Isaiah 30:21", "James 1:5", "Psalm 119:105"],
        "decisions": ["Proverbs 3:5-6", "James 1:5", "Psalm 32:8", "Proverbs 16:9", "Romans 12:2"],
        "discernment": ["Hebrews 5:14", "1 Kings 3:9", "Philippians 1:9-10", "1 John 4:1", "Romans 12:2"],
        "patience": ["Romans 12:12", "James 5:7-8", "Psalm 27:14", "Galatians 6:9", "Lamentations 3:25-26"],

        // — Identity & worth —
        "identity": ["2 Corinthians 5:17", "Ephesians 2:10", "1 John 3:1", "Galatians 2:20", "Romans 8:14-17"],
        "self-worth": ["Psalm 139:13-14", "Ephesians 2:10", "1 Peter 2:9", "Genesis 1:27", "Isaiah 43:4"],

        // — Courage & boldness —
        "courage": ["Joshua 1:9", "Deuteronomy 31:6", "1 Corinthians 16:13", "Psalm 31:24", "2 Timothy 1:7"],
        "boldness": ["Acts 4:29", "Hebrews 4:16", "Ephesians 6:19-20", "Proverbs 28:1", "2 Timothy 1:7"],

        // — Big picture —
        "death": ["1 Corinthians 15:54-57", "John 11:25-26", "Psalm 23:4", "Revelation 21:4", "Romans 14:8"],
        "heaven": ["John 14:1-3", "Revelation 21:1-4", "1 Peter 1:3-4", "Philippians 3:20", "2 Corinthians 5:1"],
        "eternal life": ["John 3:16", "John 17:3", "1 John 5:11-13", "John 11:25-26", "Romans 6:23"],
        "creation": ["Genesis 1:1", "Psalm 19:1", "Colossians 1:16", "Romans 1:20", "John 1:3"],

        // — Suffering & trials —
        "suffering": ["Romans 5:3-5", "James 1:2-4", "2 Corinthians 4:17", "1 Peter 4:12-13", "Job 23:10"],
        "trials": ["James 1:2-4", "1 Peter 1:6-7", "Romans 5:3-5", "2 Corinthians 4:17", "1 Peter 4:12-13"],
        "hardship": ["Romans 8:18", "2 Corinthians 4:17", "James 1:12", "Hebrews 12:7-11", "Psalm 34:19"],
        "persecution": ["Matthew 5:10-12", "2 Timothy 3:12", "Romans 8:35-37", "1 Peter 4:12-14", "John 15:20"],

        // — Spiritual warfare —
        "spiritual warfare": ["Ephesians 6:10-18", "1 Peter 5:8-9", "James 4:7", "2 Corinthians 10:3-5", "1 John 4:4"],
        "protection": ["Psalm 91:1-4", "Psalm 121:7-8", "2 Thessalonians 3:3", "Psalm 18:2", "Isaiah 54:17"],
    ]

    /// Synonym/alias map: maps related words a user might use to a canonical
    /// theme key. Lets the AI emit natural language ("worried", "afraid",
    /// "tired", "broke") and still land on a curated set.
    private static let themeAliases: [String: String] = [
        // Anxiety / fear / stress
        "worried": "worry", "worrying": "worry", "anxious": "anxiety",
        "afraid": "fear", "scared": "fear", "scary": "fear", "frightened": "fear",
        "stressed": "stress", "overwhelm": "stress", "overwhelmed": "stress",
        "panic": "anxiety", "panicking": "anxiety",
        // Mood
        "depressed": "depression", "down": "depression", "blue": "sadness",
        "sad": "sadness", "weeping": "sadness", "crying": "sadness",
        "hopeless": "despair", "discouraged": "despair",
        // Anger family
        "angry": "anger", "mad": "anger", "rage": "anger", "raging": "anger",
        "frustrated": "frustration", "annoyed": "frustration",
        "bitter": "bitterness", "resentful": "bitterness",
        "jealous": "jealousy", "envious": "envy",
        // Shame family
        "ashamed": "shame", "embarrassed": "shame",
        "guilty": "guilt", "regret": "guilt", "regretful": "guilt",
        // Pride / humility
        "proud": "pride", "arrogant": "pride", "humble": "humility",
        // Loneliness
        "lonely": "loneliness", "alone": "loneliness", "isolated": "isolation",
        "rejected": "rejection", "abandoned": "rejection",
        "betrayed": "betrayal",
        // Grief / loss
        "grieving": "grief", "mourning": "grief", "bereaved": "grief",
        "loss": "grief",
        // Doubt
        "doubting": "doubt", "skeptical": "doubt", "confused": "confusion",
        "uncertain": "uncertainty", "unsure": "uncertainty",
        // Health
        "sick": "sickness", "ill": "illness", "unwell": "illness",
        "hurt": "pain", "hurting": "pain", "suffering": "suffering",
        "wellness": "health", "wellbeing": "health", "well-being": "health",
        "disease": "illness", "diagnosis": "illness", "diagnosed": "illness",
        "cancer": "illness", "chronic": "illness",
        // Strength
        "weak": "weakness", "tired": "rest", "exhausted": "rest",
        "burnt out": "rest", "burned out": "rest", "burnout": "rest",
        "strong": "strength", "power": "strength",
        // Money
        "broke": "poverty", "poor": "poverty", "rich": "wealth",
        "financial": "finances", "debt": "money", "bill": "money", "bills": "money",
        "job": "work", "unemployed": "work", "unemployment": "work",
        "boss": "work", "workplace": "work",
        // Family
        "wife": "marriage", "husband": "marriage", "spouse": "marriage",
        "married": "marriage",
        "kids": "children", "child": "children",
        "parent": "parenting", "father": "parenting", "mother": "parenting",
        "dad": "parenting", "mom": "parenting", "mum": "parenting",
        "friend": "friendship", "friends": "friendship",
        // Spiritual
        "thank": "gratitude", "thanks": "gratitude", "thankful": "gratitude",
        "grateful": "gratitude",
        "faithful": "faith", "believing": "faith",
        "obey": "obedience", "obeying": "obedience",
        "discipline": "obedience", "spiritual growth": "obedience",
        "saved": "salvation", "saved by grace": "grace",
        "merciful": "mercy",
        // Sin
        "tempted": "temptation", "temptations": "temptation",
        "addicted": "addiction", "alcohol": "addiction", "alcoholic": "addiction",
        "drug": "addiction", "drugs": "addiction", "porn": "lust", "pornography": "lust",
        // Wisdom
        "decision": "decisions", "choice": "decisions", "choose": "decisions",
        "wise": "wisdom", "knowledge": "wisdom", "understanding": "wisdom",
        // Death
        "dying": "death", "dead": "death", "funeral": "death",
        "afterlife": "heaven", "paradise": "heaven",
        // Trials
        "trial": "trials", "tested": "trials", "testing": "trials",
        "trouble": "hardship", "hard time": "hardship", "hard times": "hardship",
        "persecuted": "persecution",
        // Warfare
        "demonic": "spiritual warfare", "demons": "spiritual warfare",
        "evil": "spiritual warfare", "satan": "spiritual warfare",
        "devil": "spiritual warfare", "battle": "spiritual warfare",
    ]

    /// A versatile, high-quality default set returned as a last-resort
    /// fallback when nothing else matches. These verses speak to almost
    /// any moment a user could be in.
    private static let defaultGeneralVerses: [String] = [
        "Romans 8:28",
        "Philippians 4:13",
        "Psalm 23:1",
        "Jeremiah 29:11",
        "Proverbs 3:5-6",
        "Isaiah 41:10",
    ]

    private static func formatVerseList(_ refs: [String], theme: String) -> String {
        return """
        Verses related to \(theme):
        \(refs.map { "• \($0)" }.joined(separator: "\n"))
        """
    }

    /// Resolves a reference string like "Romans 8:28" or "Philippians 4:6-7"
    /// into book + chapter + verse range. Returns nil if the format is unrecognized.
    private static func parseReference(_ ref: String) -> (book: BibleBook, chapter: Int, startVerse: Int, endVerse: Int)? {
        // Pattern: "<book name with possible leading digit and spaces> <chapter>:<start>(-<end>)?"
        let pattern = #"^(.+?)\s+(\d+):(\d+)(?:[-–](\d+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRef = ref as NSString
        guard let match = regex.firstMatch(in: ref, range: NSRange(location: 0, length: nsRef.length)),
              match.numberOfRanges >= 4
        else { return nil }

        let bookName = nsRef.substring(with: match.range(at: 1))
        guard let book = resolveBookName(bookName) else { return nil }
        guard let chapter = Int(nsRef.substring(with: match.range(at: 2))),
              let start = Int(nsRef.substring(with: match.range(at: 3)))
        else { return nil }
        let end: Int
        if match.range(at: 4).location != NSNotFound {
            end = Int(nsRef.substring(with: match.range(at: 4))) ?? start
        } else {
            end = start
        }
        return (book, chapter, start, end)
    }

    /// Loads the verse text for a single reference string. Returns the text on
    /// success, or nil if the reference can't be parsed or the verses aren't
    /// available offline. Used so `search_scripture` can return inline text and
    /// the AI never needs a follow-up `lookup_verse` call.
    private static func fetchVerseText(for ref: String) async -> String? {
        guard let parsed = parseReference(ref) else { return nil }
        let translation = BibleRepository.shared.currentTranslation
        do {
            let verses = try await BibleRepository.shared.verses(
                book: parsed.book.id,
                chapter: parsed.chapter,
                translation: translation
            )
            let selected = verses
                .filter { $0.number >= parsed.startVerse && $0.number <= parsed.endVerse }
                .sorted { $0.number < $1.number }
                .map(\.text)
            guard !selected.isEmpty else { return nil }
            return selected.joined(separator: " ")
        } catch {
            return nil
        }
    }

    /// Like `formatVerseList`, but fetches the actual verse text for every
    /// reference and embeds it inline so the model has everything it needs in
    /// one tool call (no follow-up `lookup_verse` chain). Falls back gracefully
    /// to the reference alone for any verse that's not available offline.
    private static func formatVerseListWithText(_ refs: [String], theme: String) async -> String {
        var lines: [String] = []
        for ref in refs {
            if let text = await fetchVerseText(for: ref) {
                lines.append("• \(ref) — \"\(text)\"")
            } else {
                lines.append("• \(ref)")
            }
        }
        return """
        Candidate verses related to \(theme) (text included — pick the SINGLE best fit, do not call lookup_verse):
        \(lines.joined(separator: "\n"))
        """
    }

    private static func executeSearchScripture(call: APIToolCall) async -> ChatToolResult {
        // Even on a missing/empty arg we return a useful result rather than
        // failing — the goal of this tool is to NEVER show the user an
        // "agent error" card.
        guard let args = decodeArguments(call.arguments),
              let rawTheme = (args["theme"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTheme.isEmpty
        else {
            let refs = defaultGeneralVerses
            return .success(
                modelContent: await formatVerseListWithText(refs, theme: "general"),
                summary: "Found \(refs.count) general verses"
            )
        }

        let theme = rawTheme.lowercased()

        // 1. Exact key match
        if let refs = scriptureThemes[theme] {
            return .success(
                modelContent: await formatVerseListWithText(refs, theme: theme),
                summary: "Found \(refs.count) verses about \(theme)"
            )
        }

        // 2. Alias / synonym match
        if let canonical = themeAliases[theme], let refs = scriptureThemes[canonical] {
            return .success(
                modelContent: await formatVerseListWithText(refs, theme: canonical),
                summary: "Found \(refs.count) verses about \(canonical)"
            )
        }

        // 3. Substring match against canonical keys (catches "deep anxiety",
        //    "the loneliness", "feeling rejected", etc.)
        for (key, refs) in scriptureThemes {
            if theme.contains(key) || key.contains(theme) {
                return .success(
                    modelContent: await formatVerseListWithText(refs, theme: key),
                    summary: "Found \(refs.count) verses about \(key)"
                )
            }
        }

        // 4. Keyword expansion — split into words and try each token against
        //    both keys and aliases. Catches multi-word themes like "money
        //    stress", "marriage doubt", "fear of death".
        let words = theme
            .replacingOccurrences(of: "[^a-z\\s]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 }

        for word in words {
            if let refs = scriptureThemes[word] {
                return .success(
                    modelContent: await formatVerseListWithText(refs, theme: word),
                    summary: "Found \(refs.count) verses about \(word)"
                )
            }
            if let canonical = themeAliases[word], let refs = scriptureThemes[canonical] {
                return .success(
                    modelContent: await formatVerseListWithText(refs, theme: canonical),
                    summary: "Found \(refs.count) verses about \(canonical)"
                )
            }
            for (key, refs) in scriptureThemes {
                if word.contains(key) || key.contains(word) {
                    return .success(
                        modelContent: await formatVerseListWithText(refs, theme: key),
                        summary: "Found \(refs.count) verses about \(key)"
                    )
                }
            }
        }

        // 5. FINAL FALLBACK — never fail. Return a versatile general set
        //    with inline text so the model still doesn't need lookup_verse.
        let refs = defaultGeneralVerses
        return .success(
            modelContent: await formatVerseListWithText(refs, theme: "general (no exact match for '\(theme)')"),
            summary: "General verses (no exact match for '\(theme)')"
        )
    }

    // MARK: - start_reading_plan

    private static func executeStartReadingPlan(
        call: APIToolCall,
        modelContext: ModelContext
    ) -> ChatToolResult {
        guard let args = decodeArguments(call.arguments),
              let theme = (args["theme"] as? String)?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !theme.isEmpty
        else {
            return .failure("start_reading_plan requires a theme")
        }

        // Fetch all plans
        let descriptor = FetchDescriptor<ReadingPlan>()
        guard let plans = try? modelContext.fetch(descriptor), !plans.isEmpty else {
            return .failure("No reading plans available")
        }

        // Score each plan against the theme using simple keyword overlap.
        // Stronger weight for matches in name + category, lighter for
        // applicableBurdens / applicableSeasons.
        let scored: [(plan: ReadingPlan, score: Int)] = plans.map { plan in
            var score = 0
            let nameMatch = plan.name.lowercased().contains(theme) ? 5 : 0
            let categoryMatch = plan.category.lowercased().contains(theme) ? 4 : 0
            let descMatch = plan.planDescription.lowercased().contains(theme) ? 2 : 0
            let burdenMatch = plan.applicableBurdens.contains { $0.lowercased().contains(theme) } ? 3 : 0
            let seasonMatch = plan.applicableSeasons.contains { $0.lowercased().contains(theme) } ? 2 : 0
            score = nameMatch + categoryMatch + descMatch + burdenMatch + seasonMatch
            return (plan, score)
        }

        guard let best = scored.max(by: { $0.score < $1.score }), best.score > 0 else {
            return .failure("No reading plan matches '\(theme)'")
        }

        // Check if user is already enrolled in this plan (active or not)
        let targetPlanID = best.plan.id
        let progressDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.planID == targetPlanID }
        )
        if let existing = (try? modelContext.fetch(progressDescriptor))?.first {
            existing.isActive = true
            try? modelContext.save()
            let summary = "Reactivated reading plan: \(best.plan.name)"
            let modelContent = """
            The user is already enrolled in '\(best.plan.name)' — reactivated their progress. \
            Plan length: \(best.plan.totalDays) days.
            """
            return .success(modelContent: modelContent, summary: summary)
        }

        // Create new progress entry
        let progress = UserPlanProgress(planID: best.plan.id)
        progress.isActive = true
        modelContext.insert(progress)

        do {
            try modelContext.save()
        } catch {
            return .failure("Could not start plan '\(best.plan.name)'")
        }

        let summary = "Started reading plan: \(best.plan.name)"
        let modelContent = """
        Started '\(best.plan.name)' (\(best.plan.totalDays) days). \
        Description: \(best.plan.planDescription). \
        The user is now enrolled and will see day 1 in their plans tab.
        """
        return .success(modelContent: modelContent, summary: summary)
    }

    // MARK: - set_sanctuary

    private static func executeSetSanctuary(call: APIToolCall) -> ChatToolResult {
        guard let args = decodeArguments(call.arguments),
              let soundscapeRaw = (args["soundscape"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !soundscapeRaw.isEmpty
        else {
            return .failure("set_sanctuary requires a soundscape")
        }

        // Resolve the soundscape against the enum's known cases (lenient match)
        let resolved = Soundscape.allCases.first { soundscape in
            soundscape.rawValue.lowercased() == soundscapeRaw.lowercased()
                || soundscape.displayName.lowercased() == soundscapeRaw.lowercased()
                || soundscape.rawValue.lowercased().contains(soundscapeRaw.lowercased())
        }

        guard let soundscape = resolved else {
            return .failure("Unknown soundscape '\(soundscapeRaw)'")
        }

        let minutes = (args["minutes"] as? Int) ?? 0

        // Post the existing sanctuary deep link with details. SanctuaryView
        // (or whichever view handles this notification) is responsible for
        // starting playback.
        var userInfo: [String: Any] = ["soundscape": soundscape.rawValue]
        if minutes > 0 {
            userInfo["minutes"] = minutes
        }
        NotificationCenter.default.post(
            name: .init("openSanctuary"),
            object: nil,
            userInfo: userInfo
        )

        let timerSuffix = minutes > 0 ? " for \(minutes) minutes" : ""
        let summary = "Started sanctuary: \(soundscape.displayName)\(timerSuffix)"
        let modelContent = "Started a sanctuary session with the \(soundscape.displayName) soundscape\(timerSuffix). The user can rest now."
        return .success(modelContent: modelContent, summary: summary)
    }

    // MARK: - JSON helpers

    /// Decodes an OpenAI tool argument string into a `[String: Any]`. The
    /// model occasionally emits malformed JSON when streaming is interrupted
    /// — this returns nil in that case rather than crashing.
    private static func decodeArguments(_ raw: String) -> [String: Any]? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
