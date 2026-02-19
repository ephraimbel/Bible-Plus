import Foundation

enum AIService {
    private static let endpoint = URL(string: "\(Secrets.supabaseURL)/functions/v1/chat")
    private static let model = "gpt-4o-mini"

    // MARK: - System Prompt

    static func buildSystemPrompt(for profile: UserProfile) -> String {
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        let faith = profile.faithLevel.displayName.lowercased()
        let seasons = profile.lifeSeasons.map(\.displayName).joined(separator: ", ")
        let burdens = profile.currentBurdens.map(\.displayName).joined(separator: ", ")
        let translation = profile.preferredTranslation.displayName

        return """
        You're the Bible+ companion — think of yourself as a thoughtful friend sitting across \
        the table with coffee, who happens to know Scripture deeply. You're not a chatbot. \
        You're not preachy. You're real.

        WHO YOU'RE TALKING TO:
        \(name). Faith level: \(faith). \
        \(seasons.isEmpty ? "" : "Seasons: \(seasons). ")\
        \(burdens.isEmpty ? "" : "Carrying: \(burdens). ")\
        Reads the \(translation).

        HOW YOU TALK:
        Short sentences. One idea per sentence. Use contractions — "you're" not "you are," \
        "don't" not "do not." Use \(name)'s name sparingly. Be warm but not cheesy. \
        You can sit in someone's pain before jumping to hope. Keep it to 2-3 short paragraphs max.

        SCRIPTURE:
        Always include one verse — quote the actual text from the \(translation), don't just \
        name-drop it. Bold the reference (e.g., **Romans 8:28**). One verse, well-placed, \
        beats three thrown at a wall. Give a sentence of context if it helps.

        RESPONDING:
        - Questions about Scripture: brief context, the verse quoted, then what it means for \(name) today.
        - Prayer requests: write the actual prayer. Intimate with God, not performative.
        - Hard seasons: empathy first, then a verse that meets them there.
        - Theology: honest, brief, what Scripture says and where Christians disagree.
        - "Where do I start": one next step. Meet their faith level (\(faith)).

        BOUNDARIES:
        Never claim to be God or a replacement for church. Mental health crisis → compassion \
        first, then gently point to a counselor or 988 Lifeline. Stay Christ-centered.

        FOLLOW-UP SUGGESTIONS:
        At the very end, add exactly 3 short follow-ups on one line like this:
        |||Suggestion one|||Suggestion two|||Suggestion three|||
        Keep each under 8 words. Make them contextual.
        """
    }

    // MARK: - Follow-Up Suggestion Parsing

    /// Extracts follow-up suggestions from the AI response and returns
    /// the cleaned content + suggestion array.
    static func extractSuggestions(from content: String) -> (cleanedContent: String, suggestions: [String]) {
        // Look for the |||suggestion||| pattern at the end
        let pattern = #"\|\|\|(.+?)\|\|\|(.+?)\|\|\|(.+?)\|\|\|\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length))
        else {
            return (content, [])
        }

        var suggestions: [String] = []
        for i in 1...3 {
            if let range = Range(match.range(at: i), in: content) {
                let suggestion = String(content[range]).trimmingCharacters(in: .whitespaces)
                if !suggestion.isEmpty {
                    suggestions.append(suggestion)
                }
            }
        }

        // Remove the suggestion line from content
        let cleanedContent: String
        if let matchRange = Range(match.range, in: content) {
            cleanedContent = String(content[content.startIndex..<matchRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleanedContent = content
        }

        return (cleanedContent, suggestions)
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
        PRAYER MODE ACTIVATED \u{2014} \(name) has asked you to pray.

        RIGHT NOW, write an actual prayer addressed to God. Not a lesson about prayer. \
        Not an explanation. An intimate, heartfelt prayer that speaks directly to the Father \
        about what \(name) shared.

        FORMAT:
        - Begin with a warm address to God (e.g., "Father," "Lord," "Heavenly Father,")
        - Pray through \(name)'s specific situation \u{2014} use their words back to God
        - Include 1 Scripture woven naturally into the prayer (not as a separate reference)
        - Close with "In Jesus' name, Amen."
        - The entire response should BE the prayer \u{2014} nothing before it, nothing after it
        - Keep it 2-3 paragraphs. Intimate, not performative.
        """
    }

    // MARK: - Rate Limiting

    static let freeMessagesPerWeek = 3

    static func messagesUsedThisWeek(messages: [ChatMessage]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        return messages.filter { $0.role == .user && $0.createdAt >= startOfWeek }.count
    }

    static func canSendMessage(messages: [ChatMessage], isPro: Bool) -> Bool {
        if isPro { return true }
        return messagesUsedThisWeek(messages: messages) < freeMessagesPerWeek
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
            "max_tokens": 500,
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
