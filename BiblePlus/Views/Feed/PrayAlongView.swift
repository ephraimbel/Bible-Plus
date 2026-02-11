import SwiftUI

struct PrayAlongView: View {
    let displayText: String
    let verseReference: String?
    let background: SanctuaryBackground
    let soundscapeService: SoundscapeService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var showControls = false

    var body: some View {
        ZStack {
            // Layer 1: Background
            backgroundLayer

            // Layer 2: Vignette — deeper than feed cards for focused reading
            RadialGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.55),
                ],
                center: .center,
                startRadius: 120,
                endRadius: 500
            )

            // Layer 3: Content
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 12)

                // Prayer body
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 24)

                        // Prayer hands icon
                        Image(systemName: "hands.sparkles")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(palette.accent)
                            .opacity(showContent ? 1 : 0)
                            .scaleEffect(showContent ? 1 : 0.5)
                            .animation(BPAnimation.spring.delay(0.15), value: showContent)

                        // Prayer text — one flowing block
                        Text(displayText)
                            .font(prayerFont)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .padding(.horizontal, 32)
                            .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
                            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                            .shadow(color: .black.opacity(0.3), radius: 14, y: 0)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 12)
                            .animation(BPAnimation.spring.delay(0.25), value: showContent)

                        // Verse reference
                        if let ref = verseReference, !ref.isEmpty {
                            Text("— \(ref)")
                                .font(BPFont.reference)
                                .foregroundStyle(.white.opacity(0.6))
                                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                                .padding(.top, 8)
                                .opacity(showContent ? 1 : 0)
                                .animation(BPAnimation.spring.delay(0.35), value: showContent)
                        }

                        Spacer().frame(height: 32)
                    }
                }
                .mask(scrollFadeMask)

                // Bottom controls
                bottomBar
                    .padding(.bottom, 44)
                    .opacity(showControls ? 1 : 0)
                    .offset(y: showControls ? 0 : 16)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.1)) {
                showContent = true
            }
            withAnimation(BPAnimation.spring.delay(0.5)) {
                showControls = true
            }
        }
    }

    // MARK: - Prayer Font

    private var prayerFont: Font {
        if displayText.count > 700 {
            return BPFont.prayerSmall
        } else {
            return BPFont.prayerMedium
        }
    }

    // MARK: - Scroll Fade Mask

    private var scrollFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: background.gradientColors.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let videoName = background.videoFileName {
                LoopingVideoPlayer(videoName: videoName)
            } else if let imageName = background.imageName,
                      let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Center label
            Text("GUIDED PRAYER")
                .font(BPFont.caption)
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.6))

            // Dismiss button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial.opacity(0.5))
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 18) {
            audioToggle

            GoldButton(title: "Amen", showGlow: true) {
                dismiss()
            }
            .frame(maxWidth: 220)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Audio Toggle

    private var audioToggle: some View {
        Button {
            withAnimation(BPAnimation.selection) {
                soundscapeService.togglePlayback()
            }
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: soundscapeService.isPlaying
                      ? "speaker.wave.2.fill"
                      : "speaker.slash")
                    .font(.system(size: 13, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))

                Text(soundscapeService.isPlaying
                     ? soundscapeService.currentSoundscape.displayName
                     : "Play Music")
                    .font(BPFont.caption)
            }
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
        }
    }
}
