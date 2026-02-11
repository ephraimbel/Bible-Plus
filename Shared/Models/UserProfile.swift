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
    var selectedBibleVoiceID: String
    var readerFontSize: Double
    var readerFontStyleRaw: String
    var readerLineSpacing: Double
    var lastReadBookID: String
    var lastReadChapter: Int
    var lastReadVerseNumber: Int
    var createdAt: Date
    var updatedAt: Date

    var readerFontStyle: ReaderFontStyle {
        get { ReaderFontStyle(rawValue: readerFontStyleRaw) ?? .serif }
        set { readerFontStyleRaw = newValue.rawValue }
    }

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
        isPro: Bool = true,
        aiConversationCount: Int = 0,
        hasCompletedOnboarding: Bool = false,
        selectedBibleVoiceID: String = BibleVoice.onyx.rawValue,
        readerFontSize: Double = 20,
        readerFontStyle: ReaderFontStyle = .serif,
        readerLineSpacing: Double = 6,
        lastReadBookID: String = "genesis",
        lastReadChapter: Int = 1,
        lastReadVerseNumber: Int = 1
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
        self.selectedBibleVoiceID = selectedBibleVoiceID
        self.readerFontSize = readerFontSize
        self.readerFontStyleRaw = readerFontStyle.rawValue
        self.readerLineSpacing = readerLineSpacing
        self.lastReadBookID = lastReadBookID
        self.lastReadChapter = lastReadChapter
        self.lastReadVerseNumber = lastReadVerseNumber
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
