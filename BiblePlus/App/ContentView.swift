import SwiftUI

struct ContentView: View {
    @Binding var deepLinkedContentID: UUID?
    @Environment(\.bpPalette) private var palette
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
            case .feed: "flame"
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
        .onAppear {
            audioBibleService.setSoundscapeService(soundscapeService)
        }
        .toolbarBackground(palette.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: deepLinkedContentID) { _, newValue in
            if newValue != nil {
                selectedTab = .feed
                // Reset after handling so future deep links with the same ID still trigger
                deepLinkedContentID = nil
            }
        }
    }
}
