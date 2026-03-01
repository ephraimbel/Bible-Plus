import Foundation

enum AIService {
    private static let endpoint = URL(string: "\(Secrets.supabaseURL)/functions/v1/chat")
    private static let model = "gpt-4.1-nano"

    // MARK: - System Prompt

    static func buildSystemPrompt(for profile: UserProfile) -> String {
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        let faith = profile.faithLevel.displayName.lowercased()
        let seasons = profile.lifeSeasons.map(\.displayName).joined(separator: ", ")
        let burdens = profile.currentBurdens.map(\.displayName).joined(separator: ", ")
        let translation = profile.preferredTranslation.displayName

        return """
        You are the Bible+ companion — a warm, thoughtful theologian sitting across the table \
        over coffee. You know Scripture deeply and speak from genuine understanding, not templates.

        USER: \(name). Faith: \(faith). \
        \(seasons.isEmpty ? "" : "Seasons: \(seasons). ")\
        \(burdens.isEmpty ? "" : "Carrying: \(burdens). ")\
        Reads the \(translation).

        VOICE: Write like a pastor who studied at seminary but talks like a friend. Use \
        contractions, short sentences. Be theologically rich but never academic. Sit in the \
        tension before offering hope. 2-3 paragraphs max.

        SCRIPTURE RULES:
        - You MUST include exactly ONE verse per response. NEVER quote a second verse. \
        If you want to mention another passage, just name the reference without quoting it.
        - Quote the full verse from the \(translation).
        - ALWAYS format the verse like this: "Verse text here" (**Book Chapter:Verse**)
        - Put the quote FIRST, then the reference in parentheses. Never reference-first.
        - Give brief context — who wrote it, why, what it means for \(name) today.

        RESPONDING:
        - Scripture questions: historical context, the verse quoted, then personal application.
        - Hard seasons: empathy first — name the pain. Then a verse that meets them there.
        - Prayer requests: write the actual prayer to God. Intimate, not performative.
        - Theology: what Scripture says, where faithful Christians disagree, original language if helpful.
        - "Where do I start": one specific next step for their faith level (\(faith)).

        STRICT RULES:
        - ONLY write a prayer if \(name) explicitly asks for prayer. Never add one unprompted.
        - NEVER include helpline disclaimers unless someone mentions self-harm or suicide.
        - NEVER include a "Follow-ups:" label or header.
        - Not God, not church replacement. Christ-centered.

        At the very end, on one line, write exactly 3 follow-ups in this format:
        |||Suggestion|||Suggestion|||Suggestion|||
        Under 8 words each. No label before them.
        """
    }

    // MARK: - Mode Overlay

    static func modeOverlay(for mode: ConversationMode, name: String) -> String {
        switch mode {
        case .comfort:
            return "TONE: COMFORT. Empathy first, \(name) needs to feel seen. Warm, gentle. Verses about nearness/comfort (Ps 23, Isa 41:10, Matt 11:28). Tender words, like a hand on the shoulder."
        case .challenge:
            return "TONE: CHALLENGE. Direct, honest with \(name). Don't sugarcoat. Call higher with love and clarity. Verses about growth (Heb 12:11, Jas 1:2-4, Prov 27:17). Push to act. Iron sharpens iron."
        case .teach:
            return "TONE: TEACH. \(name) wants to learn. Historical context, original languages, theological depth. Cross-references. Thorough but accessible."
        case .pray:
            return "TONE: PRAY. Every response includes or IS a prayer. Intimate, addressed to God, close with Amen. Weave Scripture into the prayer."
        }
    }

    // MARK: - Character Persona

    static func characterPersona(for character: BiblicalCharacter) -> String {
        switch character {
        case .paul:
            return "PERSONA: PAUL. Speak as Paul of Tarsus, first person. Damascus conversion, missionary journeys, prison, letters to churches. Draw from Romans, Corinthians, Ephesians, Philippians. Theological but pastoral. Persecutor turned persecuted."
        case .david:
            return "PERSONA: DAVID. Speak as King David, first person. Shepherd to king — Goliath, fleeing Saul, Jonathan, Bathsheba's repentance. Psalms in caves and on thrones. Draw from Psalms, 1-2 Samuel. Triumph and brokenness."
        case .moses:
            return "PERSONA: MOSES. Speak as Moses, first person. Burning bush, Pharaoh, Red Sea, Sinai, wilderness years. Argued with God, interceded for the people. Draw from Exodus, Numbers, Deuteronomy. Obedience when terrified."
        case .mary:
            return "PERSONA: MARY. Speak as Mary mother of Jesus, first person. Angel's visit, carrying Jesus, watching him grow, the cross. Treasured things in heart. Draw from Luke 1-2, John 2, John 19. Trust through joy and sorrow."
        case .solomon:
            return "PERSONA: SOLOMON. Speak as King Solomon, first person. God-given wisdom, Temple, wise judgment, but also turning away. Draw from Proverbs, Ecclesiastes, Song of Solomon, 1 Kings. All is vanity without God."
        case .ruth:
            return "PERSONA: RUTH. Speak as Ruth the Moabite, first person. Left everything for Naomi and God. Loss, loyalty, gleaning, redemption. Draw from book of Ruth. Stepping into the unknown out of love."
        case .peter:
            return "PERSONA: PETER. Speak as Simon Peter, first person. Fisherman to rock of the church. Walking on water, denying Christ, restoration. Draw from Gospels, Acts, 1-2 Peter. Impulsive, passionate, knows grace deeply."
        case .esther:
            return "PERSONA: ESTHER. Speak as Queen Esther, first person. Hidden identity, Mordecai's counsel, risking life before the king. Draw from book of Esther. Brave when afraid. God works even in silence."
        }
    }

    // MARK: - Follow-Up Suggestion Parsing

    /// Extracts follow-up suggestions from the AI response and returns
    /// the cleaned content + suggestion array.
    static func extractSuggestions(from content: String) -> (cleanedContent: String, suggestions: [String]) {
        // Primary: |||suggestion||| pattern
        let pipePattern = #"\|\|\|(.+?)\|\|\|(.+?)\|\|\|(.+?)\|\|\|\s*$"#
        if let regex = try? NSRegularExpression(pattern: pipePattern),
           let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)) {
            var suggestions: [String] = []
            for i in 1...3 {
                if let range = Range(match.range(at: i), in: content) {
                    let suggestion = String(content[range]).trimmingCharacters(in: .whitespaces)
                    if !suggestion.isEmpty {
                        suggestions.append(suggestion)
                    }
                }
            }
            if let matchRange = Range(match.range, in: content) {
                let cleaned = String(content[content.startIndex..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (cleaned, suggestions)
            }
        }

        // Fallback: "Follow-ups:" or "Follow ups:" or numbered/bulleted list at end
        let fallbackPattern = #"(?:\n|\r\n?)(?:Follow[\s-]?ups?:?|Suggestions?:?)\s*\n((?:[-•*\d].*\n?){1,4})\s*$"#
        if let regex = try? NSRegularExpression(pattern: fallbackPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)) {
            var suggestions: [String] = []
            if let listRange = Range(match.range(at: 1), in: content) {
                let lines = String(content[listRange]).components(separatedBy: .newlines)
                for line in lines {
                    let cleaned = line.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: #"^[-•*\d]+[.):\s]*"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty { suggestions.append(cleaned) }
                }
            }
            if !suggestions.isEmpty, let matchRange = Range(match.range, in: content) {
                let cleaned = String(content[content.startIndex..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (cleaned, Array(suggestions.prefix(3)))
            }
        }

        return (content, [])
    }

    // MARK: - Prayer Intent Detection

    static func detectsPrayerIntent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let prayerPatterns = [
            "pray with me", "pray for me", "pray for my", "pray for us",
            "i need prayer", "please pray", "can you pray",
            "write a prayer", "write me a prayer",
            "let's pray", "help me pray",
            "pray about", "prayer for",
        ]
        return prayerPatterns.contains { lowered.contains($0) }
    }

    static func buildPrayerSystemPrompt(for profile: UserProfile) -> String {
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        return """
        PRAYER MODE. Write an actual prayer to God about what \(name) shared. \
        Address God warmly, pray through their situation using their words, weave in 1 Scripture, \
        close with "In Jesus' name, Amen." Entire response IS the prayer. 2-3 paragraphs, intimate.
        """
    }

    // MARK: - Rate Limiting

    static let freeMessagesPerWeek = 3
    static let proMessagesPerWeek = 200

    static func messagesUsedThisWeek(messages: [ChatMessage]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        return messages.filter { $0.role == .user && $0.createdAt >= startOfWeek }.count
    }

    static func canSendMessage(messages: [ChatMessage], isPro: Bool) -> Bool {
        let used = messagesUsedThisWeek(messages: messages)
        let limit = isPro ? proMessagesPerWeek : freeMessagesPerWeek
        return used < limit
    }

    // MARK: - Streaming

    private static let maxRetries = 1
    private static let retryBaseDelay: UInt64 = 1_000_000_000 // 1 second

    /// Whether an error is transient and worth retrying (5xx, timeout, network).
    private static func isRetryable(_ error: Error) -> Bool {
        if let aiError = error as? AIError, case .apiError(let code, _) = aiError {
            return code >= 500
        }
        return (error as NSError).code == NSURLErrorTimedOut
            || (error as NSError).code == NSURLErrorNetworkConnectionLost
    }

    static func streamCompletion(
        messages: [(role: String, content: String)],
        onToken: @escaping (String) -> Void
    ) async throws {
        var lastError: Error = AIError.invalidResponse

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = retryBaseDelay * UInt64(attempt)
                try await Task.sleep(nanoseconds: delay)
                try Task.checkCancellation()
            }

            do {
                try await performStream(messages: messages, onToken: onToken)
                return
            } catch {
                lastError = error
                guard attempt < maxRetries, isRetryable(error) else { throw error }
            }
        }

        throw lastError
    }

    private static func performStream(
        messages: [(role: String, content: String)],
        onToken: @escaping (String) -> Void
    ) async throws {
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
            "max_tokens": 400,
            "temperature": 0.75,
        ]

        guard let endpoint else { throw AIError.invalidResponse }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Collect error body
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))

            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
            else { continue }

            await MainActor.run {
                onToken(content)
            }
        }
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Received an invalid response. Please try again."
        case .apiError(let code, _):
            "API error (\(code)). Please try again."
        case .rateLimited:
            "You've used your 3 free messages this week. Upgrade to Pro for unlimited access."
        }
    }
}
