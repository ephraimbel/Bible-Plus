import Foundation
import SwiftData

@Model
final class ReadingPlan {
    @Attribute(.unique) var id: String = ""
    var name: String = ""
    var planDescription: String = ""
    var totalDays: Int = 7
    var category: String = ""
    var gradientColors: [String] = []
    var iconName: String = ""
    var imageKey: String = ""
    var daysJSON: Data = Data()
    var applicableSeasons: [String] = []
    var applicableBurdens: [String] = []
    var faithLevelMin: String = "justCurious"
    var isProOnly: Bool = false
    var seedVersion: Int = 1

    init(
        id: String,
        name: String,
        planDescription: String,
        totalDays: Int,
        category: String,
        gradientColors: [String],
        iconName: String,
        imageKey: String,
        days: [PlanDay],
        applicableSeasons: [String],
        applicableBurdens: [String],
        faithLevelMin: String,
        isProOnly: Bool,
        seedVersion: Int
    ) {
        self.id = id
        self.name = name
        self.planDescription = planDescription
        self.totalDays = totalDays
        self.category = category
        self.gradientColors = gradientColors
        self.iconName = iconName
        self.imageKey = imageKey
        self.daysJSON = (try? JSONEncoder().encode(days)) ?? Data()
        self.applicableSeasons = applicableSeasons
        self.applicableBurdens = applicableBurdens
        self.faithLevelMin = faithLevelMin
        self.isProOnly = isProOnly
        self.seedVersion = seedVersion
    }

    var days: [PlanDay] {
        do {
            return try JSONDecoder().decode([PlanDay].self, from: daysJSON)
        } catch {
            print("[ReadingPlan] Failed to decode days for plan \(id): \(error)")
            return []
        }
    }
}

// MARK: - Plan Day Structure

struct PlanDay: Codable, Identifiable {
    let day: Int
    let title: String
    let readings: [PlanReading]
    let reflection: String?
    var id: Int { day }
}

struct PlanReading: Codable {
    let bookID: String
    let chapter: Int
    let verseStart: Int?
    let verseEnd: Int?

    var displayReference: String {
        guard let book = BibleData.book(id: bookID) else { return "\(bookID) \(chapter)" }
        if let start = verseStart, let end = verseEnd {
            return "\(book.name) \(chapter):\(start)-\(end)"
        }
        return "\(book.name) \(chapter)"
    }
}
