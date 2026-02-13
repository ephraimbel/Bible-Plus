import Foundation
import SwiftData

enum SavedTab: String, CaseIterable {
    case favorites
    case verses
    case collections
    case journal
}

@MainActor
@Observable
final class SavedViewModel {
    var selectedTab: SavedTab = .favorites

    // Journal filter state
    var journalFilter: JournalFilter = .all
    var journalCategoryFilter: PrayerCategory? = nil

    private let modelContext: ModelContext
    private let personalizationService: PersonalizationService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.personalizationService = PersonalizationService(modelContext: modelContext)
    }

    var userName: String {
        let name = personalizationService.getOrCreateProfile().firstName
        return name.isEmpty ? "Friend" : name
    }

    func personalizedText(for content: PrayerContent) -> String {
        content.templateText.replacingOccurrences(of: "{name}", with: userName)
    }

    // MARK: - Favorites

    var favorites: [PrayerContent] {
        let descriptor = FetchDescriptor<PrayerContent>(
            predicate: #Predicate { $0.isSaved == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Saved Verses

    var savedVerses: [SavedBibleVerse] {
        let descriptor = FetchDescriptor<SavedBibleVerse>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func deleteSavedVerse(_ verse: SavedBibleVerse) {
        modelContext.delete(verse)
        try? modelContext.save()
    }

    // MARK: - Collections

    var collections: [ContentCollection] {
        let descriptor = FetchDescriptor<ContentCollection>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func contentsForCollection(_ collection: ContentCollection) -> [PrayerContent] {
        guard !collection.contentIDs.isEmpty else { return [] }
        let ids = collection.contentIDs
        let descriptor = FetchDescriptor<PrayerContent>()
        guard let allContent = try? modelContext.fetch(descriptor) else { return [] }
        // Preserve collection ordering
        return ids.compactMap { id in allContent.first { $0.id == id } }
    }

    // MARK: - Journal

    private var journalVersion: Int = 0

    enum JournalFilter: String, CaseIterable {
        case all
        case unanswered
        case answered

        var displayName: String {
            switch self {
            case .all: "All"
            case .unanswered: "Unanswered"
            case .answered: "Answered"
            }
        }
    }

    var journalEntries: [PrayerEntry] {
        let _ = journalVersion
        let descriptor = FetchDescriptor<PrayerEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let all = try? modelContext.fetch(descriptor) else { return [] }

        var filtered = all

        switch journalFilter {
        case .all: break
        case .unanswered: filtered = filtered.filter { !$0.isAnswered }
        case .answered: filtered = filtered.filter { $0.isAnswered }
        }

        if let cat = journalCategoryFilter {
            filtered = filtered.filter { $0.category == cat }
        }

        return filtered
    }

    func createPrayerEntry(title: String, body: String, category: PrayerCategory, verseReference: String?) {
        let entry = PrayerEntry(title: title, body: body, category: category, verseReference: verseReference)
        modelContext.insert(entry)
        try? modelContext.save()
        journalVersion += 1
        ActivityService.log(.prayerWritten, detail: String(title.prefix(50)), in: modelContext)
    }

    func updatePrayerEntry(_ entry: PrayerEntry, title: String, body: String, category: PrayerCategory, verseReference: String?) {
        entry.title = title
        entry.body = body
        entry.category = category
        entry.verseReference = verseReference
        entry.updatedAt = Date()
        try? modelContext.save()
        journalVersion += 1
    }

    func deletePrayerEntry(_ entry: PrayerEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        journalVersion += 1
    }

    func markPrayerAsAnswered(_ entry: PrayerEntry, notes: String) {
        entry.isAnswered = true
        entry.answerNotes = notes
        entry.answeredAt = Date()
        entry.updatedAt = Date()
        try? modelContext.save()
        journalVersion += 1
        ActivityService.log(.prayerAnswered, detail: String(entry.title.prefix(50)), in: modelContext)
    }

    func unmarkPrayerAsAnswered(_ entry: PrayerEntry) {
        entry.isAnswered = false
        entry.answerNotes = ""
        entry.answeredAt = nil
        entry.updatedAt = Date()
        try? modelContext.save()
        journalVersion += 1
    }

    // MARK: - Actions

    func unsave(_ content: PrayerContent) {
        content.isSaved = false
        try? modelContext.save()
    }

    func deleteCollection(_ collection: ContentCollection) {
        modelContext.delete(collection)
        try? modelContext.save()
    }

    func removeFromCollection(_ content: PrayerContent, collection: ContentCollection) {
        collection.contentIDs.removeAll { $0 == content.id }
        collection.updatedAt = Date()
        try? modelContext.save()
    }

}
