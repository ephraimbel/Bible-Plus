import Foundation

struct BibleSearchResult: Identifiable {
    let id = UUID()
    let book: BibleBook
    let chapter: Int
    let verseNumber: Int
    let text: String

    var reference: String {
        "\(book.name) \(chapter):\(verseNumber)"
    }
}

struct BookNavigationMatch: Identifiable {
    let id = UUID()
    let book: BibleBook
    let chapter: Int?       // nil = whole book
    let verseNumber: Int?   // nil = whole chapter

    var displayTitle: String {
        var title = book.name
        if let chapter {
            title += " \(chapter)"
            if let verseNumber {
                title += ":\(verseNumber)"
            }
        }
        return title
    }

    var subtitle: String {
        if chapter != nil {
            return "Go to chapter"
        }
        return "\(book.chapterCount) chapter\(book.chapterCount == 1 ? "" : "s") · \(book.testament.displayName)"
    }
}

@MainActor
@Observable
final class BibleSearchViewModel {
    var query: String = ""
    var results: [BibleSearchResult] = []
    var bookMatches: [BookNavigationMatch] = []
    var isSearching: Bool = false
    var errorMessage: String? = nil
    var totalResults: Int = 0
    var hasMoreResults: Bool = false

    let currentTranslation: BibleTranslation

    private var currentPage: Int = 1
    private let pageLimit = 30
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    // Pre-computed search index: [(lowercased name, book)]
    private static let searchIndex: [(name: String, book: BibleBook)] = {
        var entries: [(String, BibleBook)] = []
        for book in BibleData.allBooks {
            for name in searchNames(for: book) {
                entries.append((name, book))
            }
        }
        return entries
    }()

    init(translation: BibleTranslation) {
        self.currentTranslation = translation
    }

    func searchDebounced() {
        // Instant local book matching (no debounce, works from 1 char)
        updateBookMatches()

        // Debounced API verse text search
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }

    func loadMore() {
        guard hasMoreResults, !isSearching else { return }
        currentPage += 1
        searchTask?.cancel()
        searchTask = Task {
            await fetchPage(page: currentPage, append: true)
        }
    }

    func clear() {
        debounceTask?.cancel()
        searchTask?.cancel()
        query = ""
        results = []
        bookMatches = []
        totalResults = 0
        hasMoreResults = false
        errorMessage = nil
        currentPage = 1
    }

    // MARK: - Book Matching Engine

    private func updateBookMatches() {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else {
            bookMatches = []
            return
        }
        bookMatches = Self.matchBooks(trimmed)
    }

    /// Generate all searchable name variants for a book (all lowercased).
    private static func searchNames(for book: BibleBook) -> [String] {
        var names: [String] = []
        let lower = book.name.lowercased()
        let abbr = book.id.lowercased()

        // Full name: "1 corinthians"
        names.append(lower)
        // Abbreviation: "1co"
        names.append(abbr)

        // Compact form without spaces: "1corinthians"
        let compact = lower.replacingOccurrences(of: " ", with: "")
        if compact != lower {
            names.append(compact)
        }

        // Common aliases
        let aliases: [String: [String]] = [
            "GEN": ["gen", "gn"],
            "EXO": ["exod", "ex"],
            "LEV": ["lev", "lv"],
            "NUM": ["num", "nm", "numb"],
            "DEU": ["deut", "dt"],
            "JOS": ["josh"],
            "JDG": ["judg", "jdg"],
            "RUT": ["ruth", "ru"],
            "1SA": ["1 sam", "1sam", "1 sm"],
            "2SA": ["2 sam", "2sam", "2 sm"],
            "1KI": ["1 kgs", "1kgs", "1 kings", "1kings"],
            "2KI": ["2 kgs", "2kgs", "2 kings", "2kings"],
            "1CH": ["1 chr", "1chr", "1 chron", "1chron"],
            "2CH": ["2 chr", "2chr", "2 chron", "2chron"],
            "EZR": ["ezr"],
            "NEH": ["neh"],
            "EST": ["esth"],
            "JOB": ["job", "jb"],
            "PSA": ["psalm", "ps", "psa", "pslm"],
            "PRO": ["prov", "prv"],
            "ECC": ["eccl", "eccles", "ecc", "qoh"],
            "SNG": ["song", "sos", "song of songs", "canticles"],
            "ISA": ["isa", "is"],
            "JER": ["jer", "jr"],
            "LAM": ["lam", "la"],
            "EZK": ["ezek", "eze", "ezk"],
            "DAN": ["dan", "dn"],
            "HOS": ["hos", "ho"],
            "JOL": ["joel", "jl"],
            "AMO": ["amos", "am"],
            "OBA": ["obad", "ob"],
            "JON": ["jon", "jnh"],
            "MIC": ["mic", "mc"],
            "NAM": ["nah", "na"],
            "HAB": ["hab"],
            "ZEP": ["zeph", "zep"],
            "HAG": ["hag", "hg"],
            "ZEC": ["zech", "zec"],
            "MAL": ["mal", "ml"],
            "MAT": ["matt", "mt", "mat"],
            "MRK": ["mark", "mk", "mrk"],
            "LUK": ["luke", "lk", "luk"],
            "JHN": ["jn", "jhn"],
            "ACT": ["acts", "ac"],
            "ROM": ["rom", "ro", "rm"],
            "1CO": ["1 cor", "1cor", "1 corin", "1corin"],
            "2CO": ["2 cor", "2cor", "2 corin", "2corin"],
            "GAL": ["gal", "ga"],
            "EPH": ["eph"],
            "PHP": ["phil", "php", "pp"],
            "COL": ["col"],
            "1TH": ["1 thess", "1thess", "1 thes", "1thes", "1 th"],
            "2TH": ["2 thess", "2thess", "2 thes", "2thes", "2 th"],
            "1TI": ["1 tim", "1tim", "1 ti"],
            "2TI": ["2 tim", "2tim", "2 ti"],
            "TIT": ["tit", "ti"],
            "PHM": ["phlm", "phm", "philem"],
            "HEB": ["heb"],
            "JAS": ["jas", "jm"],
            "1PE": ["1 pet", "1pet", "1 pt"],
            "2PE": ["2 pet", "2pet", "2 pt"],
            "1JN": ["1 john", "1john", "1 jn"],
            "2JN": ["2 john", "2john", "2 jn"],
            "3JN": ["3 john", "3john", "3 jn"],
            "JUD": ["jude", "jd"],
            "REV": ["rev", "revelations", "apocalypse"],
        ]

        if let bookAliases = aliases[book.id] {
            for alias in bookAliases {
                if !names.contains(alias) {
                    names.append(alias)
                }
            }
        }

        // Sort longest-first so "1 corinthians" matches before "1 cor"
        names.sort { $0.count > $1.count }
        return names
    }

    /// Match books against query. Returns matches sorted by relevance.
    private static func matchBooks(_ query: String) -> [BookNavigationMatch] {
        var matches: [BookNavigationMatch] = []
        var seenBookIDs: Set<String> = []

        for (name, book) in searchIndex {
            guard !seenBookIDs.contains(book.id) else { continue }

            // Case 1: Query starts with a known book name (exact or prefix)
            // e.g. "john 3:16" starts with "john"
            if query.hasPrefix(name) {
                let remainder = String(query.dropFirst(name.count)).trimmingCharacters(in: .whitespaces)
                if remainder.isEmpty {
                    // Exact book match: "john" or "1 corinthians"
                    matches.append(BookNavigationMatch(book: book, chapter: nil, verseNumber: nil))
                } else if let (chapter, verse) = parseChapterVerse(remainder), chapter >= 1, chapter <= book.chapterCount {
                    // Book + chapter(:verse): "john 3" or "john 3:16"
                    matches.append(BookNavigationMatch(book: book, chapter: chapter, verseNumber: verse))
                }
                seenBookIDs.insert(book.id)
                continue
            }

            // Case 2: A book name starts with the query (partial match)
            // e.g. "gen" matches "genesis"
            if name.hasPrefix(query) {
                matches.append(BookNavigationMatch(book: book, chapter: nil, verseNumber: nil))
                seenBookIDs.insert(book.id)
            }
        }

        return matches
    }

    /// Parse a string like "3", "3:16", "13:4" into (chapter, verse?).
    private static func parseChapterVerse(_ s: String) -> (Int, Int?)? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":", maxSplits: 1)
        guard let chapter = Int(parts[0].trimmingCharacters(in: .whitespaces)), chapter > 0 else {
            return nil
        }

        if parts.count == 2 {
            let verse = Int(parts[1].trimmingCharacters(in: .whitespaces))
            return (chapter, verse)
        }

        return (chapter, nil)
    }

    // MARK: - API Verse Search

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            results = []
            totalResults = 0
            hasMoreResults = false
            errorMessage = nil
            return
        }

        currentPage = 1
        searchTask?.cancel()
        searchTask = Task {
            await fetchPage(page: 1, append: false)
        }
    }

    private func fetchPage(page: Int, append: Bool) async {
        if !append {
            isSearching = true
            errorMessage = nil
        }

        if currentTranslation.isBundled {
            await fetchBundledPage(page: page, append: append)
        } else {
            await fetchAPIPage(page: page, append: append)
        }
    }

    private func fetchBundledPage(page: Int, append: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let offset = (page - 1) * pageLimit

        let response = BibleRepository.shared.searchBundled(
            query: trimmed,
            translation: currentTranslation,
            limit: pageLimit,
            offset: offset
        )

        guard !Task.isCancelled else { return }

        let mapped = response.results.compactMap { result -> BibleSearchResult? in
            guard let book = BibleData.book(id: result.bookID) else { return nil }
            return BibleSearchResult(
                book: book,
                chapter: result.chapter,
                verseNumber: result.verse,
                text: result.text
            )
        }

        if append {
            results.append(contentsOf: mapped)
        } else {
            results = mapped
        }

        totalResults = response.total
        hasMoreResults = results.count < response.total
        isSearching = false
    }

    private func fetchAPIPage(page: Int, append: Bool) async {
        do {
            let response = try await BibleAPIService.searchVerses(
                translation: currentTranslation.apiCode,
                query: query.trimmingCharacters(in: .whitespaces),
                page: page,
                limit: pageLimit
            )

            guard !Task.isCancelled else { return }

            let mapped = response.results.compactMap { verse -> BibleSearchResult? in
                let bookIndex = verse.book - 1
                guard bookIndex >= 0, bookIndex < BibleData.allBooks.count else { return nil }
                let book = BibleData.allBooks[bookIndex]
                return BibleSearchResult(
                    book: book,
                    chapter: verse.chapter,
                    verseNumber: verse.verse,
                    text: verse.text
                )
            }

            if append {
                results.append(contentsOf: mapped)
            } else {
                results = mapped
            }

            totalResults = response.total
            hasMoreResults = results.count < response.total
            isSearching = false
        } catch {
            guard !Task.isCancelled else { return }
            if !append {
                results = []
            }
            errorMessage = error.localizedDescription
            isSearching = false
        }
    }
}
