import Foundation

final class BibleRepository {
    static let shared = BibleRepository()

    // [BookID: [ChapterNum: [VerseNum: Text]]]
    private var verseData: [String: [String: [String: String]]] = [:]
    private var translation: String = "KJV"

    private init() {
        loadBundledBible()
    }

    // MARK: - Data Access

    func verses(book: String, chapter: Int) -> [(number: Int, text: String)] {
        let chapterKey = "\(chapter)"
        guard let chapterData = verseData[book]?[chapterKey] else { return [] }

        return chapterData
            .compactMap { key, value -> (number: Int, text: String)? in
                guard let num = Int(key) else { return nil }
                return (number: num, text: value)
            }
            .sorted { $0.number < $1.number }
    }

    func verse(book: String, chapter: Int, verse: Int) -> String? {
        verseData[book]?["\(chapter)"]?["\(verse)"]
    }

    func hasContent(book: String, chapter: Int) -> Bool {
        guard let chapterData = verseData[book]?["\(chapter)"] else { return false }
        return !chapterData.isEmpty
    }

    func availableChapters(for bookID: String) -> [Int] {
        guard let bookData = verseData[bookID] else { return [] }
        return bookData.keys.compactMap { Int($0) }.sorted()
    }

    var currentTranslation: String { translation }

    // MARK: - Loading

    private func loadBundledBible() {
        guard let url = Bundle.main.url(forResource: "bible-kjv", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let t = json["translation"] as? String {
            translation = t
        }

        if let books = json["books"] as? [String: [String: [String: String]]] {
            verseData = books
        }
    }
}
