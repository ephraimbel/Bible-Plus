import Foundation
import SwiftData

@Model
final class SavedBibleVerse {
    var id: UUID = UUID()
    var bookID: String = ""
    var bookName: String = ""
    var chapter: Int = 1
    var verseNumber: Int = 1
    var text: String = ""
    var translation: String = "KJV"
    var highlightColorRaw: String? = nil
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var highlightColor: VerseHighlightColor? {
        get {
            guard let raw = highlightColorRaw else { return nil }
            return VerseHighlightColor(rawValue: raw)
        }
        set {
            highlightColorRaw = newValue?.rawValue
        }
    }

    init(
        bookID: String,
        bookName: String,
        chapter: Int,
        verseNumber: Int,
        text: String,
        translation: String,
        highlightColor: VerseHighlightColor? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.bookID = bookID
        self.bookName = bookName
        self.chapter = chapter
        self.verseNumber = verseNumber
        self.text = text
        self.translation = translation
        self.highlightColorRaw = highlightColor?.rawValue
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
