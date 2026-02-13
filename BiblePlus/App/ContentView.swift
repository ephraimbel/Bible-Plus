import SwiftUI
import SwiftData

struct ContentView: View {
    @Binding var deepLinkedContentID: UUID?
    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasAutoPlayedSoundscape") private var hasAutoPlayedSoundscape = false
    @State private var selectedTab: Tab = .feed
    @State private var soundscapeService = SoundscapeService()
    @State private var audioBibleService = AudioBibleService()

    enum Tab: String, CaseIterable {
        case feed, bible, ask, saved, settings

        var title: String {
            switch self {
            case .feed: "Feed"
            case .bible: "Bible"
            case .ask: "Ask"
            case .saved: "Saved"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .feed: "house.fill"
            case .bible: "book"
            case .ask: "bubble.left.and.bubble.right"
            case .saved: "bookmark"
            case .settings: "gearshape"
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

            ConversationListView()
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

            // Auto-play Evening Rest for new users entering after onboarding
            if !hasAutoPlayedSoundscape {
                soundscapeService.play(.eveningRest)
                hasAutoPlayedSoundscape = true
                // Update profile so Sanctuary/Settings reflect the selection
                let descriptor = FetchDescriptor<UserProfile>()
                if let profile = try? modelContext.fetch(descriptor).first {
                    profile.selectedSoundscapeID = Soundscape.eveningRest.rawValue
                    try? modelContext.save()
                }
            }
        }
        .toolbarBackground(palette.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: deepLinkedContentID) { _, newValue in
            if newValue != nil {
                selectedTab = .feed
                deepLinkedContentID = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scriptureDeepLink)) { notification in
            if let bookName = notification.userInfo?["bookName"] as? String,
               let chapter = notification.userInfo?["chapter"] as? Int {
                // Smooth tab switch, then tell BibleView to navigate.
                // BibleView stores pending nav if its viewModel isn't ready yet.
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedTab = .bible
                }
                NotificationCenter.default.post(
                    name: .scriptureBibleNavigate,
                    object: nil,
                    userInfo: ["bookName": bookName, "chapter": chapter]
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationSaveAction)) { notification in
            guard let uuid = notification.userInfo?["contentID"] as? UUID else { return }
            let descriptor = FetchDescriptor<PrayerContent>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let content = try? modelContext.fetch(descriptor).first {
                content.isSaved = true
                try? modelContext.save()
            }
        }
    }
}
