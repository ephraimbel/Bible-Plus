import Foundation

final class BibleRepository: @unchecked Sendable {
    static let shared = BibleRepository()

    private let lock = NSLock()
    private var _currentTranslation: BibleTranslation = .kjv

    var currentTranslation: BibleTranslation {
        lock.lock()
        defer { lock.unlock() }
        return _currentTranslation
    }

    // MARK: - In-Memory Cache

    private let memoryCache = NSCache<NSString, CachedChapter>()

    /// Lazily loaded bundled Bible data — parsed once per translation, kept in memory.
    private var bundledData: [String: [String: [String: [String: String]]]] = [:]
    private var bundledLoaded: Set<String> = []

    // MARK: - Init

    private init() {
        memoryCache.countLimit = 200
    }

    // MARK: - Translation

    func setTranslation(_ translation: BibleTranslation) {
        lock.lock()
        _currentTranslation = translation
        lock.unlock()
    }

    // MARK: - Async Access

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

        // 3. Bundled data (KJV + WEB — full Bible offline, no network needed)
        if trans.isBundled {
            let bundled = bundledFallback(book: book, chapter: chapter, translation: trans)
            if !bundled.isEmpty {
                let cached = CachedChapter(verses: bundled)
                memoryCache.setObject(cached, forKey: cacheKey as NSString)
                return bundled
            }
        }

        // 4. Network fetch (for non-bundled translations)
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

        // Bundled fallback
        let bundled = bundledFallback(book: book, chapter: chapter, translation: trans)
        if !bundled.isEmpty {
            let cached = CachedChapter(verses: bundled)
            memoryCache.setObject(cached, forKey: cacheKey as NSString)
        }
        return bundled
    }

    // MARK: - Bundled Data (Loaded Once Per Translation, Cached in Memory)

    func bundledFallback(book: String, chapter: Int, translation: BibleTranslation? = nil) -> [(number: Int, text: String)] {
        let trans = translation ?? currentTranslation
        let resourceName = bundledResourceName(for: trans)

        lock.lock()
        if !bundledLoaded.contains(resourceName) {
            if let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let books = json["books"] as? [String: [String: [String: String]]] {
                bundledData[resourceName] = books
            }
            bundledLoaded.insert(resourceName)
        }
        let books = bundledData[resourceName]
        lock.unlock()

        guard let chapterData = books?[book]?["\(chapter)"] else { return [] }

        return chapterData
            .compactMap { key, value -> (number: Int, text: String)? in
                guard let num = Int(key) else { return nil }
                return (number: num, text: value)
            }
            .sorted { $0.number < $1.number }
    }

    private func bundledResourceName(for translation: BibleTranslation) -> String {
        switch translation {
        case .kjv: "bible-kjv"
        case .web: "bible-web"
        default: "bible-kjv" // Fallback to KJV for non-bundled translations
        }
    }

    // MARK: - Bundled Search

    struct BundledSearchResponse {
        let results: [(bookID: String, chapter: Int, verse: Int, text: String)]
        let total: Int
    }

    func searchBundled(query: String, translation: BibleTranslation, limit: Int = 30, offset: Int = 0) -> BundledSearchResponse {
        let resourceName = bundledResourceName(for: translation)

        // Ensure bundled data is loaded
        lock.lock()
        if !bundledLoaded.contains(resourceName) {
            if let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let books = json["books"] as? [String: [String: [String: String]]] {
                bundledData[resourceName] = books
            }
            bundledLoaded.insert(resourceName)
        }
        let books = bundledData[resourceName]
        lock.unlock()

        guard let books else { return BundledSearchResponse(results: [], total: 0) }

        let lowercasedQuery = query.lowercased()
        var allMatches: [(bookID: String, chapter: Int, verse: Int, text: String)] = []

        // Iterate in canonical book order
        for book in BibleData.allBooks {
            guard let chapters = books[book.id] else { continue }
            for chapterNum in 1...book.chapterCount {
                guard let verses = chapters["\(chapterNum)"] else { continue }
                for (verseKey, verseText) in verses {
                    guard let verseNum = Int(verseKey) else { continue }
                    if verseText.lowercased().contains(lowercasedQuery) {
                        allMatches.append((bookID: book.id, chapter: chapterNum, verse: verseNum, text: verseText))
                    }
                }
            }
        }

        // Sort: book order (already iterated in order), then chapter, then verse
        allMatches.sort { lhs, rhs in
            let lhsBookIdx = BibleData.allBooks.firstIndex(where: { $0.id == lhs.bookID }) ?? 0
            let rhsBookIdx = BibleData.allBooks.firstIndex(where: { $0.id == rhs.bookID }) ?? 0
            if lhsBookIdx != rhsBookIdx { return lhsBookIdx < rhsBookIdx }
            if lhs.chapter != rhs.chapter { return lhs.chapter < rhs.chapter }
            return lhs.verse < rhs.verse
        }

        let total = allMatches.count
        let paged = Array(allMatches.dropFirst(offset).prefix(limit))
        return BundledSearchResponse(results: paged, total: total)
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
