import SwiftUI

struct FeedCardView: View {
    let content: PrayerContent
    let displayText: String
    let theme: ThemeDefinition
    let isSaved: Bool
    let showDoubleTapHeart: Bool
    var isAudioPlaying: Bool = false

    // Action callbacks
    var onSave: () -> Void = {}
    var onShare: () -> Void = {}
    var onPin: () -> Void = {}
    var onAskAI: () -> Void = {}
    var onToggleSound: () -> Void = {}
    var onOpenSanctuary: () -> Void = {}
    var onDoubleTap: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @State private var heartVisible = false
    @State private var showComingSoon = false

    var body: some View {
        ZStack {
            // LAYER 1: Background gradient from user's theme
            backgroundLayer

            // LAYER 2: Readability overlay
            overlayLayer

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
            onDoubleTap()
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

    private var backgroundLayer: some View {
        LinearGradient(
            colors: theme.previewGradient.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Layer 2: Readability Overlay

    private var overlayLayer: some View {
        VStack(spacing: 0) {
            // Top fade
            LinearGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)

            Spacer()

            // Bottom fade for text readability — tall and strong
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.50),
                    Color.black.opacity(0.65),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 500)
        }
    }

    // MARK: - Layer 3 + 4: Content + Reference

    private var contentLayer: some View {
        VStack(spacing: 0) {
            Spacer()

            // Content type badge
            Text(content.type.displayName.uppercased())
                .font(BPFont.caption)
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .padding(.bottom, 16)

            // Main text
            Text(displayText)
                .font(contentFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 48)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 0)

            // Verse reference
            if let reference = content.verseReference, !reference.isEmpty {
                Text("— \(reference)")
                    .font(BPFont.reference)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(.top, 16)
            }

            // Category label
            Text(content.category)
                .font(BPFont.caption)
                .foregroundStyle(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                .padding(.top, 8)

            // Guided prayer "Pray Along" button
            if content.type == .guidedPrayer {
                GoldButton(title: "Pray Along", showGlow: true) {
                    showComingSoon = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showComingSoon = false
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 24)
            }

            if showComingSoon {
                Text("Coming soon")
                    .font(BPFont.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 8)
                    .transition(.opacity)
            }

            // Reflection "Ask the AI" button
            if content.type == .reflection {
                GoldButton(title: "Ask the AI") {
                    onAskAI()
                }
                .padding(.horizontal, 60)
                .padding(.top, 24)
            }

            Spacer()
        }
        // Offset down to account for tab bar covering the bottom
        .padding(.top, 49)
    }

    /// Adapt font size based on text length
    private var contentFont: Font {
        if displayText.count > 250 {
            return BPFont.prayerSmall
        } else if displayText.count > 120 {
            return BPFont.prayerMedium
        } else {
            return BPFont.prayerLarge
        }
    }

    // MARK: - Layer 5: Action Bar

    private var actionBarLayer: some View {
        HStack {
            Spacer()
            ActionBarView(
                isSaved: isSaved,
                isAudioPlaying: isAudioPlaying,
                onSave: onSave,
                onShare: onShare,
                onPin: onPin,
                onAskAI: onAskAI,
                onToggleSound: onToggleSound,
                onOpenSanctuary: onOpenSanctuary
            )
            .padding(.trailing, 12)
        }
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
