import SwiftUI
import SwiftData
import UserNotifications

@main
struct BiblePlusApp: App {
    let modelContainer: ModelContainer
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        do {
            modelContainer = try SharedModelContainer.create()

            // Seed content on first launch and migrate legacy messages
            let seedContext = ModelContext(modelContainer)
            ContentSeeder.seedIfNeeded(modelContext: seedContext)
            ContentSeeder.migrateOrphanedMessages(modelContext: seedContext)

            // DEBUG: Unlock Pro for testing — remove before release
            let profileFetch = FetchDescriptor<UserProfile>()
            if let profile = try? seedContext.fetch(profileFetch).first {
                profile.isPro = true
                try? seedContext.save()
            }

            // Refresh notification content on each launch
            if let profile = try? seedContext.fetch(profileFetch).first,
               profile.hasCompletedOnboarding,
               !profile.prayerTimes.isEmpty {
                let contentFetch = FetchDescriptor<PrayerContent>()
                let allContent = (try? seedContext.fetch(contentFetch)) ?? []
                let prayerTimes = profile.prayerTimes
                let firstName = profile.firstName
                let burdens = profile.currentBurdens
                let seasons = profile.lifeSeasons
                let faithLevel = profile.faithLevel
                let isPro = profile.isPro
                Task { @MainActor in
                    // Build a lightweight profile snapshot for scheduling
                    await NotificationService.shared.rescheduleFromSnapshot(
                        prayerTimes: prayerTimes,
                        firstName: firstName,
                        burdens: burdens,
                        seasons: seasons,
                        faithLevel: faithLevel,
                        isPro: isPro,
                        content: allContent
                    )
                }
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
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
        return true
    }

    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle notification tap — deep link to content
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["contentID"] as? String,
           let uuid = UUID(uuidString: idString) {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .notificationDeepLink,
                    object: nil,
                    userInfo: ["contentID": uuid]
                )
            }
        }
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.colorScheme) private var systemScheme
    @State private var deepLinkedContentID: UUID?

    private var currentProfile: UserProfile? { profiles.first }
    private var hasCompletedOnboarding: Bool {
        currentProfile?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView(deepLinkedContentID: $deepLinkedContentID)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity
                    ))
            } else {
                OnboardingContainerView()
                    .transition(.opacity)
            }
        }
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
        // bibleplus://content/{uuid}
        guard url.scheme == "bibleplus",
              url.host == "content",
              let idString = url.pathComponents.dropFirst().first,
              let uuid = UUID(uuidString: idString)
        else { return }
        deepLinkedContentID = uuid
    }
}
