import Foundation
import SwiftData

enum ContentSeeder {
    private static let seedVersionKey = "io.bibleplus.lastSeedVersion"

    /// Seed the database with bundled content, supporting incremental updates.
    static func seedIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: seedVersionKey)

        // Self-healing: if the store has zero PrayerContent (e.g. a prior
        // seed silently failed and the version flag was never written, or a
        // schema migration wiped the table), force a full reseed regardless
        // of the lastVersion gate.
        let existingCount: Int = {
            let descriptor = FetchDescriptor<PrayerContent>()
            return (try? modelContext.fetchCount(descriptor)) ?? 0
        }()
        let forceReseed = existingCount == 0

        guard let url = LocalizedContentLoader.url(forResource: "feed-content") else {
            NSLog("[ContentSeeder] feed-content.json missing from bundle")
            return
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            NSLog("[ContentSeeder] read failed: \(error)")
            return
        }

        let decoder = JSONDecoder()
        let items: [SeedContentItem]
        do {
            items = try decoder.decode([SeedContentItem].self, from: data)
        } catch {
            NSLog("[ContentSeeder] decode failed: \(error)")
            return
        }

        let newItems = forceReseed
            ? items
            : items.filter { $0.seedVersion > lastVersion }
        guard !newItems.isEmpty else {
            NSLog("[ContentSeeder] no new items (lastVersion=\(lastVersion))")
            return
        }

        var maxVersion = lastVersion
        for item in newItems {
            let content = PrayerContent(
                type: item.type,
                templateText: item.templateText ?? item.verseText ?? "",
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

        do {
            try modelContext.save()
            UserDefaults.standard.set(maxVersion, forKey: seedVersionKey)
            NSLog("[ContentSeeder] seeded \(newItems.count) items, version=\(maxVersion)")
        } catch {
            NSLog("[ContentSeeder] save failed: \(error)")
        }
    }

    // MARK: - Reading Plans Seeder

    private static let plansSeedVersionKey = "io.bibleplus.lastPlansSeedVersion"

    static func seedPlansIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: plansSeedVersionKey)

        // Self-healing: if the SwiftData store has zero ReadingPlan rows
        // (e.g. a schema migration wiped the table while UserDefaults still
        // remembers the previous seed version) force a full reseed so the
        // Reading Plans screen never renders blank.
        let existingCount: Int = {
            let descriptor = FetchDescriptor<ReadingPlan>()
            return (try? modelContext.fetchCount(descriptor)) ?? 0
        }()
        let forceReseed = existingCount == 0

        guard let url = LocalizedContentLoader.url(forResource: "reading-plans"),
              let data = try? Data(contentsOf: url)
        else { return }

        let decoder = JSONDecoder()
        guard let items = try? decoder.decode([SeedPlanItem].self, from: data) else { return }

        let newItems = forceReseed
            ? items
            : items.filter { $0.seedVersion > lastVersion }
        guard !newItems.isEmpty else { return }

        var maxVersion = lastVersion
        for item in newItems {
            // Upsert: when a plan with this ID already exists (seedVersion bump
            // scenario) update it in place; otherwise insert a fresh row.
            // UserPlanProgress is keyed by planID (string) so it survives edits.
            let itemID = item.id
            let existingDescriptor = FetchDescriptor<ReadingPlan>(
                predicate: #Predicate { $0.id == itemID }
            )
            if let existing = try? modelContext.fetch(existingDescriptor).first {
                existing.name = item.name
                existing.planDescription = item.description
                existing.totalDays = item.totalDays
                existing.category = item.category
                existing.gradientColors = item.gradientColors
                existing.iconName = item.iconName
                existing.imageKey = item.imageKey ?? ""
                existing.daysJSON = (try? JSONEncoder().encode(item.days)) ?? Data()
                existing.applicableSeasons = item.applicableSeasons
                existing.applicableBurdens = item.applicableBurdens
                existing.faithLevelMin = item.faithLevelMin
                existing.isProOnly = item.isProOnly
                existing.seedVersion = item.seedVersion
            } else {
                let plan = ReadingPlan(
                    id: item.id,
                    name: item.name,
                    planDescription: item.description,
                    totalDays: item.totalDays,
                    category: item.category,
                    gradientColors: item.gradientColors,
                    iconName: item.iconName,
                    imageKey: item.imageKey ?? "",
                    days: item.days,
                    applicableSeasons: item.applicableSeasons,
                    applicableBurdens: item.applicableBurdens,
                    faithLevelMin: item.faithLevelMin,
                    isProOnly: item.isProOnly,
                    seedVersion: item.seedVersion
                )
                modelContext.insert(plan)
            }
            maxVersion = max(maxVersion, item.seedVersion)
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(maxVersion, forKey: plansSeedVersionKey)
            NSLog("[ContentSeeder] seeded \(newItems.count) plans, version=\(maxVersion)")
        } catch {
            NSLog("[ContentSeeder] plan save failed: \(error)")
        }
    }

    // MARK: - Daily Paths Seeder

    private static let pathsSeedVersionKey = "io.bibleplus.lastPathsSeedVersion"

    static func seedDailyPathsIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: pathsSeedVersionKey)

        let existingCount: Int = {
            let descriptor = FetchDescriptor<DailyPath>()
            return (try? modelContext.fetchCount(descriptor)) ?? 0
        }()
        let forceReseed = existingCount == 0

        guard let url = LocalizedContentLoader.url(forResource: "daily-paths"),
              let data = try? Data(contentsOf: url)
        else { return }

        let decoder = JSONDecoder()
        guard let items = try? decoder.decode([SeedPathItem].self, from: data) else {
            NSLog("[ContentSeeder] daily-paths decode failed")
            return
        }

        let newItems = forceReseed
            ? items
            : items.filter { $0.seedVersion > lastVersion }
        guard !newItems.isEmpty else { return }

        var maxVersion = lastVersion
        for item in newItems {
            let itemID = item.id
            let existingDescriptor = FetchDescriptor<DailyPath>(
                predicate: #Predicate { $0.id == itemID }
            )
            let chapters = item.chapters ?? []
            if let existing = try? modelContext.fetch(existingDescriptor).first {
                existing.name = item.name
                existing.pathDescription = item.description
                existing.totalDays = item.totalDays
                existing.category = item.category
                existing.gradientColors = item.gradientColors
                existing.iconName = item.iconName
                existing.imageKey = item.imageKey ?? ""
                existing.daysJSON = (try? JSONEncoder().encode(item.days)) ?? Data()
                existing.chaptersJSON = (try? JSONEncoder().encode(chapters)) ?? Data()
                existing.applicableSeasons = item.applicableSeasons
                existing.applicableBurdens = item.applicableBurdens
                existing.faithLevelMin = item.faithLevelMin
                existing.isProOnly = item.isProOnly
                existing.freeDaysAllowed = item.freeDaysAllowed
                existing.seedVersion = item.seedVersion
            } else {
                let path = DailyPath(
                    id: item.id,
                    name: item.name,
                    pathDescription: item.description,
                    totalDays: item.totalDays,
                    category: item.category,
                    gradientColors: item.gradientColors,
                    iconName: item.iconName,
                    imageKey: item.imageKey ?? "",
                    days: item.days,
                    chapters: chapters,
                    applicableSeasons: item.applicableSeasons,
                    applicableBurdens: item.applicableBurdens,
                    faithLevelMin: item.faithLevelMin,
                    isProOnly: item.isProOnly,
                    freeDaysAllowed: item.freeDaysAllowed,
                    seedVersion: item.seedVersion
                )
                modelContext.insert(path)
            }
            maxVersion = max(maxVersion, item.seedVersion)
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(maxVersion, forKey: pathsSeedVersionKey)
            NSLog("[ContentSeeder] seeded \(newItems.count) daily paths, version=\(maxVersion)")
        } catch {
            NSLog("[ContentSeeder] daily path save failed: \(error)")
        }
    }

    private static let migrationCompleteKey = "io.bibleplus.migrationComplete"

    /// Migrate orphaned chat messages from pre-threading era into a legacy conversation.
    static func migrateOrphanedMessages(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationCompleteKey) else { return }

        let legacyId = ChatMessage.legacyConversationId

        // Check if legacy conversation already exists
        let convDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == legacyId }
        )
        let legacyExists = !((try? modelContext.fetch(convDescriptor))?.isEmpty ?? true)

        // Find messages with nil conversationId (from schema migration) and assign legacy ID
        let nilDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.conversationId == nil }
        )
        if let nilMessages = try? modelContext.fetch(nilDescriptor), !nilMessages.isEmpty {
            for msg in nilMessages {
                msg.conversationId = legacyId
            }
            modelContext.safeSave()
        }

        guard !legacyExists else { return }

        // Check if there are any orphaned messages with the sentinel ID
        let msgDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.conversationId == legacyId }
        )
        guard let orphans = try? modelContext.fetch(msgDescriptor), !orphans.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationCompleteKey)
            return
        }

        let conversation = Conversation(
            id: legacyId,
            title: "Previous Conversation",
            createdAt: orphans.first?.createdAt ?? Date(),
            updatedAt: orphans.last?.createdAt ?? Date()
        )
        modelContext.insert(conversation)
        modelContext.safeSave()
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)
    }
}

// MARK: - Seed JSON Structure

struct SeedContentItem: Decodable {
    let type: ContentType
    // Verse-type entries in feed-content.json carry no template (the verseText
    // itself is the body), so this field can legitimately be null in the JSON.
    // Keep it optional here and fall back to "" or verseText when constructing
    // the SwiftData record.
    let templateText: String?
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

struct SeedPlanItem: Decodable {
    let id: String
    let name: String
    let description: String
    let totalDays: Int
    let category: String
    let gradientColors: [String]
    let iconName: String
    let imageKey: String?
    let days: [PlanDay]
    let applicableSeasons: [String]
    let applicableBurdens: [String]
    let faithLevelMin: String
    let isProOnly: Bool
    let seedVersion: Int
}

struct SeedPathItem: Decodable {
    let id: String
    let name: String
    let description: String
    let totalDays: Int
    let category: String
    let gradientColors: [String]
    let iconName: String
    let imageKey: String?
    let days: [PathDay]
    let chapters: [PathChapter]?
    let applicableSeasons: [String]
    let applicableBurdens: [String]
    let faithLevelMin: String
    let isProOnly: Bool
    let freeDaysAllowed: Int?
    let seedVersion: Int
}
