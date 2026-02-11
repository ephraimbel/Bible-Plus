import SwiftUI
import SwiftData

@main
struct BiblePlusApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                PrayerContent.self,
                ContentCollection.self,
            ])
            let config = ModelConfiguration(
                "BiblePlus",
                schema: schema,
                groupContainer: .identifier("group.com.bibleplus.shared")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])

            // Seed content on first launch
            let seedContext = ModelContext(modelContainer)
            ContentSeeder.seedIfNeeded(modelContext: seedContext)
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

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.colorScheme) private var systemScheme

    private var currentProfile: UserProfile? { profiles.first }
    private var hasCompletedOnboarding: Bool {
        currentProfile?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingContainerView()
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
    }

    private var resolvedColorScheme: ColorScheme? {
        guard let mode = currentProfile?.colorMode else { return nil }
        switch mode {
        case .light: return .light
        case .dark, .immersive: return .dark
        case .auto: return nil
        }
    }
}
