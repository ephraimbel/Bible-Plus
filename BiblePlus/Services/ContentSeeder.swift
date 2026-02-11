import Foundation
import SwiftData

enum ContentSeeder {
    /// Seed the database with bundled content if it's empty.
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PrayerContent>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        guard let url = Bundle.main.url(forResource: "feed-content", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return
        }

        let decoder = JSONDecoder()
        guard let items = try? decoder.decode([SeedContentItem].self, from: data) else {
            return
        }

        for item in items {
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
                isProOnly: item.isProOnly
            )
            modelContext.insert(content)
        }

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
}
