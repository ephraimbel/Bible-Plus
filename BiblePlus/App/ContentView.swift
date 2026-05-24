import SwiftUI
import SwiftData
import WidgetKit

// MARK: - ContentView (NavigationStack, no tab bar)
//
// Home is the only root. Bible, Saved, Settings, Reading Plans, and
// Chat are pushed destinations on a single NavigationStack. Sanctuary
// stays a fullScreenCover (its immersive UI needs to fully take over
// the screen) and Conversation History is a presentation sheet hung
// off the drawer (Phase 3).
//
// The notification-handler stack is extracted into a ViewModifier
// because chaining ~10 `.onReceive` modifiers in `body` puts the Swift
// type-checker over its complexity budget and the file fails to compile.
struct ContentView: View {
    @Binding var deepLinkedContentID: UUID?
    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasAutoPlayedSoundscape") private var hasAutoPlayedSoundscape = false
    /// One-time flag: have we deep-linked the user into the seeded welcome
    /// conversation yet? Trips on the first ContentView appear after
    /// onboarding so the user lands inside their first chat instead of on
    /// Home. Persisted so re-launches don't keep hijacking the user.
    @AppStorage("hasRoutedToWelcomeConversation") private var hasRoutedToWelcomeConversation = false

    @State private var navPath = NavigationPath()
    @State private var soundscapeService = SoundscapeService()
    @State private var audioBibleService = AudioBibleService()
    /// Single shared instance so Settings, onboarding, and any deep-link
    /// entry all read from the same `currentCode`. Reassigning language in
    /// Settings immediately re-renders every view tree under this env.
    @State private var localizationService: LocalizationService = .shared
    @State private var pendingConversation: PendingConversation?
    /// Conversation history is presented as a sheet from the drawer.
    /// `.switchToAskTab` / `.askDeepLink` flip this flag.
    @State private var showConversationHistory = false
    /// Main menu drawer — opened by the home top-bar profile pill.
    /// Routes to History · Saved · Progress · Plans · Sanctuary · Settings.
    @State private var showMainMenu = false
    @Environment(\.scenePhase) private var scenePhase

    /// Push targets reachable from the home NavigationStack. Hashable
    /// because NavigationPath stores them by value.
    enum HomeDestination: Hashable {
        case bible
        case chat(conversationId: UUID, initialContext: String?)
        case settings
        case saved
        case plans
    }

    // MARK: - Body

    var body: some View {
        configuredRoot
            .sheet(isPresented: $showConversationHistory) {
                ConversationListView(
                    pendingConversation: $pendingConversation,
                    onOpenConversationFullPage: { conversationId, context in
                        // Close the history sheet, then push the chat onto
                        // the main stack so it opens full-screen rather than
                        // inside the sheet. The delay lets the sheet finish
                        // dismissing before the push animates.
                        showConversationHistory = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navPath.append(HomeDestination.chat(conversationId: conversationId, initialContext: context))
                        }
                    }
                )
            }
            .sheet(isPresented: $showMainMenu) {
                MainMenuSheet()
            }
            .modifier(NotificationRouter(
                navPath: $navPath,
                showConversationHistory: $showConversationHistory,
                showMainMenu: $showMainMenu,
                modelContext: modelContext
            ))
            .onAppear(perform: handleAppear)
            .onChange(of: scenePhase, handleScenePhaseChange)
    }

    @ViewBuilder
    private var configuredRoot: some View {
        NavigationStack(path: $navPath) {
            FeedView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: HomeDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .environment(soundscapeService)
        .environment(audioBibleService)
        .environment(localizationService)
        .environment(\.locale, localizationService.locale)
        .environment(\.layoutDirection, localizationService.layoutDirection)
        .id(localizationService.currentCode ?? "system")
        .tint(palette.accent)
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .bible:
            BibleView()
        case .chat(let id, let ctx):
            ChatView(conversationId: id, initialContext: ctx)
        case .settings:
            SettingsView()
        case .saved:
            SavedView()
        case .plans:
            ReadingPlansView(isPro: currentProfileIsPro)
        }
    }

    /// Synchronous profile fetch for views that need a Pro flag at push
    /// time. The query runs once per navigation push, not per body
    /// recompute, so it's cheap.
    private var currentProfileIsPro: Bool {
        let descriptor = FetchDescriptor<UserProfile>()
        return (try? modelContext.fetch(descriptor).first?.isPro) ?? false
    }

    // MARK: - Lifecycle handlers

    private func handleAppear() {
        audioBibleService.setSoundscapeService(soundscapeService)

        ActivityService.logAppOpenedIfNeeded(in: modelContext)
        Analytics.track(.appOpened)

        if !hasAutoPlayedSoundscape {
            soundscapeService.play(.eveningRest)
            hasAutoPlayedSoundscape = true
            let descriptor = FetchDescriptor<UserProfile>()
            if let profile = try? modelContext.fetch(descriptor).first {
                profile.selectedSoundscapeID = Soundscape.eveningRest.rawValue
                modelContext.safeSave()
            }
        }

        // First-launch-after-onboarding deep link: push the seeded
        // welcome conversation immediately so the user lands inside
        // their first chat instead of on an empty home screen.
        routeToWelcomeConversationIfNeeded()

        ensureWelcomeBackNotificationIfPossible()
    }

    private func handleScenePhaseChange(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        if newPhase == .background {
            soundscapeService.stop()
        }
        if newPhase == .active {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Helpers

    /// Recovery path: every launch, if the user has notifications enabled
    /// and at least one prayer time set, but the daily welcome-back push
    /// isn't scheduled, schedule it. Idempotent — `ensureWelcomeBack…` no-ops
    /// if a request is already pending.
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

    /// Push the seeded welcome conversation onto the nav stack on the
    /// FIRST launch after onboarding completes. Subsequent launches are
    /// no-ops because the @AppStorage flag has been flipped.
    private func routeToWelcomeConversationIfNeeded() {
        guard !hasRoutedToWelcomeConversation else { return }
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first,
              profile.hasCompletedOnboarding,
              let convoID = profile.welcomeConversationID
        else { return }

        hasRoutedToWelcomeConversation = true
        navPath.append(HomeDestination.chat(conversationId: convoID, initialContext: nil))
    }
}

// MARK: - Notification Router
//
// All the global notification handlers (composer submit, widget deep
// links, scripture deep links, save action, etc.) chained into a single
// ViewModifier so ContentView's body stays inside the Swift compiler's
// type-check complexity budget. Each handler maps a notification into
// either a NavigationPath push or a sheet present.
private struct NotificationRouter: ViewModifier {
    @Binding var navPath: NavigationPath
    @Binding var showConversationHistory: Bool
    @Binding var showMainMenu: Bool
    let modelContext: ModelContext

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openAIWithContext)) { notification in
                let title = notification.userInfo?["title"] as? String ?? "New Conversation"
                let context = notification.userInfo?["context"] as? String

                let conversation = Conversation(title: title)
                modelContext.insert(conversation)
                modelContext.safeSave()

                navPath.append(ContentView.HomeDestination.chat(conversationId: conversation.id, initialContext: context))
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToBibleTab)) { _ in
                navPath.append(ContentView.HomeDestination.bible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToSettingsTab)) { _ in
                navPath.append(ContentView.HomeDestination.settings)
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToSavedTab)) { _ in
                navPath.append(ContentView.HomeDestination.saved)
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToAskTab)) { _ in
                showConversationHistory = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMainMenu)) { _ in
                showMainMenu = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .bibleDeepLink)) { _ in
                navPath.append(ContentView.HomeDestination.bible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .askDeepLink)) { _ in
                showConversationHistory = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .progressDeepLink)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: .showProgressFromWidget, object: nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .plansDeepLink)) { notification in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(
                        name: .showPlansFromWidget,
                        object: nil,
                        userInfo: notification.userInfo
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sanctuaryDeepLink)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: .openSanctuaryFromWidget, object: nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scriptureDeepLink)) { notification in
                guard let bookName = notification.userInfo?["bookName"] as? String,
                      let chapter = notification.userInfo?["chapter"] as? Int else { return }
                let verse = notification.userInfo?["verse"] as? Int ?? 0
                navPath.append(ContentView.HomeDestination.bible)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(
                        name: .scriptureBibleNavigate,
                        object: nil,
                        userInfo: ["bookName": bookName, "chapter": chapter, "verse": verse]
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
                guard let idString = notification.userInfo?["conversationId"] as? String,
                      let conversationId = UUID(uuidString: idString) else { return }
                let context = notification.userInfo?["context"] as? String
                navPath.append(ContentView.HomeDestination.chat(conversationId: conversationId, initialContext: context))
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
    }
}

// MARK: - Pending Conversation

struct PendingConversation {
    let conversationId: UUID
    let context: String?
}
