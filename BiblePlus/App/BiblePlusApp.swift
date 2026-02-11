import SwiftUI
import SwiftData

@main
struct BiblePlusApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try SharedModelContainer.create()

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
    @State private var deepLinkedContentID: UUID?

    private var currentProfile: UserProfile? { profiles.first }
    private var hasCompletedOnboarding: Bool {
        currentProfile?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView(deepLinkedContentID: $deepLinkedContentID)
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
