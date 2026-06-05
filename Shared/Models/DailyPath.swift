import Foundation
import SwiftData

@Model
final class DailyPath {
    @Attribute(.unique) var id: String = ""
    var name: String = ""
    var pathDescription: String = ""
    var totalDays: Int = 14
    var category: String = ""
    var gradientColors: [String] = []
    var iconName: String = ""
    var imageKey: String = ""
    var daysJSON: Data = Data()
    var applicableSeasons: [String] = []
    var applicableBurdens: [String] = []
    var faithLevelMin: String = "justCurious"
    var isProOnly: Bool = false

    /// When set, days 1...freeDaysAllowed are accessible to free users; the
    /// paywall fires when a free user opens day `freeDaysAllowed + 1`. When
    /// nil, the entire path is governed by `isProOnly` alone.
    var freeDaysAllowed: Int? = nil

    /// Optional themed grouping of days (e.g. "Naming the anxiety" → days
    /// 1-3). Encoded as JSON so it can evolve without a schema migration.
    /// When empty, the detail view renders as a flat day list.
    var chaptersJSON: Data = Data()

    var seedVersion: Int = 1

    init(
        id: String,
        name: String,
        pathDescription: String,
        totalDays: Int,
        category: String,
        gradientColors: [String],
        iconName: String,
        imageKey: String,
        days: [PathDay],
        chapters: [PathChapter],
        applicableSeasons: [String],
        applicableBurdens: [String],
        faithLevelMin: String,
        isProOnly: Bool,
        freeDaysAllowed: Int?,
        seedVersion: Int
    ) {
        self.id = id
        self.name = name
        self.pathDescription = pathDescription
        self.totalDays = totalDays
        self.category = category
        self.gradientColors = gradientColors
        self.iconName = iconName
        self.imageKey = imageKey
        self.daysJSON = (try? JSONEncoder().encode(days)) ?? Data()
        self.chaptersJSON = (try? JSONEncoder().encode(chapters)) ?? Data()
        self.applicableSeasons = applicableSeasons
        self.applicableBurdens = applicableBurdens
        self.faithLevelMin = faithLevelMin
        self.isProOnly = isProOnly
        self.freeDaysAllowed = freeDaysAllowed
        self.seedVersion = seedVersion
    }

    var days: [PathDay] {
        do {
            return try JSONDecoder().decode([PathDay].self, from: daysJSON)
        } catch {
            print("[DailyPath] Failed to decode days for path \(id): \(error)")
            return []
        }
    }

    var chapters: [PathChapter] {
        guard !chaptersJSON.isEmpty else { return [] }
        return (try? JSONDecoder().decode([PathChapter].self, from: chaptersJSON)) ?? []
    }

    func chapter(for day: Int) -> PathChapter? {
        chapters.first { $0.contains(day) }
    }

    func day(_ dayNumber: Int) -> PathDay? {
        days.first { $0.day == dayNumber }
    }

    /// True when the given day requires Pro entitlement.
    func dayRequiresPro(_ dayNumber: Int) -> Bool {
        if isProOnly { return true }
        guard let cap = freeDaysAllowed else { return false }
        return dayNumber > cap
    }
}
