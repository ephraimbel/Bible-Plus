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

    // MARK: - Multi-language (helloao catalog) Access

    /// In-memory cache of localized book names keyed by `translationID/bookID`.
    /// helloao returns localized names as part of each chapter payload, so we
    /// opportunistically cache them as we fetch chapters. Readers can query
    /// `localizedBookName(…)` to show e.g. "Génesis" instead of "Genesis"
    /// without waiting for a full book-list roundtrip.
    private var localizedBookNames: [String: String] = [:]

    /// Async fetch for a helloao-catalog translation. Routes through the same
    /// disk cache as legacy API translations so a chapter read once is offline
    /// forever. The `bookID` argument must be a USFM abbreviation (GEN, EXO,
    /// …, REV) — helloao uses the same vocabulary as `BibleData`.
    func verses(ref: TranslationRef, book: String, chapter: Int) async throws -> [(number: Int, text: String)] {
        return try await verses(refID: ref.id, book: book, chapter: chapter)
    }

    /// ID-only overload. The Bible reader stores the user's pick as a String
    /// (`UserProfile.preferredTranslationRefID`) and may try to fetch *before*
    /// `TranslationCatalog` has finished its background manifest refresh —
    /// without this overload, the fetch falls through to bundled KJV until
    /// the catalog lands, which is a surprisingly common race on first launch.
    /// We don't actually need any catalog metadata to fetch a chapter — just
    /// the refID — so this skips the catalog lookup entirely.
    func verses(refID: String, book: String, chapter: Int) async throws -> [(number: Int, text: String)] {
        // Bundled refs map back to legacy path so existing cache/bundled JSON
        // paths stay authoritative for KJV/WEB.
        if refID.hasPrefix(TranslationRef.bundledPrefix) {
            let legacy: BibleTranslation = (refID == TranslationRef.bundledWEB.id) ? .web : .kjv
            return try await verses(book: book, chapter: chapter, translation: legacy)
        }

        let cacheKey = "ref:\(refID)/\(book)/\(chapter)" as NSString
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached.verses
        }
        if let diskVerses = readDiskCacheForRef(refID: refID, book: book, chapter: chapter) {
            memoryCache.setObject(CachedChapter(verses: diskVerses), forKey: cacheKey)
            return diskVerses
        }

        let result = try await BibleAPIService.fetchHelloAOChapter(
            translationID: refID,
            bookID: book,
            chapter: chapter
        )
        lock.lock()
        localizedBookNames["\(refID)/\(book)"] = result.bookName
        lock.unlock()

        memoryCache.setObject(CachedChapter(verses: result.verses), forKey: cacheKey)
        writeDiskCacheForRef(verses: result.verses, refID: refID, book: book, chapter: chapter)
        return result.verses
    }

    /// The last-seen localized book name for `(ref, bookID)`. Returns `nil`
    /// if no chapter in that book has been fetched yet — callers should fall
    /// back to `BibleData.allBooks` English names.
    func localizedBookName(refID: String, bookID: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return localizedBookNames["\(refID)/\(bookID)"]
    }

    /// Prime the localized book-name cache for a translation by fetching
    /// `/api/{id}/books.json` once. Call this when the user picks a ref so
    /// `BookPickerView` can immediately show "Génesis"/"Salmos"/etc. without
    /// waiting for each chapter to be opened. Idempotent: re-running is
    /// effectively a no-op (just overwrites with the same values) and the
    /// network fetch is short-circuited if the file is on disk.
    func prefetchBookNames(refID: String) async {
        // Skip when already populated — cheap check to avoid re-fetching.
        lock.lock()
        let alreadyPopulated = localizedBookNames.keys.contains(where: { $0.hasPrefix("\(refID)/") })
        lock.unlock()
        if alreadyPopulated { return }

        // Try disk first.
        if let disk = readBookNamesCacheForRef(refID: refID), !disk.isEmpty {
            lock.lock()
            for (bookID, name) in disk {
                localizedBookNames["\(refID)/\(bookID)"] = name
            }
            lock.unlock()
            return
        }

        // Network fetch. Silent failure is fine — we fall back to English.
        guard let entries = try? await BibleAPIService.fetchHelloAOBooks(translationID: refID) else {
            return
        }
        lock.lock()
        for (bookID, name) in entries {
            localizedBookNames["\(refID)/\(bookID)"] = name
        }
        lock.unlock()
        writeBookNamesCacheForRef(refID: refID, entries: entries)
    }

    private func bookNamesCacheURL(refID: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("BibleCache", isDirectory: true)
            .appendingPathComponent("ref-\(refID)", isDirectory: true)
            .appendingPathComponent("_books.json")
    }

    private func readBookNamesCacheForRef(refID: String) -> [(String, String)]? {
        let url = bookNamesCacheURL(refID: refID)
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        return dict.map { ($0.key, $0.value) }
    }

    private func writeBookNamesCacheForRef(refID: String, entries: [(id: String, name: String)]) {
        let url = bookNamesCacheURL(refID: refID)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dict = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.name) })
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func diskCacheURLForRef(refID: String, book: String, chapter: Int) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("BibleCache", isDirectory: true)
            .appendingPathComponent("ref-\(refID)", isDirectory: true)
            .appendingPathComponent(book, isDirectory: true)
            .appendingPathComponent("\(chapter).json")
    }

    private func readDiskCacheForRef(refID: String, book: String, chapter: Int) -> [(number: Int, text: String)]? {
        let url = diskCacheURLForRef(refID: refID, book: book, chapter: chapter)
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

    private func writeDiskCacheForRef(verses: [(number: Int, text: String)], refID: String, book: String, chapter: Int) {
        let url = diskCacheURLForRef(refID: refID, book: book, chapter: chapter)
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
