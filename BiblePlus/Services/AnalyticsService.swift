import Foundation
import TelemetryClient

enum Analytics {
    // MARK: - Configure

    static func configure() {
        let config = TelemetryManagerConfiguration(
            appID: "2C2CA89C-B004-4501-B8C5-CB3DB18E452F"
        )
        TelemetryManager.initialize(with: config)
    }

    // MARK: - Events

    static func track(_ event: Event, properties: [String: String] = [:]) {
        TelemetryManager.send(event.rawValue, with: properties)
    }

    // MARK: - Event Definitions

    enum Event: String {
        // Onboarding
        case onboardingStarted = "onboarding_started"
        case onboardingCompleted = "onboarding_completed"

        // Paywall
        case paywallViewed = "paywall_viewed"
        case paywallDismissed = "paywall_dismissed"
        case paywallPurchaseStarted = "paywall_purchase_started"
        case paywallPurchaseCompleted = "paywall_purchase_completed"
        case paywallRestoreTapped = "paywall_restore_tapped"
        case paywallPageAdvanced = "paywall_page_advanced"

        // AI Chat
        case aiMessageSent = "ai_message_sent"
        case aiConversationStarted = "ai_conversation_started"
        case aiRateLimitHit = "ai_rate_limit_hit"
        case aiFollowUpTapped = "ai_followup_tapped"
        case aiAmenTapped = "ai_amen_tapped"

        // Bible
        case bibleChapterRead = "bible_chapter_read"
        case bibleVerseExplained = "bible_verse_explained"

        // Feed
        case feedCardViewed = "feed_card_viewed"
        case feedCardLiked = "feed_card_liked"
        case feedCardShared = "feed_card_shared"

        // Plans
        case planStarted = "plan_started"
        case planDayCompleted = "plan_day_completed"

        // Sanctuary
        case sanctuaryOpened = "sanctuary_opened"

        // Engagement
        case appOpened = "app_opened"
        case streakMilestone = "streak_milestone"

        // Welcome conversation retention hooks (post-onboarding flow).
        // These four events let us measure the new "welcomed not dumped"
        // funnel: did the user land in the welcome conversation, did they
        // see the typewriter through, did they reply, and did they come
        // back via the daily welcome-back push.
        case welcomeConversationOpened = "welcome_conversation_opened"
        case welcomeTypewriterCompleted = "welcome_typewriter_completed"
        case welcomeReplied = "welcome_replied"
        case welcomeNotificationTapped = "welcome_notification_tapped"
    }
}
