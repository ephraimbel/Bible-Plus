import Foundation

enum BibleAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid request URL."
        case .networkError(let error):
            error.localizedDescription
        case .invalidResponse(let code):
            "Server returned status \(code)."
        case .decodingError:
            "Could not read chapter data."
        }
    }
}

enum BibleAPIService {
    private static let baseURL = "https://bolls.life/get-text"

    private struct APIVerse: Decodable {
        let pk: Int
        let verse: Int
        let text: String
    }

    static func fetchChapter(
        translation: String,
        bookNumber: Int,
        chapter: Int
    ) async throws -> [(number: Int, text: String)] {
        guard let url = URL(string: "\(baseURL)/\(translation)/\(bookNumber)/\(chapter)/") else {
            throw BibleAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BibleAPIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw BibleAPIError.invalidResponse(http.statusCode)
        }

        guard let verses = try? JSONDecoder().decode([APIVerse].self, from: data) else {
            throw BibleAPIError.decodingError
        }

        return verses.map { (number: $0.verse, text: cleanText($0.text)) }
    }

    private static func cleanText(_ text: String) -> String {
        // Strip HTML tags (e.g. Strong's concordance <S>1234</S> in KJV)
        let stripped = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Collapse multiple whitespace into single space
        return stripped
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
