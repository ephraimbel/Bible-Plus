import Foundation
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
    var selectedVerse: VerseItem? = nil

    // MARK: - Page Flip Direction

    enum NavigationDirection {
        case forward, backward
    }

    var navigationDirection: NavigationDirection = .forward

    // MARK: - Loading State

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var isShowingOfflineFallback: Bool = false

    // MARK: - Data

    var verses: [(number: Int, text: String)] = []
    var currentTranslation: BibleTranslation = .kjv

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

        // Read user's preferred translation
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            currentTranslation = profile.preferredTranslation
        }
        repository.setTranslation(currentTranslation)
        loadChapter()
    }

    // MARK: - Navigation

    func selectBook(_ book: BibleBook) {
        navigationDirection = .forward
        selectedBook = book
        selectedChapter = 1
        showBookPicker = false
        loadChapter()
    }

    func selectChapter(_ chapter: Int) {
        navigationDirection = chapter > selectedChapter ? .forward : .backward
        selectedChapter = chapter
        showBookPicker = false
        loadChapter()
    }

    func goToNextChapter() {
        navigationDirection = .forward
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
        navigationDirection = .backward
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

    // MARK: - Translation

    func changeTranslation(_ translation: BibleTranslation) {
        currentTranslation = translation
        repository.setTranslation(translation)

        // Persist to UserProfile
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            profile.preferredTranslation = translation
            profile.updatedAt = Date()
            try? modelContext.save()
        }

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
