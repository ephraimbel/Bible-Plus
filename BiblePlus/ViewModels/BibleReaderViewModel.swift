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

    // MARK: - Reader Settings

    var readerFontSize: Double = 20
    var readerFontStyle: ReaderFontStyle = .serif
    var readerLineSpacing: Double = 6

    // MARK: - Last Read Position

    var lastReadVerseNumber: Int? = nil

    var readerFontDesign: Font.Design {
        readerFontStyle == .serif ? .serif : .rounded
    }

    private let repository = BibleRepository.shared
    private let modelContext: ModelContext
    private var loadTask: Task<Void, Never>?

    var translationName: String { currentTranslation.displayName }

    var hasContent: Bool { !verses.isEmpty }

    var chapterTitle: String {
        "\(selectedBook.name) \(selectedChapter)"
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
            readerLineSpacing = profile.readerLineSpacing

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

        selectedBook = book
        selectedChapter = 1
        lastReadVerseNumber = nil
        showBookPicker = false
        loadChapter()
    }

    func selectChapter(_ chapter: Int) {
        guard chapter >= 1, chapter <= selectedBook.chapterCount else { return }
        selectedChapter = chapter
        lastReadVerseNumber = nil
        showBookPicker = false
        loadChapter()
    }

    func goToNextChapter() {

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
            try? modelContext.save()
        }
    }

    // MARK: - Translation

    func changeTranslation(_ translation: BibleTranslation) {
        currentTranslation = translation
        repository.setTranslation(translation)
        updateProfile { $0.preferredTranslation = translation }
        showTranslationPicker = false
        loadChapter()
    }

    // MARK: - Loading

    func retryLoading() {
        errorMessage = nil
        loadChapter()
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
            $0.readerLineSpacing = readerLineSpacing
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

    // MARK: - Search Navigation

    func navigateToVerse(book: BibleBook, chapter: Int, verseNumber: Int) {

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
                let fetched = try await repository.verses(
                    book: selectedBook.id,
                    chapter: selectedChapter
                )
                guard !Task.isCancelled else { return }
                verses = fetched
                isLoading = false
                loadSavedVerses()

                // Auto-select the target verse
                if let verseText = fetched.first(where: { $0.number == verseNumber }) {
                    selectedVerse = VerseItem(number: verseText.number, text: verseText.text)
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
            translation: currentTranslation.displayName
        )
        modelContext.insert(saved)
        try? modelContext.save()
        savedVerseMap[verse.number] = saved
        HapticService.success()
    }

    func unsaveVerse(_ verse: VerseItem) {
        guard let saved = savedVerseMap[verse.number] else { return }
        modelContext.delete(saved)
        try? modelContext.save()
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
                translation: currentTranslation.displayName,
                highlightColor: color
            )
            modelContext.insert(saved)
            savedVerseMap[verse.number] = saved
        }
        try? modelContext.save()
        HapticService.lightImpact()
    }

    func removeHighlight(_ verse: VerseItem) {
        guard let saved = savedVerseMap[verse.number] else { return }
        saved.highlightColor = nil
        saved.updatedAt = Date()
        try? modelContext.save()
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

    private func loadChapter() {
        loadTask?.cancel()
        selectedVerse = nil
        verses = []
        isShowingOfflineFallback = false
        errorMessage = nil
        isLoading = true

        loadTask = Task {
            do {
                let fetched = try await repository.verses(
                    book: selectedBook.id,
                    chapter: selectedChapter
                )
                guard !Task.isCancelled else { return }
                verses = fetched
                isLoading = false
                loadSavedVerses()
                persistReadPosition()
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
