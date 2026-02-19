import Foundation
import SwiftData

enum SavedTab: String, CaseIterable {
    case favorites
    case verses
    case notes
}

// MARK: - Saved Item Wrapper

enum SavedItem: Identifiable {
    case content(PrayerContent)
    case prayer(PrayerEntry)

    var id: UUID {
        switch self {
        case .content(let c): c.id
        case .prayer(let p): p.id
        }
    }

    var date: Date {
        switch self {
        case .content(let c): c.createdAt
        case .prayer(let p): p.createdAt
        }
    }
}

@MainActor
@Observable
final class SavedViewModel {
    var selectedTab: SavedTab = .favorites

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

    // MARK: - Prayer Entries

    var prayerEntries: [PrayerEntry] {
        let descriptor = FetchDescriptor<PrayerEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Merged favorites + prayer entries, sorted by date descending
    var savedItems: [SavedItem] {
        let contentItems: [SavedItem] = favorites.map { .content($0) }
        let prayerItems: [SavedItem] = prayerEntries.map { .prayer($0) }
        return (contentItems + prayerItems).sorted { $0.date > $1.date }
    }

    func deletePrayerEntry(_ entry: PrayerEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    func toggleAnswered(_ entry: PrayerEntry) {
        entry.isAnswered.toggle()
        entry.answeredAt = entry.isAnswered ? Date() : nil
        entry.updatedAt = Date()
        try? modelContext.save()
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

    // MARK: - Notes (verses with annotations)

    var notedVerses: [SavedBibleVerse] {
        let descriptor = FetchDescriptor<SavedBibleVerse>(
            predicate: #Predicate { $0.notes != "" },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func clearNote(_ verse: SavedBibleVerse) {
        verse.notes = ""
        verse.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Collections (used by CollectionPickerSheet)

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
        return ids.compactMap { id in allContent.first { $0.id == id } }
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
