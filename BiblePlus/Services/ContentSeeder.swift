import Foundation
import SwiftData

enum ContentSeeder {
    private static let seedVersionKey = "com.bibleplus.lastSeedVersion"

    /// Seed the database with bundled content, supporting incremental updates.
    static func seedIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: seedVersionKey)

        guard let url = Bundle.main.url(forResource: "feed-content", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return
        }

        let decoder = JSONDecoder()
        guard let items = try? decoder.decode([SeedContentItem].self, from: data) else {
            return
        }

        let newItems = items.filter { $0.seedVersion > lastVersion }
        guard !newItems.isEmpty else { return }

        var maxVersion = lastVersion
        for item in newItems {
            let content = PrayerContent(
                type: item.type,
                templateText: item.templateText,
                verseReference: item.verseReference,
                verseText: item.verseText,
                category: item.category,
                timeOfDay: item.timeOfDay,
                applicableSeasons: item.applicableSeasons,
                applicableBurdens: item.applicableBurdens,
                faithLevelMin: item.faithLevelMin,
                isProOnly: item.isProOnly,
                seedVersion: item.seedVersion
            )
            modelContext.insert(content)
            maxVersion = max(maxVersion, item.seedVersion)
        }

        try? modelContext.save()
        UserDefaults.standard.set(maxVersion, forKey: seedVersionKey)
    }

    /// Migrate orphaned chat messages from pre-threading era into a legacy conversation.
    static func migrateOrphanedMessages(modelContext: ModelContext) {
        let legacyId = ChatMessage.legacyConversationId

        // Check if legacy conversation already exists
        let convDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == legacyId }
        )
        guard (try? modelContext.fetch(convDescriptor))?.isEmpty == true else { return }

        // Check if there are any orphaned messages with the sentinel ID
        let msgDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.conversationId == legacyId }
        )
        guard let orphans = try? modelContext.fetch(msgDescriptor), !orphans.isEmpty else { return }

        let conversation = Conversation(
            id: legacyId,
            title: "Previous Conversation",
            createdAt: orphans.first?.createdAt ?? Date(),
            updatedAt: orphans.last?.createdAt ?? Date()
        )
        modelContext.insert(conversation)
        try? modelContext.save()
    }
}

// MARK: - Seed JSON Structure

struct SeedContentItem: Decodable {
    let type: ContentType
    let templateText: String
    let verseReference: String?
    let verseText: String?
    let category: String
    let timeOfDay: [PrayerTimeSlot]
    let applicableSeasons: [LifeSeason]
    let applicableBurdens: [Burden]
    let faithLevelMin: FaithLevel
    let isProOnly: Bool
    let seedVersion: Int
}
