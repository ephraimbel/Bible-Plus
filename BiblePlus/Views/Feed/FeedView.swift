import SwiftUI
import SwiftData
import Combine

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
    @State private var scrollPosition: Int? = 0
    @State private var showSanctuary = false
    @State private var prayAlongContent: PrayerContent? = nil

    var body: some View {
        ZStack {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Index 0: Greeting card
                GreetingCardView(
                    greeting: vm.greeting,
                    streakText: vm.streakText,
                    background: vm.currentBackground,
                    isCurrentCard: scrollPosition == 0
                )
                .containerRelativeFrame(.vertical)
                .id(0)

                // Index 1+: Content cards
                ForEach(Array(vm.cards.enumerated()), id: \.element.id) { index, content in
                    FeedCardView(
                        content: content,
                        displayText: vm.personalizedText(for: content),
                        background: vm.currentBackground,
                        isCurrentCard: scrollPosition == index + 1,
                        isSaved: vm.isSaved(content),
                        showDoubleTapHeart: vm.doubleTapHeartID == content.id,
                        isAudioPlaying: soundscapeService.isPlaying,
                        audioVolume: soundscapeService.volume,
                        onSave: { vm.toggleSave(for: content) },
                        onShare: { vm.shareCard(content) },
                        onPin: { vm.pinToCollection(content) },
                        onAskAI: { vm.askAI(about: content) },
                        onToggleSound: { soundscapeService.togglePlayback() },
                        onVolumeChange: { soundscapeService.setVolume($0) },
                        onOpenSanctuary: { showSanctuary = true },
                        onPrayAlong: { prayAlongContent = content },
                        onDoubleTap: { vm.doubleTapSave(for: content) }
                    )
                    .containerRelativeFrame(.vertical)
                    .id(index + 1)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .onChange(of: scrollPosition) { _, newValue in
            if let idx = newValue {
                vm.onSwipe(to: idx)
            }
        }
        .ignoresSafeArea()
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
        .fullScreenCover(item: $prayAlongContent) { content in
            PrayAlongView(
                displayText: vm.personalizedText(for: content),
                background: vm.currentBackground
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: SettingsViewModel.personalizationDidChange)) { _ in
            scrollPosition = 0
            vm.refreshFeed()
        }

        // Streak celebration overlay
        if vm.showStreakCelebration {
            StreakCelebrationView(
                streakCount: vm.streakCount,
                milestone: vm.streakMilestone,
                onDismiss: { vm.dismissStreakCelebration() }
            )
            .transition(.opacity)
            .zIndex(100)
        }
        } // ZStack
    }
}
