import Foundation
import SwiftUI
import SwiftData
import UIKit

@MainActor
@Observable
final class BibleReaderViewModel {
    // MARK: - Navigation State

    var selectedBook: BibleBook = BibleData.allBooks[0]
    var selectedChapter: Int = 1
    var showBookPicker: Bool = false
    var showTranslationPicker: Bool = false
    var showSearch: Bool = false
    var showReaderSettings: Bool = false
    var selectedVerse: VerseItem? = nil

    // MARK: - Loading State

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var isShowingOfflineFallback: Bool = false

    // MARK: - Data

    var verses: [(number: Int, text: String)] = []
    var currentTranslation: BibleTranslation = .kjv
    /// When non-nil (and not a bundled-prefix id), the reader fetches chapters
    /// from bible.helloao.org for this translation instead of using the legacy
    /// enum path. Written in two ways: (a) user picks from the multilingual
    /// picker, persisted to `UserProfile.preferredTranslationRefID`; or (b)
    /// language change auto-seeds the default via `LanguageDefaultBible`.
    var currentRefID: String? = nil

    // MARK: - Saved Verses

    var savedVerseMap: [Int: SavedBibleVerse] = [:]

    var savedVerseNumbers: Set<Int> {
        Set(savedVerseMap.keys)
    }

    var highlightColors: [Int: VerseHighlightColor] {
        var map: [Int: VerseHighlightColor] = [:]
        for (number, saved) in savedVerseMap {
            if let color = saved.highlightColor {
                map[number] = color
            }
        }
        return map
    }

    var verseNotes: [Int: String] {
        var map: [Int: String] = [:]
        for (number, saved) in savedVerseMap {
            if !saved.notes.isEmpty {
                map[number] = saved.notes
            }
        }
        return map
    }

    // MARK: - Reader Settings

    var readerFontSize: Double = 20
    var readerFontStyle: ReaderFontStyle = .serif
    var readerFontWeight: ReaderFontWeight = .regular
    var readerLineSpacing: Double = 6
    var readerTextAlignmentJustified: Bool = false
    var readerShowVerseNumbers: Bool = true

    // MARK: - Last Read Position

    var lastReadVerseNumber: Int? = nil

    var readerFontDesign: Font.Design {
        readerFontStyle.fontDesign
    }

    private let repository = BibleRepository.shared
    private let modelContext: ModelContext
    private nonisolated(unsafe) var loadTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Chapter Read Tracking

    /// Minimum seconds on a chapter before it counts as "read"
    private static let chapterReadThreshold: TimeInterval = 15

    /// Timestamp when the current chapter finished loading
    private var chapterLoadedAt: Date?

    /// Detail string for the chapter currently being read (e.g. "Genesis 1")
    private var pendingChapterDetail: String?

    /// Human-visible translation label. Prefers the catalog ref's shortName
    /// (e.g. "R09" for Reina-Valera 1909) so non-English users don't see a
    /// stale "KJV" badge, and falls back to the legacy enum's abbreviation.
    var translationName: String {
        if let refID = currentRefID,
           !refID.hasPrefix(TranslationRef.bundledPrefix),
           let ref = TranslationCatalog.shared.translation(id: refID) {
            return ref.shortName
        }
        return currentTranslation.abbreviation
    }

    /// Localized book name for the active translation when available (e.g.
    /// "Génesis" for Spanish Reina-Valera). Falls back to the English name
    /// from `BibleData` until the first chapter of that book is fetched.
    var localizedBookName: String {
        if let refID = currentRefID,
           !refID.hasPrefix(TranslationRef.bundledPrefix),
           let localized = repository.localizedBookName(refID: refID, bookID: selectedBook.id) {
            return localized
        }
        return selectedBook.name
    }

    var hasContent: Bool { !verses.isEmpty }

    var chapterTitle: String {
        "\(localizedBookName) \(selectedChapter)"
    }

    var canGoBack: Bool {
        selectedChapter > 1 || BibleData.allBooks.firstIndex(of: selectedBook) ?? 0 > 0
    }

    var canGoForward: Bool {
        selectedChapter < selectedBook.chapterCount
            || (BibleData.allBooks.firstIndex(of: selectedBook) ?? 0) < BibleData.allBooks.count - 1
    }

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Read user preferences
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            currentTranslation = profile.preferredTranslation
            readerFontSize = profile.readerFontSize
            readerFontStyle = profile.readerFontStyle
            readerFontWeight = profile.readerFontWeight
            readerLineSpacing = profile.readerLineSpacing
            readerTextAlignmentJustified = profile.textAlignmentJustified
            readerShowVerseNumbers = profile.showVerseNumbers

            // Resolve the active translation ref. Precedence: explicit user
            // pick > language default from `LanguageDefaultBible`. Nil means
            // "use legacy bundled/API translation" — English users without an
            // explicit pick land here and read the legacy KJV path.
            if let stored = profile.preferredTranslationRefID, !stored.isEmpty {
                currentRefID = stored
            } else {
                // `effectiveLanguageCode` resolves "follow system" to the
                // device's preferred language, so a Spanish-phone user with
                // no explicit pick still defaults to Reina-Valera.
                let code = LocalizationService.shared.effectiveLanguageCode
                if let defaultID = LanguageDefaultBible.defaultRefID(for: code),
                   defaultID != LanguageDefaultBible.bundledEnglishID {
                    currentRefID = defaultID
                }
            }

            // Warm the localized-book-name cache for the active ref so the
            // book picker shows "Génesis"/"Salmos"/etc. immediately instead
            // of waiting for the user to open a chapter in each book.
            if let refID = currentRefID,
               !refID.hasPrefix(TranslationRef.bundledPrefix) {
                Task { await repository.prefetchBookNames(refID: refID) }
            }

            // Restore last read position
            if let book = BibleData.allBooks.first(where: { $0.id == profile.lastReadBookID }) {
                selectedBook = book
                selectedChapter = min(profile.lastReadChapter, book.chapterCount)
                lastReadVerseNumber = profile.lastReadVerseNumber
            }
        }
        repository.setTranslation(currentTranslation)
        loadChapter()
    }

    // MARK: - Navigation

    func selectBook(_ book: BibleBook) {
        logChapterReadIfQualified()
        selectedBook = book
        selectedChapter = 1
        lastReadVerseNumber = nil
        showBookPicker = false
        loadChapter()
    }

    func selectChapter(_ chapter: Int) {
        guard chapter >= 1, chapter <= selectedBook.chapterCount else { return }
        logChapterReadIfQualified()
        selectedChapter = chapter
        lastReadVerseNumber = nil
        showBookPicker = false
        loadChapter()
    }

    func goToNextChapter() {
        logChapterReadIfQualified()
        lastReadVerseNumber = nil
        if selectedChapter < selectedBook.chapterCount {
            selectedChapter += 1
        } else {
            if let idx = BibleData.allBooks.firstIndex(of: selectedBook),
               idx + 1 < BibleData.allBooks.count {
                selectedBook = BibleData.allBooks[idx + 1]
                selectedChapter = 1
            }
        }
        loadChapter()
    }

    func goToPreviousChapter() {
        logChapterReadIfQualified()
        lastReadVerseNumber = nil
        if selectedChapter > 1 {
            selectedChapter -= 1
        } else {
            if let idx = BibleData.allBooks.firstIndex(of: selectedBook), idx > 0 {
                selectedBook = BibleData.allBooks[idx - 1]
                selectedChapter = selectedBook.chapterCount
            }
        }
        loadChapter()
    }

    func selectVerse(_ verse: VerseItem) {
        selectedVerse = verse
        HapticService.lightImpact()
    }

    // MARK: - Profile Persistence Helper

    private func updateProfile(_ update: (UserProfile) -> Void) {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            update(profile)
            profile.updatedAt = Date()
            modelContext.safeSave()
        }
    }

    // MARK: - Translation

    func changeTranslation(_ translation: BibleTranslation) {
        currentTranslation = translation
        currentRefID = nil  // user explicitly picked a legacy enum; clear ref override
        repository.setTranslation(translation)
        updateProfile {
            $0.preferredTranslation = translation
            $0.preferredTranslationRefID = nil
        }
        showTranslationPicker = false
        loadChapter(logActivity: false)
    }

    /// Switch to a multilingual catalog translation (helloao-backed). Persists
    /// to `UserProfile.preferredTranslationRefID` so reopening the app keeps
    /// the pick. Pass `nil` to clear the override and revert to the legacy
    /// `BibleTranslation` enum.
    func changeTranslationRef(_ refID: String?) {
        currentRefID = refID
        updateProfile { $0.preferredTranslationRefID = refID }
        showTranslationPicker = false
        if let refID, !refID.hasPrefix(TranslationRef.bundledPrefix) {
            Task { await repository.prefetchBookNames(refID: refID) }
        }
        loadChapter(logActivity: false)
    }

    // MARK: - Loading

    func retryLoading() {
        errorMessage = nil
        loadChapter(logActivity: false)
    }

    // MARK: - Actions

    func copyVerse(_ verse: VerseItem) {
        let text = "\(verse.text)\n— \(selectedBook.name) \(selectedChapter):\(verse.number) (\(translationName))"
        UIPasteboard.general.string = text
        HapticService.success()
    }

    func verseReference(for verse: VerseItem) -> String {
        "\(selectedBook.name) \(selectedChapter):\(verse.number)"
    }

    func shareText(for verse: VerseItem) -> String {
        "\(verse.text)\n— \(selectedBook.name) \(selectedChapter):\(verse.number) (\(translationName))"
    }

    func explainVersePrompt(for verse: VerseItem) -> String {
        let ref = verseReference(for: verse)
        return "Help me understand what God is saying in \(ref): \"\(verse.text)\" — what did this mean in its original context, and what does it mean for my life today?"
    }

    // MARK: - Reader Settings Persistence

    func persistReaderSettings() {
        updateProfile {
            $0.readerFontSize = readerFontSize
            $0.readerFontStyle = readerFontStyle
            $0.readerFontWeight = readerFontWeight
            $0.readerLineSpacing = readerLineSpacing
            $0.textAlignmentJustified = readerTextAlignmentJustified
            $0.showVerseNumbers = readerShowVerseNumbers
        }
    }

    // MARK: - Read Position Persistence

    func persistReadPosition() {
        updateProfile {
            $0.lastReadBookID = selectedBook.id
            $0.lastReadChapter = selectedChapter
        }
    }

    func updateLastReadVerse(_ verseNumber: Int) {
        lastReadVerseNumber = verseNumber
        updateProfile {
            $0.lastReadBookID = selectedBook.id
            $0.lastReadChapter = selectedChapter
            $0.lastReadVerseNumber = verseNumber
        }
    }

    // MARK: - Chapter Read Logging

    /// Logs a `.chapterRead` event only if the user spent enough time on the chapter.
    /// Called when navigating away from the current chapter or when the view disappears.
    private func logChapterReadIfQualified() {
        guard let loadedAt = chapterLoadedAt,
              let detail = pendingChapterDetail else { return }

        let timeSpent = Date().timeIntervalSince(loadedAt)
        if timeSpent >= Self.chapterReadThreshold {
            ActivityService.log(.chapterRead, detail: detail, in: modelContext)
            Analytics.track(.bibleChapterRead, properties: ["chapter": detail])
        }

        // Reset so we don't double-log
        chapterLoadedAt = nil
        pendingChapterDetail = nil
    }

    /// Called by the view's `.onDisappear` to flush any pending chapter read.
    func onDisappear() {
        logChapterReadIfQualified()
    }

    // MARK: - Search Navigation

    func navigateToVerse(book: BibleBook, chapter: Int, verseNumber: Int) {
        logChapterReadIfQualified()
        selectedBook = book
        selectedChapter = chapter
        showSearch = false

        loadTask?.cancel()
        selectedVerse = nil
        verses = []
        isShowingOfflineFallback = false
        errorMessage = nil
        isLoading = true

        loadTask = Task {
            do {
                let fetched: [(number: Int, text: String)]
                if let refID = currentRefID, !refID.hasPrefix(TranslationRef.bundledPrefix) {
                    // Use the ID-only overload — works even if TranslationCatalog
                    // hasn't finished its background manifest fetch yet (common
                    // race on first launch in non-English).
                    fetched = try await repository.verses(
                        refID: refID,
                        book: selectedBook.id,
                        chapter: selectedChapter
                    )
                } else {
                    fetched = try await repository.verses(
                        book: selectedBook.id,
                        chapter: selectedChapter
                    )
                }
                guard !Task.isCancelled else { return }
                verses = fetched
                isLoading = false
                loadSavedVerses()

                // Scroll to and highlight the target verse (not selectedVerse which opens action sheet)
                if verseNumber > 0 {
                    lastReadVerseNumber = verseNumber
                }
            } catch {
                guard !Task.isCancelled else { return }
                let fallback = repository.versesSync(
                    book: selectedBook.id,
                    chapter: selectedChapter
                )
                if !fallback.isEmpty {
                    verses = fallback
                    isShowingOfflineFallback = currentTranslation != .kjv
                    isLoading = false
                    loadSavedVerses()
                } else {
                    verses = []
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Save & Highlight

    func isVerseSaved(_ number: Int) -> Bool {
        savedVerseMap[number] != nil
    }

    func highlightColor(for number: Int) -> VerseHighlightColor? {
        savedVerseMap[number]?.highlightColor
    }

    func saveVerse(_ verse: VerseItem) {
        guard savedVerseMap[verse.number] == nil else { return }
        let saved = SavedBibleVerse(
            bookID: selectedBook.id,
            bookName: selectedBook.name,
            chapter: selectedChapter,
            verseNumber: verse.number,
            text: verse.text,
            translation: currentTranslation.abbreviation
        )
        modelContext.insert(saved)
        modelContext.safeSave()
        savedVerseMap[verse.number] = saved
        ActivityService.log(.verseSaved, detail: "\(selectedBook.name) \(selectedChapter):\(verse.number)", in: modelContext)
        HapticService.success()
    }

    func unsaveVerse(_ verse: VerseItem) {
        guard let saved = savedVerseMap[verse.number] else { return }
        modelContext.delete(saved)
        modelContext.safeSave()
        savedVerseMap.removeValue(forKey: verse.number)
        HapticService.lightImpact()
    }

    func highlightVerse(_ verse: VerseItem, color: VerseHighlightColor) {
        if let saved = savedVerseMap[verse.number] {
            saved.highlightColor = color
            saved.updatedAt = Date()
        } else {
            let saved = SavedBibleVerse(
                bookID: selectedBook.id,
                bookName: selectedBook.name,
                chapter: selectedChapter,
                verseNumber: verse.number,
                text: verse.text,
                translation: currentTranslation.abbreviation,
                highlightColor: color
            )
            modelContext.insert(saved)
            savedVerseMap[verse.number] = saved
        }
        modelContext.safeSave()
        ActivityService.log(.verseHighlighted, detail: "\(selectedBook.name) \(selectedChapter):\(verse.number)", in: modelContext)
        HapticService.lightImpact()
    }

    func removeHighlight(_ verse: VerseItem) {
        guard let saved = savedVerseMap[verse.number] else { return }
        saved.highlightColor = nil
        saved.updatedAt = Date()
        modelContext.safeSave()
    }

    func noteText(for number: Int) -> String? {
        guard let saved = savedVerseMap[number], !saved.notes.isEmpty else { return nil }
        return saved.notes
    }

    func saveNote(for verse: VerseItem, note: String) {
        if let saved = savedVerseMap[verse.number] {
            saved.notes = note
            saved.updatedAt = Date()
        } else {
            let saved = SavedBibleVerse(
                bookID: selectedBook.id,
                bookName: selectedBook.name,
                chapter: selectedChapter,
                verseNumber: verse.number,
                text: verse.text,
                translation: currentTranslation.abbreviation,
                notes: note
            )
            modelContext.insert(saved)
            savedVerseMap[verse.number] = saved
        }
        modelContext.safeSave()
        HapticService.success()
    }

    private func loadSavedVerses() {
        let bookID = selectedBook.id
        let chapter = selectedChapter
        let descriptor = FetchDescriptor<SavedBibleVerse>(
            predicate: #Predicate { $0.bookID == bookID && $0.chapter == chapter }
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        var map: [Int: SavedBibleVerse] = [:]
        for saved in results {
            map[saved.verseNumber] = saved
        }
        savedVerseMap = map
    }

    // MARK: - Private

    private func loadChapter(logActivity: Bool = true) {
        loadTask?.cancel()
        selectedVerse = nil
        verses = []
        isShowingOfflineFallback = false
        errorMessage = nil
        isLoading = true

        loadTask = Task {
            do {
                let fetched: [(number: Int, text: String)]
                // Route through helloao when the user has picked (or defaulted
                // to) a multilingual translation. Bundled prefixes collapse
                // back to the legacy path inside BibleRepository.
                if let refID = currentRefID, !refID.hasPrefix(TranslationRef.bundledPrefix) {
                    fetched = try await repository.verses(
                        refID: refID,
                        book: selectedBook.id,
                        chapter: selectedChapter
                    )
                } else {
                    fetched = try await repository.verses(
                        book: selectedBook.id,
                        chapter: selectedChapter
                    )
                }
                guard !Task.isCancelled else { return }
                verses = fetched
                isLoading = false
                loadSavedVerses()
                persistReadPosition()
                if logActivity {
                    chapterLoadedAt = Date()
                    pendingChapterDetail = "\(selectedBook.name) \(selectedChapter)"
                }
            } catch {
                guard !Task.isCancelled else { return }

                // Graceful fallback: try sync path (cached or bundled KJV)
                let fallback = repository.versesSync(
                    book: selectedBook.id,
                    chapter: selectedChapter
                )

                if !fallback.isEmpty {
                    verses = fallback
                    isShowingOfflineFallback = currentTranslation != .kjv
                    isLoading = false
                    loadSavedVerses()
                    persistReadPosition()
                    if logActivity {
                        chapterLoadedAt = Date()
                        pendingChapterDetail = "\(selectedBook.name) \(selectedChapter)"
                    }
                } else {
                    verses = []
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - VerseItem

struct VerseItem: Identifiable, Equatable {
    let number: Int
    let text: String
    var id: Int { number }
}
