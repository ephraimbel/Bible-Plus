import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Binding var deepLinkedContentID: UUID?
    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasAutoPlayedSoundscape") private var hasAutoPlayedSoundscape = false
    @State private var selectedTab: Tab = .feed
    @State private var soundscapeService = SoundscapeService()
    @State private var audioBibleService = AudioBibleService()
    // Single shared instance so Settings, onboarding, and any deep-link entry
    // all read from the same `currentCode`. Reassigning language in Settings
    // immediately re-renders every view tree under this environment.
    @State private var localizationService: LocalizationService = .shared
    @State private var showFeedEntryButton = true
    @State private var pendingConversation: PendingConversation?
    @Environment(\.scenePhase) private var scenePhase

    enum Tab: String, CaseIterable {
        case feed, bible, ask, journal, settings

        /// Returning `LocalizedStringKey` (not `String`) is what routes these
        /// through the String Catalog. A raw `String` would bypass the
        /// Bundle-swizzle lookup entirely — tab items would stay in English
        /// even after the user switched languages.
        var title: LocalizedStringKey {
            switch self {
            case .feed: "Home"
            case .bible: "Bible"
            case .ask: "Ask"
            case .journal: "Journal"
            case .settings: "Profile"
            }
        }

        var icon: String {
            switch self {
            case .feed: "house.fill"
            case .bible: "book.fill"
            case .ask: "sparkle"
            case .journal: "book.closed.fill"
            case .settings: "person.fill"
            }
        }
    }

    @ViewBuilder
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label(Tab.feed.title, systemImage: Tab.feed.icon) }
                .tag(Tab.feed)

            BibleView()
                .tabItem { Label(Tab.bible.title, systemImage: Tab.bible.icon) }
                .tag(Tab.bible)

            ConversationListView(pendingConversation: $pendingConversation)
                .tabItem { Label(Tab.ask.title, systemImage: Tab.ask.icon) }
                .tag(Tab.ask)

            JournalView()
                .tabItem { Label(Tab.journal.title, systemImage: Tab.journal.icon) }
                .tag(Tab.journal)

            SettingsView()
                .tabItem { Label(Tab.settings.title, systemImage: Tab.settings.icon) }
                .tag(Tab.settings)
        }
    }

    @ViewBuilder
    private var configuredTabs: some View {
        tabs
        .environment(soundscapeService)
        .environment(audioBibleService)
        .environment(localizationService)
        .environment(\.locale, localizationService.locale)
        .environment(\.layoutDirection, localizationService.layoutDirection)
        .id(localizationService.currentCode ?? "system")
        .tint(palette.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onAppear {
            audioBibleService.setSoundscapeService(soundscapeService)

            // Log app opened for streak tracking
            ActivityService.logAppOpenedIfNeeded(in: modelContext)
            Analytics.track(.appOpened)

            // Auto-play Evening Rest for new users entering after onboarding
            if !hasAutoPlayedSoundscape {
                soundscapeService.play(.eveningRest)
                hasAutoPlayedSoundscape = true
                // Update profile so Sanctuary/Settings reflect the selection
                let descriptor = FetchDescriptor<UserProfile>()
                if let profile = try? modelContext.fetch(descriptor).first {
                    profile.selectedSoundscapeID = Soundscape.eveningRest.rawValue
                    modelContext.safeSave()
                }
            }

            // Recovery path for the daily welcome-back notification.
            // Catches users who denied notification permission during
            // onboarding (so it was never scheduled) but later enabled
            // notifications via Settings — without this, they'd be
            // permanently locked out of the day-2 retention hook.
            ensureWelcomeBackNotificationIfPossible()
        }
        // Let iOS 26 render its native Liquid Glass tab bar. The old
        // UITabBarAppearance overrides (transparent background, nil effect)
        // were holdovers from the flat-bar era that stripped the glass
        // material — removing them restores the system glass at full quality.
        .onReceive(NotificationCenter.default.publisher(for: .dashboardShowFeedChanged)) { notification in
            if let showFeed = notification.userInfo?["showFeed"] as? Bool {
                showFeedEntryButton = !showFeed
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAskTab)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .ask
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToSettingsTab)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .settings
            }
        }
    }

    var body: some View {
        configuredTabs
        .onChange(of: deepLinkedContentID) { _, newValue in
            if let contentID = newValue {
                selectedTab = .feed
                // Post notification so FeedView can scroll to the content
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(
                        name: .feedContentDeepLink,
                        object: nil,
                        userInfo: ["contentID": contentID]
                    )
                }
                deepLinkedContentID = nil
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                soundscapeService.stop()
            }
            if newPhase == .active {
                // Ensure widgets pick up the latest background on every foreground
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAIWithContext)) { notification in
            let title = notification.userInfo?["title"] as? String ?? "New Conversation"
            let context = notification.userInfo?["context"] as? String

            // Create conversation
            let conversation = Conversation(title: title)
            modelContext.insert(conversation)
            modelContext.safeSave()

            // Set pending navigation — ConversationListView picks this up on appear
            pendingConversation = PendingConversation(
                conversationId: conversation.id,
                context: context
            )

            // Switch to Ask tab
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .ask
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedContentDeepLink)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .feed
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { _ in
            // SavedView and other call sites post this when they want to
            // jump into an existing AI conversation. ConversationListView
            // handles the actual nav-stack push; we just make sure the
            // Ask tab is selected first so its NavigationStack is mounted.
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .ask
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scriptureDeepLink)) { notification in
            if let bookName = notification.userInfo?["bookName"] as? String,
               let chapter = notification.userInfo?["chapter"] as? Int {
                let verse = notification.userInfo?["verse"] as? Int ?? 0
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .bible
                }
                // Delay so BibleView renders and its .onReceive is active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(
                        name: .scriptureBibleNavigate,
                        object: nil,
                        userInfo: ["bookName": bookName, "chapter": chapter, "verse": verse]
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationSaveAction)) { notification in
            guard let uuid = notification.userInfo?["contentID"] as? UUID else { return }
            let descriptor = FetchDescriptor<PrayerContent>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let content = try? modelContext.fetch(descriptor).first {
                content.isSaved = true
                modelContext.safeSave()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .progressDeepLink)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .feed
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .showProgressFromWidget, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .plansDeepLink)) { notification in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .feed
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: .showPlansFromWidget,
                    object: nil,
                    userInfo: notification.userInfo
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bibleDeepLink)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .bible
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .askDeepLink)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .ask
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sanctuaryDeepLink)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .feed
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .openSanctuaryFromWidget, object: nil)
            }
        }
    }

    /// Recovery path: every launch, if the user has notifications enabled
    /// and at least one prayer time set, but the daily welcome-back push
    /// isn't scheduled, schedule it. Idempotent — `ensureWelcomeBack…` no-ops
    /// if a request is already pending. Catches users who denied permission
    /// during onboarding then enabled it later via Settings.
    private func ensureWelcomeBackNotificationIfPossible() {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first,
              profile.hasCompletedOnboarding,
              let firstSlot = profile.prayerTimes
                .sorted(by: { $0.rawValue < $1.rawValue })
                .first
        else { return }

        NotificationService.shared.ensureWelcomeBackScheduledIfNeeded(
            name: profile.firstName,
            slot: firstSlot
        )
    }

}

// MARK: - Pending Conversation

struct PendingConversation {
    let conversationId: UUID
    let context: String?
}
