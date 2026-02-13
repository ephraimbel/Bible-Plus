import Foundation
import SwiftData

@Model
final class PrayerEntry {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var categoryRaw: String = ""
    var isAnswered: Bool = false
    var answerNotes: String = ""
    var answeredAt: Date?
    var verseReference: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var category: PrayerCategory {
        get { PrayerCategory(rawValue: categoryRaw) ?? .petition }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        title: String,
        body: String,
        category: PrayerCategory,
        verseReference: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.categoryRaw = category.rawValue
        self.isAnswered = false
        self.answerNotes = ""
        self.answeredAt = nil
        self.verseReference = verseReference
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
