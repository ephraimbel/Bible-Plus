import Foundation
import SwiftData

enum SavedTab: String, CaseIterable {
    case favorites
    case collections
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
