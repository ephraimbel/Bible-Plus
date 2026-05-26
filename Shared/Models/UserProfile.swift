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
    /// When set, overrides `preferredTranslation` with a multilingual catalog
    /// reference (see `TranslationRef` + `TranslationCatalog`). Optional so
    /// existing rows migrate cleanly — nil means the legacy enum wins.
    var preferredTranslationRefID: String? = nil
    var prayerTimes: [PrayerTimeSlot]
    var selectedThemeID: String
    var selectedSoundscapeID: String
    var selectedBackgroundID: String
    var widgetSelectedBackgroundID: String?
    var colorMode: ColorMode
    var streakCount: Int
    var lastActiveDate: Date?
    var longestStreak: Int
    var isPro: Bool
    var aiConversationCount: Int
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool
    var streakReminderEnabled: Bool
    var planReminderEnabled: Bool
    var faithBoostsEnabled: Bool
    var selectedNotificationTopicsRaw: [String]?
    var selectedBibleVoiceID: String
    var readerFontSize: Double
    var readerFontStyleRaw: String
    var readerFontWeightRaw: String?
    var readerLineSpacing: Double
    var readerTextAlignmentJustified: Bool?
    var readerShowVerseNumbers: Bool?
    var lastReadBookID: String
    var lastReadChapter: Int
    var lastReadVerseNumber: Int
    var createdAt: Date
    var updatedAt: Date

    /// Long-term memory digest — a 3-5 sentence natural-language summary of
    /// who this user is spiritually, what they're walking through, and what
    /// passages resonate with them. Rebuilt periodically by AIService and
    /// injected into the system prompt on every primary chat call. Optional
    /// so existing rows migrate cleanly.
    var aiMemoryDigest: String? = nil

    /// When the digest was last refreshed. Used to throttle the refresh
    /// cadence (we don't refresh on every message — too expensive).
    var aiMemoryDigestUpdatedAt: Date? = nil

    /// Count of user messages since the last digest refresh. Used by the
    /// throttling logic to decide when to fire the next refresh.
    var aiMessagesSinceDigestRefresh: Int = 0

    /// Pinned facts the AI has been told to never forget. Each entry is one
    /// short, atomic fact ("Has a daughter named Sarah", "Husband died Oct
    /// 2024", "Walks through deconstruction"). Capped at 20 to keep the
    /// system prompt bounded. Optional so existing rows migrate cleanly.
    var aiPinnedFactsRaw: [String]? = nil

    /// User-supplied profile picture (PFP). Stored as raw image data so it
    /// travels with SwiftData and survives across launches without an
    /// external file. Optional so existing rows migrate cleanly.
    var profileImageData: Data? = nil

    /// ID of the conversation pre-seeded at the end of onboarding. Messages
    /// in this conversation are excluded from the 5-message lifetime free
    /// quota — see `Conversation.isOnboarding`. Stored on UserProfile so the
    /// router can deep-link the user into it on first launch.
    var welcomeConversationID: UUID? = nil

    /// The verse the user chose to "Keep this with me" during the onboarding
    /// Personal Verse Reveal. Stored as plain text + reference (not just a
    /// content ID) so it persists even for curated fallback verses, and so
    /// the home screen can resurface it as the user's first daily verse —
    /// making the reveal moment actually pay off.
    var keptVerseText: String? = nil
    var keptVerseReference: String? = nil
    /// When the verse was kept. The home screen features the kept verse for
    /// a few days after onboarding (the payoff), then resumes normal daily
    /// rotation — the verse persists in the Saved collection regardless.
    var keptVerseDate: Date? = nil

    /// Friendly accessor for pinned facts. Setting an empty array clears the
    /// field to nil so SwiftData stays tidy.
    var aiPinnedFacts: [String] {
        get { aiPinnedFactsRaw ?? [] }
        set { aiPinnedFactsRaw = newValue.isEmpty ? nil : newValue }
    }

    var selectedNotificationTopics: [NotificationTopic] {
        get {
            guard let raw = selectedNotificationTopicsRaw else {
                return NotificationTopic.freeTopics
            }
            let topics = raw.compactMap { NotificationTopic(rawValue: $0) }
            return topics.isEmpty ? NotificationTopic.freeTopics : topics
        }
        set {
            selectedNotificationTopicsRaw = newValue.map(\.rawValue)
        }
    }

    var readerFontStyle: ReaderFontStyle {
        get { ReaderFontStyle(rawValue: readerFontStyleRaw) ?? .serif }
        set { readerFontStyleRaw = newValue.rawValue }
    }

    var readerFontWeight: ReaderFontWeight {
        get { readerFontWeightRaw.flatMap { ReaderFontWeight(rawValue: $0) } ?? .regular }
        set { readerFontWeightRaw = newValue.rawValue }
    }

    var textAlignmentJustified: Bool {
        get { readerTextAlignmentJustified ?? false }
        set { readerTextAlignmentJustified = newValue }
    }

    var showVerseNumbers: Bool {
        get { readerShowVerseNumbers ?? true }
        set { readerShowVerseNumbers = newValue }
    }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        faithLevel: FaithLevel = .growing,
        lifeSeasons: [LifeSeason] = [],
        currentBurdens: [Burden] = [],
        preferredTranslation: BibleTranslation = .kjv,
        prayerTimes: [PrayerTimeSlot] = [],
        selectedThemeID: String = "sunrise-mountains",
        selectedSoundscapeID: String = "pureSilence",
        selectedBackgroundID: String = "warm-gold",
        widgetSelectedBackgroundID: String? = nil,
        colorMode: ColorMode = .auto,
        streakCount: Int = 0,
        lastActiveDate: Date? = nil,
        longestStreak: Int = 0,
        isPro: Bool = false,
        aiConversationCount: Int = 0,
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false,
        streakReminderEnabled: Bool = true,
        planReminderEnabled: Bool = true,
        faithBoostsEnabled: Bool = false,
        selectedNotificationTopicsRaw: [String]? = nil,
        selectedBibleVoiceID: String = BibleVoice.onyx.rawValue,
        readerFontSize: Double = 20,
        readerFontStyle: ReaderFontStyle = .serif,
        readerFontWeight: ReaderFontWeight = .regular,
        readerLineSpacing: Double = 6,
        readerTextAlignmentJustified: Bool = false,
        readerShowVerseNumbers: Bool = true,
        lastReadBookID: String = "GEN",
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
        self.widgetSelectedBackgroundID = widgetSelectedBackgroundID
        self.colorMode = colorMode
        self.streakCount = streakCount
        self.lastActiveDate = lastActiveDate
        self.longestStreak = longestStreak
        self.isPro = isPro
        self.aiConversationCount = aiConversationCount
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
        self.streakReminderEnabled = streakReminderEnabled
        self.planReminderEnabled = planReminderEnabled
        self.faithBoostsEnabled = faithBoostsEnabled
        self.selectedNotificationTopicsRaw = selectedNotificationTopicsRaw
        self.selectedBibleVoiceID = selectedBibleVoiceID
        self.readerFontSize = readerFontSize
        self.readerFontStyleRaw = readerFontStyle.rawValue
        self.readerFontWeightRaw = readerFontWeight.rawValue
        self.readerLineSpacing = readerLineSpacing
        self.readerTextAlignmentJustified = readerTextAlignmentJustified
        self.readerShowVerseNumbers = readerShowVerseNumbers
        self.lastReadBookID = lastReadBookID
        self.lastReadChapter = lastReadChapter
        self.lastReadVerseNumber = lastReadVerseNumber
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
