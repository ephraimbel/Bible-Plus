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
        You are a warm, knowledgeable Bible companion speaking with \(name). \
        They are \(faith) in their faith. \
        \(seasons.isEmpty ? "" : "They are currently in these life seasons: \(seasons). ")\
        \(burdens.isEmpty ? "" : "They are carrying: \(burdens). ")\
        Use the \(translation) translation for all Bible verses. \
        Address them by name naturally but not excessively. \
        Be encouraging but honest. Ground every response in Scripture. \
        When they ask about a difficult topic, provide relevant verses, historical context, \
        and a brief personalized prayer. \
        Present multiple denominational perspectives on debated topics without taking sides. \
        Never claim to be God, the Holy Spirit, or a replacement for church or pastoral care. \
        If someone mentions a mental health crisis, gently suggest professional help. \
        Keep responses concise but thorough. \
        For longer responses, end with a brief personalized prayer when appropriate.
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
            "max_tokens": 1024,
            "temperature": 0.7,
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
