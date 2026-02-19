import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SoundscapeService.self) private var soundscapeService
    @State private var viewModel: FeedViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                FeedContentView(vm: vm, soundscapeService: soundscapeService)
            } else {
                BPLoadingView().onAppear { initializeViewModel() }
            }
        }
    }

    private func initializeViewModel() {
        viewModel = FeedViewModel(modelContext: modelContext)
    }
}

// MARK: - Inner Content View

private struct FeedContentView: View {
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
            if !vm.showFeed {
                HomeDashboardView(
                    vm: vm,
                    soundscapeService: soundscapeService,
                    onEnterFeed: {
                        withAnimation(.easeInOut(duration: 0.3)) { vm.showFeed = true }
                        HapticService.lightImpact()
                    },
                    onShowProgress: { showProgress = true },
                    onDailyVerseTap: { deepLinkDailyVerse() },
                    onContinueReading: { deepLinkContinueReading() },
                    onOpenSanctuary: { showSanctuary = true }
                )
                .transition(.opacity)
            } else {
                FeedPagingView(
                    vm: vm,
                    soundscapeService: soundscapeService,
                    onReturnHome: {
                        withAnimation(.easeInOut(duration: 0.3)) { vm.showFeed = false }
                        HapticService.lightImpact()
                    },
                    onShowSanctuary: { showSanctuary = true },
                    onShowSoundscapePicker: { openSoundscapePicker() },
                    onShowBackgroundPicker: { openBackgroundPicker() }
                )
                .transition(.opacity)
            }

            // Streak celebration overlay (above both views)
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
            vm.showFeed = false
            vm.refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .enterFeedFromDashboard)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { vm.showFeed = true }
            HapticService.lightImpact()
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedContentDeepLink)) { notification in
            if let contentID = notification.userInfo?["contentID"] as? UUID {
                vm.navigateToContent(id: contentID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProgressFromWidget)) { _ in
            vm.showFeed = false
            showProgress = true
        }
        .onChange(of: vm.showFeed) { _, showFeed in
            NotificationCenter.default.post(
                name: .dashboardShowFeedChanged,
                object: nil,
                userInfo: ["showFeed": showFeed]
            )
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

    private func openSoundscapePicker() {
        _ = getOrCreateSanctuaryVM()
        showSoundscapePicker = true
    }

    private func openBackgroundPicker() {
        _ = getOrCreateSanctuaryVM()
        showBackgroundPicker = true
    }

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

    private func deepLinkContinueReading() {
        let bookName = vm.continueReading?.bookName ?? "Genesis"
        let chapter = vm.continueReading?.chapter ?? 1
        NotificationCenter.default.post(
            name: .scriptureDeepLink,
            object: nil,
            userInfo: ["bookName": bookName, "chapter": chapter]
        )
    }
}
