import Foundation
import SwiftData

@Model
final class PrayerContent {
    var id: UUID
    var type: ContentType
    var templateText: String
    var verseReference: String?
    var verseText: String?
    var category: String
    var timeOfDay: [PrayerTimeSlot]
    var applicableSeasons: [LifeSeason]
    var applicableBurdens: [Burden]
    var faithLevelMin: FaithLevel
    var isProOnly: Bool
    var isSaved: Bool
    var seedVersion: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: ContentType = .prayer,
        templateText: String = "",
        verseReference: String? = nil,
        verseText: String? = nil,
        category: String = "",
        timeOfDay: [PrayerTimeSlot] = [],
        applicableSeasons: [LifeSeason] = [],
        applicableBurdens: [Burden] = [],
        faithLevelMin: FaithLevel = .justCurious,
        isProOnly: Bool = false,
        isSaved: Bool = false,
        seedVersion: Int = 1
    ) {
        self.id = id
        self.type = type
        self.templateText = templateText
        self.verseReference = verseReference
        self.verseText = verseText
        self.category = category
        self.timeOfDay = timeOfDay
        self.applicableSeasons = applicableSeasons
        self.applicableBurdens = applicableBurdens
        self.faithLevelMin = faithLevelMin
        self.isProOnly = isProOnly
        self.isSaved = isSaved
        self.seedVersion = seedVersion
        self.createdAt = Date()
    }
}
