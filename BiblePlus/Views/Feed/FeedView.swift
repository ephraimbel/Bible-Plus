import SwiftUI
import SwiftData

// MARK: - FeedView (now a thin home wrapper)
//
// The Feed itself is shelved for this release — the app is chat-first.
// This view persists as the loader that creates `FeedViewModel` (still
// the source of streak, daily verse, current background, etc.) and
// hosts the sheets/covers that hang off the home dashboard.
//
// FeedPagingView is preserved in the repo but no longer routed to.
struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SoundscapeService.self) private var soundscapeService
    @State private var viewModel: FeedViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                HomeContentView(vm: vm, soundscapeService: soundscapeService)
            } else {
                BPLoadingView().onAppear { initializeViewModel() }
            }
        }
    }

    private func initializeViewModel() {
        viewModel = FeedViewModel(modelContext: modelContext)
    }
}

// MARK: - Home Content View
//
// Hosts HomeDashboardView and all the sheets/covers it can present:
// share preview, collection picker, sanctuary, soundscape picker,
// background picker, progress sheet, and the streak celebration
// overlay. Lives here so home stays focused on layout while ambient
// presentation lives at the container level.
private struct HomeContentView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService
    @Environment(\.modelContext) private var modelContext

    @State private var showSanctuary = false
    @State private var showSoundscapePicker = false
    @State private var showBackgroundPicker = false
    @State private var sanctuaryVM: SanctuaryViewModel?
    @State private var showProgress = false

    var body: some View {
        ZStack {
            HomeDashboardView(
                vm: vm,
                soundscapeService: soundscapeService,
                onEnterFeed: { /* feed shelved — no-op */ },
                onShowProgress: { showProgress = true },
                onDailyVerseTap: { deepLinkDailyVerse() },
                onContinueReading: { deepLinkContinueReading() },
                onOpenSanctuary: { showSanctuary = true }
            )

            // Streak celebration overlay (above home content)
            if vm.showStreakCelebration {
                StreakCelebrationView(
                    streakCount: vm.streakCount,
                    milestone: vm.streakMilestone,
                    onDismiss: { vm.dismissStreakCelebration() }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .sheet(item: $vm.shareContent) { content in
            SharePreviewSheet(
                content: content,
                displayText: vm.personalizedText(for: content),
                background: vm.currentBackground
            )
        }
        .sheet(item: $vm.collectionContent) { content in
            CollectionPickerSheet(
                content: content,
                isPro: vm.profile.isPro
            )
        }
        .sheet(item: $vm.askAIContent) { content in
            NavigationStack {
                ChatView(
                    conversationId: vm.askAIConversationId,
                    initialContext: vm.askAIPrompt(for: content)
                )
            }
        }
        .fullScreenCover(isPresented: $showSanctuary) {
            SanctuaryView(soundscapeService: soundscapeService)
        }
        .sheet(isPresented: $showSoundscapePicker) {
            SoundscapePickerView(vm: getOrCreateSanctuaryVM())
        }
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPickerView(vm: getOrCreateSanctuaryVM())
        }
        .sheet(isPresented: $showProgress) {
            MyProgressView()
        }
        .onReceive(NotificationCenter.default.publisher(for: SettingsViewModel.personalizationDidChange)) { _ in
            vm.refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProgressFromWidget)) { _ in
            showProgress = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSanctuaryFromWidget)) { _ in
            showSanctuary = true
        }
    }

    // MARK: - Helpers

    private func getOrCreateSanctuaryVM() -> SanctuaryViewModel {
        if let existing = sanctuaryVM { return existing }
        let personalization = PersonalizationService(modelContext: modelContext)
        let newVM = SanctuaryViewModel(soundscapeService: soundscapeService, personalizationService: personalization)
        sanctuaryVM = newVM
        return newVM
    }

    /// Open the Bible reader at the user's last-read position (or Genesis 1
    /// if they haven't read yet). Drives the home "Continue" action card.
    private func deepLinkContinueReading() {
        let bookName = vm.continueReading?.bookName ?? "Genesis"
        let chapter = vm.continueReading?.chapter ?? 1
        NotificationCenter.default.post(
            name: .scriptureDeepLink,
            object: nil,
            userInfo: ["bookName": bookName, "chapter": chapter]
        )
    }

    /// Parse the daily verse reference into a scripture deep-link payload
    /// so tapping the home hero card opens the Bible reader at the right
    /// chapter/verse.
    private func deepLinkDailyVerse() {
        guard let verse = vm.dailyVerse else { return }
        let ref = verse.reference
        if let colonIndex = ref.lastIndex(of: ":") {
            let beforeColon = ref[ref.startIndex..<colonIndex]
            let afterColon = String(ref[ref.index(after: colonIndex)...])
            let verseNum = Int(afterColon.trimmingCharacters(in: .whitespaces)) ?? 0
            if let spaceIndex = beforeColon.lastIndex(of: " ") {
                let bookName = String(beforeColon[beforeColon.startIndex..<spaceIndex])
                let chapterStr = String(beforeColon[beforeColon.index(after: spaceIndex)...])
                if let chapter = Int(chapterStr) {
                    NotificationCenter.default.post(
                        name: .scriptureDeepLink,
                        object: nil,
                        userInfo: ["bookName": bookName, "chapter": chapter, "verse": verseNum]
                    )
                }
            }
        }
    }
}
