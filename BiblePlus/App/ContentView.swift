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
    @State private var showFeedEntryButton = true
    @State private var pendingConversation: PendingConversation?
    @Environment(\.scenePhase) private var scenePhase

    enum Tab: String, CaseIterable {
        case feed, bible, ask, saved, settings

        var title: String {
            switch self {
            case .feed: "Home"
            case .bible: "Bible"
            case .ask: "Ask"
            case .saved: "Saved"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .feed: "house.fill"
            case .bible: "book.fill"
            case .ask: "bubble.left.and.bubble.right.fill"
            case .saved: "bookmark.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    var body: some View {
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

            SavedView()
                .tabItem { Label(Tab.saved.title, systemImage: Tab.saved.icon) }
                .tag(Tab.saved)

            SettingsView()
                .tabItem { Label(Tab.settings.title, systemImage: Tab.settings.icon) }
                .tag(Tab.settings)
        }
        .environment(soundscapeService)
        .environment(audioBibleService)
        .tint(palette.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onAppear {
            audioBibleService.setSoundscapeService(soundscapeService)

            // Log app opened for streak tracking
            ActivityService.logAppOpenedIfNeeded(in: modelContext)

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
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear {
            // Force tab bar fully transparent at runtime
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = .clear
            tabBarAppearance.backgroundEffect = nil
            tabBarAppearance.backgroundImage = UIImage()
            tabBarAppearance.shadowColor = .clear
            tabBarAppearance.shadowImage = UIImage()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        .onReceive(NotificationCenter.default.publisher(for: .dashboardShowFeedChanged)) { notification in
            if let showFeed = notification.userInfo?["showFeed"] as? Bool {
                showFeedEntryButton = !showFeed
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .switchToAskTab)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = .ask
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
}

// MARK: - Pending Conversation

struct PendingConversation {
    let conversationId: UUID
    let context: String?
}
