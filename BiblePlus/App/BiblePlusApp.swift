import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat

/// Bridge to the C function defined in `BPEarlyBootstrap.m`. Declaring it
/// here serves two purposes: (1) we can invoke it explicitly from init()
/// as belt-and-suspenders, and (2) the Swift reference pins the `.o` so
/// the linker doesn't dead-strip the translation unit — the constructor
/// attribute alone was getting silently dropped.
@_silgen_name("BPEarlyLanguageLock")
private func _bpEarlyLanguageLock()

@main
struct BiblePlusApp: App {
    let modelContainer: ModelContainer
    let modelContainerError: Bool
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        // Belt-and-suspenders: BPEarlyBootstrap.m's constructor attribute
        // already runs this at dyld load time (before @main), but we call
        // it again here so the symbol is guaranteed referenced — otherwise
        // the linker dead-strips the whole translation unit and the
        // first-launch English lock never fires.
        _bpEarlyLanguageLock()

        // Bootstrap the localization service BEFORE anything else. On first
        // launch this mirrors the AppleLanguages write above and initializes
        // the Swift-side state (Bundle override + @Observable service).
        LocalizationService.bootstrap()

        let container: ModelContainer
        var hadError = false
        do {
            container = try SharedModelContainer.create()
        } catch {
            hadError = true
            // Fall back to an in-memory container so the app can launch
            let schema = Schema([
                UserProfile.self,
                PrayerContent.self,
                ContentCollection.self,
                ChatMessage.self,
                Conversation.self,
                SavedBibleVerse.self,
                ReadingPlan.self,
                UserPlanProgress.self,
                ActivityEvent.self,
            ])
            let fallback = ModelConfiguration(
                "BiblePlusFallback",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            // In-memory container so the app can at least launch and show DataErrorView.
            // Falls back to empty schema which cannot fail (in-memory, no models).
            if let mem = try? ModelContainer(for: schema, configurations: [fallback]) {
                container = mem
            } else {
                // swiftlint:disable:next force_try
                container = try! ModelContainer(
                    for: Schema([]),
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            }
        }
        modelContainer = container
        modelContainerError = hadError

        // Global UIKit appearance: fully transparent tab bar, no separator
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = .clear
        tabAppearance.backgroundEffect = nil
        tabAppearance.backgroundImage = UIImage()
        tabAppearance.shadowColor = nil
        tabAppearance.shadowImage = UIImage()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().backgroundColor = .clear
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()

        // Global nav bar title colors matching our palette
        let titleColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1)   // #ECECEC
                : UIColor(red: 0.231, green: 0.169, blue: 0.114, alpha: 1)  // #3B2B1D sepia brown
        }
        let bgColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.17, green: 0.17, blue: 0.15, alpha: 1)   // #2B2A27
                : UIColor(red: 0.937, green: 0.894, blue: 0.839, alpha: 1) // #EFE4D6 Haven tan paper
        }
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bgColor
        navAppearance.titleTextAttributes = [.foregroundColor: titleColor]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(red: 0.79, green: 0.66, blue: 0.43, alpha: 1) // #C9A96E accent

        // Kick off a background refresh of the multilingual translation
        // catalog (bible.helloao.org). Fire-and-forget — the reader falls
        // back to bundled KJV if the manifest hasn't landed yet.
        Task { @MainActor in
            TranslationCatalog.shared.refreshIfNeeded()
        }

        // RevenueCat — full integration (handles purchases, entitlements, renewals)
        Purchases.configure(withAPIKey: "appl_FjknWibdqNxzGBryURSpcNKbxcv")

        // TelemetryDeck — privacy-first analytics
        Analytics.configure()

        guard !hadError else { return }

        // Seed content on first launch and migrate legacy messages
        let seedContext = ModelContext(modelContainer)
        ContentSeeder.seedIfNeeded(modelContext: seedContext)
        ContentSeeder.seedPlansIfNeeded(modelContext: seedContext)
        ContentSeeder.seedDailyPathsIfNeeded(modelContext: seedContext)
        ContentSeeder.migrateOrphanedMessages(modelContext: seedContext)

        // Recovery: ensure the Daily Path reminder is correctly scheduled
        // (or cancelled) for the user's current state. Cheap, idempotent,
        // safe to call on every launch. Internal refresh logic cancels the
        // existing pending request before scheduling, so duplicates can't
        // accrue across launches.
        Task { @MainActor in
            NotificationService.shared.refreshDailyPathReminder(modelContext: seedContext)
        }

        // Ensure widget has the current background frame
        let profileFetch = FetchDescriptor<UserProfile>()
        if let profile = try? seedContext.fetch(profileFetch).first {
            let effectiveID = profile.widgetSelectedBackgroundID ?? profile.selectedBackgroundID
            if let bg = SanctuaryBackground.background(for: effectiveID) {
                WidgetBackgroundService.updateWidgetBackground(for: bg)
            }
        }

        // Refresh notification content on each launch
        if let profile = try? seedContext.fetch(profileFetch).first,
           profile.hasCompletedOnboarding,
           profile.notificationsEnabled {
            let contentFetch = FetchDescriptor<PrayerContent>()
            let allContent = (try? seedContext.fetch(contentFetch)) ?? []
            let prayerTimes = profile.prayerTimes
            let firstName = profile.firstName
            let burdens = profile.currentBurdens
            let seasons = profile.lifeSeasons
            let faithLevel = profile.faithLevel
            let isPro = profile.isPro
            let streakCount = profile.streakCount
            let streakReminderEnabled = profile.streakReminderEnabled
            let planReminderEnabled = profile.planReminderEnabled
            let faithBoostsEnabled = profile.faithBoostsEnabled
            let selectedTopics = profile.selectedNotificationTopics

            // Find active reading plan for plan reminders
            var activePlanName: String?
            var activePlanID: String?
            var activePlanNextDay: Int?
            var activePlanTotalDays: Int?

            let progressFetch = FetchDescriptor<UserPlanProgress>(
                predicate: #Predicate { $0.isActive && $0.completedDate == nil }
            )
            if let activeProgress = try? seedContext.fetch(progressFetch).first {
                let targetPlanID = activeProgress.planID
                let planFetch = FetchDescriptor<ReadingPlan>(
                    predicate: #Predicate { $0.id == targetPlanID }
                )
                if let plan = try? seedContext.fetch(planFetch).first {
                    activePlanName = plan.name
                    activePlanID = plan.id
                    activePlanTotalDays = plan.totalDays
                    activePlanNextDay = activeProgress.nextDay(totalDays: plan.totalDays)
                }
            }

            Task { @MainActor in
                await NotificationService.shared.rescheduleFromSnapshot(
                    prayerTimes: prayerTimes,
                    firstName: firstName,
                    burdens: burdens,
                    seasons: seasons,
                    faithLevel: faithLevel,
                    isPro: isPro,
                    content: allContent,
                    streakCount: streakCount,
                    streakReminderEnabled: streakReminderEnabled,
                    planReminderEnabled: planReminderEnabled,
                    activePlanName: activePlanName,
                    activePlanID: activePlanID,
                    activePlanNextDay: activePlanNextDay,
                    activePlanTotalDays: activePlanTotalDays,
                    faithBoostsEnabled: faithBoostsEnabled,
                    selectedTopics: selectedTopics
                )
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(hasDataError: modelContainerError)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Delegate (Notification Handling)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            NotificationService.shared.registerCategories()
            TikTokAnalyticsService.shared.initializeSDK()
        }
        return true
    }

    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle notification tap and action buttons
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        // "Copy Text" action — copy notification body to clipboard
        if actionIdentifier == "COPY_ACTION" {
            let body = response.notification.request.content.body
            await MainActor.run {
                UIPasteboard.general.string = body
            }
            return
        }

        // "Save" action — mark feed content as favorite
        if actionIdentifier == "SAVE_ACTION" {
            if let idString = userInfo["contentID"] as? String,
               let uuid = UUID(uuidString: idString) {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .notificationSaveAction,
                        object: nil,
                        userInfo: ["contentID": uuid]
                    )
                }
            }
            return
        }

        // Reading plan deep link
        if let deepLink = userInfo["deepLink"] as? String,
           deepLink == "readingPlan",
           let planID = userInfo["planID"] as? String {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .readingPlanDeepLink,
                    object: nil,
                    userInfo: ["planID": planID]
                )
            }
            return
        }

        // Daily welcome-back tap → route to the Feed so the user lands
        // on the day's content. This is the recurring retention push set
        // up at the end of onboarding.
        if let type = userInfo["type"] as? String, type == "welcome_back" {
            await MainActor.run {
                NotificationCenter.default.post(name: .feedContentDeepLink, object: nil)
                Analytics.track(.welcomeNotificationTapped)
            }
            return
        }

        // Default tap — deep link to content or Bible verse
        if let idString = userInfo["contentID"] as? String,
           let uuid = UUID(uuidString: idString) {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .notificationDeepLink,
                    object: nil,
                    userInfo: ["contentID": uuid]
                )
            }
        } else if let bookName = userInfo["bookName"] as? String,
                  let chapter = userInfo["chapter"] as? Int {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .scriptureDeepLink,
                    object: nil,
                    userInfo: ["bookName": bookName, "chapter": chapter]
                )
            }
        }
    }
}

struct RootView: View {
    let hasDataError: Bool
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemScheme
    @State private var deepLinkedContentID: UUID?
    @State private var showSplash = true
    @State private var storeKitService = StoreKitService()
    @State private var reviewService = ReviewService.shared
    // LocalizationService is a singleton; holding it in @State gives SwiftUI
    // a stable identity for observation so the whole tree re-renders when
    // the user switches languages from Settings.
    @State private var localizationService: LocalizationService = .shared

    private var currentProfile: UserProfile? { profiles.first }
    private var hasCompletedOnboarding: Bool {
        currentProfile?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        if hasDataError {
            DataErrorView()
        } else {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    ContentView(deepLinkedContentID: $deepLinkedContentID)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity
                        ))
                } else {
                    ConversationalOnboardingView()
                        .transition(.opacity)
                }
            }
            .environment(storeKitService)
            .preferredColorScheme(resolvedColorScheme)
            .environment(
                \.bpPalette,
                BPColorPalette.resolve(
                    mode: currentProfile?.colorMode ?? .auto,
                    systemScheme: systemScheme
                )
            )
            .animation(BPAnimation.pageTransition, value: hasCompletedOnboarding)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .notificationDeepLink)) { notification in
                if let uuid = notification.userInfo?["contentID"] as? UUID {
                    deepLinkedContentID = uuid
                }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Review prompt overlay
            if reviewService.showPrompt {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .zIndex(2)
                    .onTapGesture { reviewService.userTappedNotYet() }

                ReviewPromptView(
                    onYes: { reviewService.userTappedYes() },
                    onNotYet: { reviewService.userTappedNotYet() }
                )
                .zIndex(3)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .environment(reviewService)
        .environment(localizationService)
        .environment(\.locale, localizationService.locale)
        .environment(\.layoutDirection, localizationService.layoutDirection)
        // Force the whole tree to rebuild when the active language changes —
        // ensures every cached `Text(...)` re-resolves immediately without
        // requiring an app relaunch.
        .id(localizationService.currentCode ?? "system")
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: reviewService.showPrompt)
        .onAppear {
            // Splash hold tuned to let the glow bloom land (~1.0s) plus a
            // short beat so the handoff to Welcome feels intentional, not
            // impatient. Cut from 2.0s — the extra 800ms was dead air.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    showSplash = false
                }
            }
        }
        .onChange(of: storeKitService.isPro) { _, newValue in
            if let profile = currentProfile, profile.isPro != newValue {
                profile.isPro = newValue
                modelContext.safeSave()
            }
        }
        .onAppear {
            if let profile = currentProfile {
                profile.isPro = storeKitService.isPro
                modelContext.safeSave()
            }
        }
        } // else
    }

    private var resolvedColorScheme: ColorScheme? {
        guard let mode = currentProfile?.colorMode else { return nil }
        switch mode {
        case .light: return .light
        case .dark, .immersive: return .dark
        case .auto: return nil
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "bibleplus" else { return }

        switch url.host {
        case "content":
            // bibleplus://content/{uuid}
            if let idString = url.pathComponents.dropFirst().first,
               let uuid = UUID(uuidString: idString) {
                deepLinkedContentID = uuid
            }
        case "progress":
            // bibleplus://progress
            NotificationCenter.default.post(name: .progressDeepLink, object: nil)
        case "plans":
            // bibleplus://plans/{planID}
            if let planID = url.pathComponents.dropFirst().first {
                NotificationCenter.default.post(
                    name: .plansDeepLink,
                    object: nil,
                    userInfo: ["planID": planID]
                )
            } else {
                // bibleplus://plans (no specific plan)
                NotificationCenter.default.post(name: .plansDeepLink, object: nil)
            }
        case "bible":
            NotificationCenter.default.post(name: .bibleDeepLink, object: nil)
        case "ask":
            NotificationCenter.default.post(name: .askDeepLink, object: nil)
        case "sanctuary":
            NotificationCenter.default.post(name: .sanctuaryDeepLink, object: nil)
        case "path":
            // bibleplus://path  or  bibleplus://path/{pathID}
            let pathID = url.pathComponents.dropFirst().first
            NotificationCenter.default.post(
                name: .pathDeepLink,
                object: nil,
                userInfo: pathID.map { ["pathID": $0] } ?? [:]
            )
        default:
            break
        }
    }
}

// MARK: - Data Error View

private struct DataErrorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Unable to Load Data")
                .font(.title2.bold())
            Text("Bible Plus couldn't open its database. Please try restarting the app. If the problem persists, reinstalling may help.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
