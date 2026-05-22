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

    // MARK: - Search

    struct SearchResultVerse: Decodable {
        let pk: Int
        let verse: Int
        let text: String
        let book: Int
        let chapter: Int
    }

    struct SearchResponse: Decodable {
        let results: [SearchResultVerse]
        let total: Int
    }

    static func searchVerses(
        translation: String,
        query: String,
        page: Int = 1,
        limit: Int = 30
    ) async throws -> SearchResponse {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://bolls.life/v2/find/\(translation)?search=\(encodedQuery)&page=\(page)&limit=\(limit)")
        else {
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

        guard let searchResponse = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            throw BibleAPIError.decodingError
        }

        return SearchResponse(
            results: searchResponse.results.map {
                SearchResultVerse(
                    pk: $0.pk,
                    verse: $0.verse,
                    text: cleanText($0.text),
                    book: $0.book,
                    chapter: $0.chapter
                )
            },
            total: searchResponse.total
        )
    }

    // MARK: - HelloAO (multi-language catalog)

    /// Response shape for `bible.helloao.org/api/{translation_id}/{book}/{chapter}.json`.
    /// Verses' `content` is an array that normally holds plain strings, but
    /// can contain nested formatting/note objects for some translations —
    /// we flatten by keeping only the strings.
    private struct HelloAOChapterResponse: Decodable {
        struct BookInfo: Decodable {
            let id: String
            let name: String
            let commonName: String?
        }
        struct ChapterBlock: Decodable {
            let number: Int
            let content: [ChapterItem]
        }
        struct ChapterItem: Decodable {
            let type: String?
            let number: Int?
            let content: [ContentFragment]?

            enum CodingKeys: String, CodingKey {
                case type, number, content
            }
        }
        /// `content` entries can be either a string or a nested object.
        /// We decode defensively — anything not a plain string becomes nil.
        enum ContentFragment: Decodable {
            case text(String)
            case other

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let s = try? container.decode(String.self) {
                    self = .text(s)
                } else {
                    self = .other
                }
            }
        }
        let book: BookInfo
        let chapter: ChapterBlock
    }

    /// Fetch a single chapter from helloao. Returns the localized book name
    /// plus `(verse number, text)` pairs so callers can both render verses
    /// and update their book-name caches for the target language.
    static func fetchHelloAOChapter(
        translationID: String,
        bookID: String,
        chapter: Int
    ) async throws -> (bookName: String, verses: [(number: Int, text: String)]) {
        guard let url = URL(string: "https://bible.helloao.org/api/\(translationID)/\(bookID)/\(chapter).json") else {
            throw BibleAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

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
        guard let decoded = try? JSONDecoder().decode(HelloAOChapterResponse.self, from: data) else {
            throw BibleAPIError.decodingError
        }
        var verses: [(number: Int, text: String)] = []
        for item in decoded.chapter.content where item.type == "verse" {
            guard let num = item.number, let frags = item.content else { continue }
            // Join all plain-text fragments with a single space. Drops any
            // non-text objects (headings, Strong's tags, etc.) so the verse
            // text stays clean and readable.
            let text = frags.compactMap { frag -> String? in
                if case .text(let s) = frag { return s }
                return nil
            }.joined(separator: " ")
            let cleaned = cleanText(text)
            if !cleaned.isEmpty {
                verses.append((number: num, text: cleaned))
            }
        }
        return (bookName: decoded.book.commonName ?? decoded.book.name, verses: verses)
    }

    /// Response shape for `bible.helloao.org/api/{translation_id}/books.json`.
    /// Each entry is a book in the translation with its localized name.
    struct HelloAOBooksResponse: Decodable {
        struct BookEntry: Decodable {
            let id: String          // USFM (GEN, EXO, …)
            let name: String
            let commonName: String?
            let numberOfChapters: Int
        }
        let books: [BookEntry]
    }

    /// Fetch the list of books for a translation so the app can show
    /// localized book names in the picker *before* any chapter is opened.
    /// Cheaper than per-chapter fetches and uses the same helloao catalog.
    static func fetchHelloAOBooks(translationID: String) async throws -> [(id: String, name: String)] {
        guard let url = URL(string: "https://bible.helloao.org/api/\(translationID)/books.json") else {
            throw BibleAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
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
        guard let decoded = try? JSONDecoder().decode(HelloAOBooksResponse.self, from: data) else {
            throw BibleAPIError.decodingError
        }
        return decoded.books.map { ($0.id, $0.commonName ?? $0.name) }
    }

    // MARK: - Text Cleaning

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
