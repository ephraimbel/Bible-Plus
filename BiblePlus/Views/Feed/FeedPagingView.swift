import SwiftUI

struct FeedPagingView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService
    let onReturnHome: () -> Void
    let onShowSettings: () -> Void
    let onShowSanctuary: () -> Void
    let onShowSoundscapePicker: () -> Void
    let onShowBackgroundPicker: () -> Void
    let onPrayAlong: (PrayerContent) -> Void

    @State private var scrollPosition: Int? = 0

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.cards.enumerated()), id: \.element.id) { index, content in
                        FeedCardView(
                            content: content,
                            displayText: vm.personalizedText(for: content),
                            background: vm.currentBackground,
                            isCurrentCard: scrollPosition == index,
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
                            onOpenSanctuary: { onShowSanctuary() },
                            onOpenSoundscapes: { onShowSoundscapePicker() },
                            onOpenBackgrounds: { onShowBackgroundPicker() },
                            onPrayAlong: { onPrayAlong(content) },
                            onDoubleTap: { vm.doubleTapSave(for: content) }
                        )
                        .containerRelativeFrame(.vertical)
                        .id(index)
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

            // Top bar: Home (left) + Settings (right) — always visible in feed
            VStack {
                HStack {
                    Button {
                        onReturnHome()
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    }

                    Spacer()

                    Button {
                        onShowSettings()
                        HapticService.lightImpact()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
            }
            .zIndex(50)
        }
    }
}
