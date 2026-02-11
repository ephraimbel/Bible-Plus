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
    var selectedVerse: VerseItem? = nil

    // MARK: - Data

    var verses: [(number: Int, text: String)] = []

    private let repository = BibleRepository.shared
    private let modelContext: ModelContext

    var translationName: String { repository.currentTranslation }

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
        loadChapter()
    }

    // MARK: - Navigation

    func selectBook(_ book: BibleBook) {
        selectedBook = book
        selectedChapter = 1
        showBookPicker = false
        loadChapter()
    }

    func selectChapter(_ chapter: Int) {
        selectedChapter = chapter
        showBookPicker = false
        loadChapter()
    }

    func goToNextChapter() {
        if selectedChapter < selectedBook.chapterCount {
            selectedChapter += 1
        } else {
            // Move to next book
            if let idx = BibleData.allBooks.firstIndex(of: selectedBook),
               idx + 1 < BibleData.allBooks.count {
                selectedBook = BibleData.allBooks[idx + 1]
                selectedChapter = 1
            }
        }
        loadChapter()
    }

    func goToPreviousChapter() {
        if selectedChapter > 1 {
            selectedChapter -= 1
        } else {
            // Move to previous book
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
        return "Explain this verse to me: \"\(verse.text)\" — \(ref)"
    }

    // MARK: - Private

    private func loadChapter() {
        verses = repository.verses(book: selectedBook.id, chapter: selectedChapter)
    }
}

// MARK: - VerseItem

struct VerseItem: Identifiable, Equatable {
    let number: Int
    let text: String
    var id: Int { number }
}
