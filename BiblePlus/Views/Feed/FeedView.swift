import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: FeedViewModel?
    @State private var audioService = AudioService()

    var body: some View {
        Group {
            if let vm = viewModel {
                FeedContentView(vm: vm, audioService: audioService)
            } else {
                Color.clear.onAppear { initializeViewModel() }
            }
        }
    }

    private func initializeViewModel() {
        viewModel = FeedViewModel(
            modelContext: modelContext,
            audioService: audioService
        )
    }
}

// MARK: - Inner Content View

private struct FeedContentView: View {
    @Bindable var vm: FeedViewModel
    let audioService: AudioService
    @State private var scrollPosition: Int? = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Index 0: Greeting card
                GreetingCardView(
                    greeting: vm.greeting,
                    theme: vm.currentTheme
                )
                .containerRelativeFrame(.vertical)
                .id(0)

                // Index 1+: Content cards
                ForEach(Array(vm.cards.enumerated()), id: \.element.id) { index, content in
                    FeedCardView(
                        content: content,
                        displayText: vm.personalizedText(for: content),
                        theme: vm.currentTheme,
                        isSaved: vm.isSaved(content),
                        showDoubleTapHeart: vm.doubleTapHeartID == content.id,
                        onSave: { vm.toggleSave(for: content) },
                        onShare: { vm.shareCard(content) },
                        onPin: { vm.pinToCollection(content) },
                        onAskAI: { /* Phase 5 */ },
                        onToggleSound: { audioService.togglePlayback() },
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
                theme: vm.currentTheme
            )
        }
        .sheet(item: $vm.collectionContent) { content in
            CollectionPickerSheet(
                content: content,
                isPro: vm.profile.isPro
            )
        }
    }
}
