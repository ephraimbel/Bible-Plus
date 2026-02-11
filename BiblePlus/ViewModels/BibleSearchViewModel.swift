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

@MainActor
@Observable
final class BibleSearchViewModel {
    var query: String = ""
    var results: [BibleSearchResult] = []
    var isSearching: Bool = false
    var errorMessage: String? = nil
    var totalResults: Int = 0
    var hasMoreResults: Bool = false

    let currentTranslation: BibleTranslation

    private var currentPage: Int = 1
    private let pageLimit = 30
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init(translation: BibleTranslation) {
        self.currentTranslation = translation
    }

    func searchDebounced() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
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
        totalResults = 0
        hasMoreResults = false
        errorMessage = nil
        currentPage = 1
    }

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
