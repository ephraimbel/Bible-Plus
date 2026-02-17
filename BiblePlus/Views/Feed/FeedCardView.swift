import SwiftUI

struct FeedCardView: View {
    let content: PrayerContent
    let displayText: String
    let background: SanctuaryBackground
    let isCurrentCard: Bool
    let isSaved: Bool
    let showDoubleTapHeart: Bool
    var isAudioPlaying: Bool = false
    var audioVolume: Float = 0.3
    @Binding var immersiveMode: Bool

    // Action callbacks
    var onSave: () -> Void = {}
    var onShare: () -> Void = {}
    var onPin: () -> Void = {}
    var onAskAI: () -> Void = {}
    var onToggleSound: () -> Void = {}
    var onVolumeChange: (Float) -> Void = { _ in }
    var onOpenSanctuary: () -> Void = {}
    var onOpenSoundscapes: () -> Void = {}
    var onOpenBackgrounds: () -> Void = {}
    var onDoubleTap: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @State private var heartVisible = false

    var body: some View {
        ZStack {
            // LAYER 1: Background gradient from user's theme
            backgroundLayer
                .accessibilityHidden(true)

            // LAYER 2: Readability overlay
            overlayLayer
                .accessibilityHidden(true)

            // LAYER 3 + 4: Content + Reference
            contentLayer

            // LAYER 5: Action bar (right side)
            actionBarLayer

            // Double-tap heart overlay
            if heartVisible {
                heartOverlay
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            HapticService.impact(.medium)
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.25)) {
                immersiveMode.toggle()
            }
            HapticService.lightImpact()
        }
        .onChange(of: showDoubleTapHeart) { _, newValue in
            if newValue {
                withAnimation(BPAnimation.spring) {
                    heartVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        heartVisible = false
                    }
                }
            }
        }
    }

    // MARK: - Layer 1: Background

    @ViewBuilder
    private var backgroundLayer: some View {
        // Gradient fills all available space and establishes layout size;
        // image/video is rendered as an overlay so it can't skew the layout.
        LinearGradient(
            colors: background.gradientColors.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            if isCurrentCard, let videoName = background.videoFileName {
                LoopingVideoPlayer(videoName: videoName, isPlaying: true)
            } else if let imageName = background.imageName,
                      let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .clipped()
    }

    // MARK: - Layer 2: Subtle Vignette

    private var overlayLayer: some View {
        ZStack {
            // Thin uniform tint for text legibility
            Color.black.opacity(0.06)

            // Gentle vignette — keeps the background vibrant, just softens the edges
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.1),
                ],
                center: .center,
                startRadius: 200,
                endRadius: 500
            )
        }
    }

    // MARK: - Layer 3 + 4: Content + Reference

    private var contentLayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // Content type badge — hides in immersive mode
            Text(content.type.displayName.uppercased())
                .font(BPFont.caption)
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .padding(.bottom, 16)
                .opacity(immersiveMode ? 0 : 1)

            // Main text — always visible
            mainTextView

            // Verse reference — always visible
            if let reference = content.verseReference, !reference.isEmpty {
                OrnamentalDivider(color: .white, opacity: 0.25)
                    .padding(.vertical, 12)

                Text("— \(reference)")
                    .font(BPFont.reference)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }

            // Category label — hides in immersive mode
            Text(content.category)
                .font(BPFont.caption)
                .foregroundStyle(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                .padding(.top, 8)
                .opacity(immersiveMode ? 0 : 1)

            // Reflection "Ask the AI" button — hides in immersive mode
            if content.type == .reflection {
                GoldButton(title: "Ask the AI") {
                    onAskAI()
                }
                .padding(.horizontal, 60)
                .padding(.top, 24)
                .opacity(immersiveMode ? 0 : 1)
            }

            Spacer(minLength: 16)
        }
        .padding(.top, 49)
        .padding(.bottom, immersiveMode ? 16 : 83)
    }

    // MARK: - Main Text View

    private var mainTextView: some View {
        Text(displayText)
            .font(contentFont)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(displayText.count > 250 ? 5 : 6)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, contentHorizontalPadding)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }

    /// Adapt font size based on text length (5 tiers)
    private var contentFont: Font {
        if displayText.count > 350 {
            return BPFont.prayerTiny
        } else if displayText.count > 250 {
            return BPFont.prayerXSmall
        } else if displayText.count > 120 {
            return BPFont.prayerMedium
        } else {
            return BPFont.prayerLarge
        }
    }

    /// Tighter horizontal padding for long text so more words fit per line
    private var contentHorizontalPadding: CGFloat {
        displayText.count > 200 ? 36 : 48
    }

    // MARK: - Layer 5: Action Bar

    private var actionBarLayer: some View {
        HStack {
            Spacer()
            ActionBarView(
                isSaved: isSaved,
                isAudioPlaying: isAudioPlaying,
                volume: audioVolume,
                onSave: onSave,
                onShare: onShare,
                onPin: onPin,
                onAskAI: onAskAI,
                onToggleSound: onToggleSound,
                onVolumeChange: onVolumeChange,
                onOpenSanctuary: onOpenSanctuary,
                onOpenSoundscapes: onOpenSoundscapes,
                onOpenBackgrounds: onOpenBackgrounds
            )
            .padding(.trailing, 12)
        }
        .opacity(immersiveMode ? 0 : 1)
        .allowsHitTesting(!immersiveMode)
    }

    // MARK: - Double-Tap Heart Overlay

    private var heartOverlay: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80))
            .foregroundStyle(palette.accent)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(heartVisible ? 1.0 : 0.3)
            .opacity(heartVisible ? 1.0 : 0)
    }
}
