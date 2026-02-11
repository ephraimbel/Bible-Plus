import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var firstName: String
    var faithLevel: FaithLevel
    var lifeSeasons: [LifeSeason]
    var currentBurdens: [Burden]
    var preferredTranslation: BibleTranslation
    var prayerTimes: [PrayerTimeSlot]
    var selectedThemeID: String
    var selectedSoundscapeID: String
    var selectedBackgroundID: String
    var colorMode: ColorMode
    var streakCount: Int
    var lastActiveDate: Date?
    var longestStreak: Int
    var isPro: Bool
    var aiConversationCount: Int
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        firstName: String = "",
        faithLevel: FaithLevel = .growing,
        lifeSeasons: [LifeSeason] = [],
        currentBurdens: [Burden] = [],
        preferredTranslation: BibleTranslation = .niv,
        prayerTimes: [PrayerTimeSlot] = [],
        selectedThemeID: String = "sunrise-mountains",
        selectedSoundscapeID: String = "pureSilence",
        selectedBackgroundID: String = "warm-gold",
        colorMode: ColorMode = .auto,
        streakCount: Int = 0,
        lastActiveDate: Date? = nil,
        longestStreak: Int = 0,
        isPro: Bool = false,
        aiConversationCount: Int = 0,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.firstName = firstName
        self.faithLevel = faithLevel
        self.lifeSeasons = lifeSeasons
        self.currentBurdens = currentBurdens
        self.preferredTranslation = preferredTranslation
        self.prayerTimes = prayerTimes
        self.selectedThemeID = selectedThemeID
        self.selectedSoundscapeID = selectedSoundscapeID
        self.selectedBackgroundID = selectedBackgroundID
        self.colorMode = colorMode
        self.streakCount = streakCount
        self.lastActiveDate = lastActiveDate
        self.longestStreak = longestStreak
        self.isPro = isPro
        self.aiConversationCount = aiConversationCount
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
