import Foundation

final class BibleRepository: @unchecked Sendable {
    static let shared = BibleRepository()

    private(set) var currentTranslation: BibleTranslation = .kjv

    // MARK: - In-Memory Cache

    private let memoryCache = NSCache<NSString, CachedChapter>()

    // MARK: - Init

    private init() {
        memoryCache.countLimit = 200
    }

    // MARK: - Translation

    func setTranslation(_ translation: BibleTranslation) {
        currentTranslation = translation
    }

    // MARK: - Async Access (Network-backed)

    func verses(book: String, chapter: Int, translation: BibleTranslation? = nil) async throws -> [(number: Int, text: String)] {
        let trans = translation ?? currentTranslation
        let cacheKey = Self.cacheKey(book: book, chapter: chapter, translation: trans)

        // 1. Memory cache
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached.verses
        }

        // 2. Disk cache
        if let diskVerses = readDiskCache(book: book, chapter: chapter, translation: trans) {
            let cached = CachedChapter(verses: diskVerses)
            memoryCache.setObject(cached, forKey: cacheKey as NSString)
            return diskVerses
        }

        // 3. Network fetch
        guard let bookNumber = BibleData.apiBookNumber(for: book) else { return [] }

        let fetched = try await BibleAPIService.fetchChapter(
            translation: trans.apiCode,
            bookNumber: bookNumber,
            chapter: chapter
        )

        // Cache results
        let cached = CachedChapter(verses: fetched)
        memoryCache.setObject(cached, forKey: cacheKey as NSString)
        writeDiskCache(verses: fetched, book: book, chapter: chapter, translation: trans)

        return fetched
    }

    // MARK: - Synchronous Access (Offline / Widget)

    func versesSync(book: String, chapter: Int, translation: BibleTranslation? = nil) -> [(number: Int, text: String)] {
        let trans = translation ?? currentTranslation
        let cacheKey = Self.cacheKey(book: book, chapter: chapter, translation: trans)

        // Memory cache
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached.verses
        }

        // Disk cache
        if let diskVerses = readDiskCache(book: book, chapter: chapter, translation: trans) {
            let cached = CachedChapter(verses: diskVerses)
            memoryCache.setObject(cached, forKey: cacheKey as NSString)
            return diskVerses
        }

        // Bundled KJV fallback
        return bundledFallback(book: book, chapter: chapter)
    }

    // MARK: - Bundled KJV Fallback

    func bundledFallback(book: String, chapter: Int) -> [(number: Int, text: String)] {
        guard let url = Bundle.main.url(forResource: "bible-kjv", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let books = json["books"] as? [String: [String: [String: String]]],
              let chapterData = books[book]?["\(chapter)"]
        else { return [] }

        return chapterData
            .compactMap { key, value -> (number: Int, text: String)? in
                guard let num = Int(key) else { return nil }
                return (number: num, text: value)
            }
            .sorted { $0.number < $1.number }
    }

    // MARK: - Cache Key

    private static func cacheKey(book: String, chapter: Int, translation: BibleTranslation) -> String {
        "\(translation.apiCode)/\(book)/\(chapter)"
    }

    // MARK: - Disk Cache

    private func diskCacheURL(book: String, chapter: Int, translation: BibleTranslation) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("BibleCache", isDirectory: true)
            .appendingPathComponent(translation.apiCode, isDirectory: true)
            .appendingPathComponent(book, isDirectory: true)
            .appendingPathComponent("\(chapter).json")
    }

    private func readDiskCache(book: String, chapter: Int, translation: BibleTranslation) -> [(number: Int, text: String)]? {
        let url = diskCacheURL(book: book, chapter: chapter, translation: translation)
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }

        let verses = dict
            .compactMap { key, value -> (number: Int, text: String)? in
                guard let num = Int(key) else { return nil }
                return (number: num, text: value)
            }
            .sorted { $0.number < $1.number }

        return verses.isEmpty ? nil : verses
    }

    private func writeDiskCache(verses: [(number: Int, text: String)], book: String, chapter: Int, translation: BibleTranslation) {
        let url = diskCacheURL(book: book, chapter: chapter, translation: translation)
        let dir = url.deletingLastPathComponent()

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var dict: [String: String] = [:]
        for v in verses {
            dict["\(v.number)"] = v.text
        }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - NSCache Value Wrapper

private final class CachedChapter {
    let verses: [(number: Int, text: String)]
    init(verses: [(number: Int, text: String)]) {
        self.verses = verses
    }
}
