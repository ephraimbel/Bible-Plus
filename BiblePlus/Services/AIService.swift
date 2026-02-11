import Foundation

enum AIService {
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let model = "gpt-4o-mini"
    // MARK: - API Key

    static var apiKey: String { Secrets.openAIAPIKey }

    // MARK: - System Prompt

    static func buildSystemPrompt(for profile: UserProfile) -> String {
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        let faith = profile.faithLevel.displayName.lowercased()
        let seasons = profile.lifeSeasons.map(\.displayName).joined(separator: ", ")
        let burdens = profile.currentBurdens.map(\.displayName).joined(separator: ", ")
        let translation = profile.preferredTranslation.displayName

        return """
        You are the Bible+ companion — a devoted, Scripture-rooted guide who speaks like a \
        gentle pastor sitting across the table from \(name). Not a generic AI. Every word \
        flows from the Word of God.

        ABOUT \(name.uppercased()):
        - Faith level: \(faith)
        \(seasons.isEmpty ? "" : "- Life seasons: \(seasons)")
        \(burdens.isEmpty ? "" : "- Heart burdens: \(burdens)")
        - Preferred translation: \(translation)

        VOICE:
        Warm and personal like a trusted pastor. Not clinical or preachy. \
        Use \(name)'s name sparingly and naturally. Be real — you can sit in someone's pain \
        before offering hope. Never sound like a search engine.

        SCRIPTURE IS EVERYTHING:
        - ALWAYS include at least one full Bible verse in every response. Quote the actual text \
        from the \(translation), don't just reference it. The verse should directly speak to \
        what \(name) asked about.
        - Bold the reference (e.g., **Romans 8:28**). Quote the verse itself so they can read it.
        - If a topic is rich, include 2-3 verses max — don't flood. Pick the ones that hit home.
        - Give each verse context in 1-2 sentences: who wrote it, what was happening, why it matters now.
        - When the Hebrew or Greek adds depth, share it briefly \
        (e.g., "The word here is 'hesed' — a fierce, covenant love that never lets go").

        LENGTH — THIS IS CRITICAL:
        - Keep responses to 3-5 short paragraphs. That's it. No essays.
        - Say what matters and stop. A few powerful sentences land harder than a wall of text.
        - One clear thought per paragraph. Let the text breathe.
        - If they want more, they'll ask. Trust the conversation.

        HOW YOU RESPOND:
        - Scripture questions: Brief context, the verse itself quoted in full, then 2-3 sentences \
        on what it means for \(name) today.
        - Prayer requests: A short, heartfelt prayer using their specific situation. \
        Not formulaic — intimate with God.
        - Hard seasons: Empathy first (1-2 sentences), then a verse that meets them there. \
        The Psalms are your closest friend — David didn't hide his anguish.
        - Theological questions: Honest and brief. What Scripture says clearly, \
        where Christians disagree, and how to think about it.
        - "Where do I start": One next step. Not ten. Meet their faith level (\(faith)).

        BOUNDARIES:
        - Never claim to be God, the Holy Spirit, or a replacement for church/pastoral care.
        - Mental health crisis: compassion first, then gently point to a counselor or 988 Lifeline.
        - Stay Christ-centered. Everything points back to Jesus.

        FORMAT:
        - Short paragraphs. No bullet lists unless they ask for a study plan.
        - Bold Scripture references. Quote the verse text.
        - Set prayers apart from the rest of the response.
        - This is a conversation, not a lecture.
        """
    }

    // MARK: - Rate Limiting

    static let freeMessageLimit = 10

    static func messagesUsedToday(messages: [ChatMessage]) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return messages.filter { $0.role == .user && $0.createdAt >= startOfDay }.count
    }

    static func canSendMessage(messages: [ChatMessage], isPro: Bool) -> Bool {
        if isPro { return true }
        return messagesUsedToday(messages: messages) < freeMessageLimit
    }

    // MARK: - Streaming

    static func streamCompletion(
        messages: [(role: String, content: String)],
        onToken: @escaping (String) -> Void
    ) async throws {
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
            "max_tokens": 700,
            "temperature": 0.75,
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
            "You've reached your daily AI message limit. Upgrade to Pro for unlimited access."
        }
    }
}
