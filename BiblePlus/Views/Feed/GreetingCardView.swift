import SwiftUI

struct GreetingCardView: View {
    let greeting: String
    var streakText: String? = nil
    let background: SanctuaryBackground
    let isCurrentCard: Bool
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var pulseChevron = false

    var body: some View {
        ZStack {
            // Background (video/image/gradient)
            greetingBackground

            // Gentle vignette
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.15),
                ],
                center: .center,
                startRadius: 200,
                endRadius: 500
            )

            VStack(spacing: 0) {
                Spacer()

                // App title
                HStack(spacing: 0) {
                    Text("Bible")
                        .foregroundStyle(.white)
                    Text("+")
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.9), radius: 20)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.6), radius: 40)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.3), radius: 60)
                }
                .font(.system(size: 32, weight: .bold, design: .serif))
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.6)

                // Streak badge
                if let streakText {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                        Text(streakText)
                            .font(BPFont.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.6)
                    .padding(.top, 12)
                }

                Spacer().frame(height: streakText != nil ? 16 : 28)

                // Greeting text
                Text(greeting)
                    .font(BPFont.prayerLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                Spacer()

                // Swipe hint
                VStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .light))
                        .offset(y: pulseChevron ? -4 : 0)

                    Text("Swipe up to begin")
                        .font(BPFont.caption)
                }
                .foregroundStyle(.white.opacity(0.7))
                .opacity(showContent ? 1 : 0)

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.3)) {
                showContent = true
            }
            withAnimation(
                Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(1.0)
            ) {
                pulseChevron = true
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var greetingBackground: some View {
        GeometryReader { geo in
            ZStack {
                // Base gradient — always visible as fallback
                LinearGradient(
                    colors: background.gradientColors.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if isCurrentCard, let videoName = background.videoFileName {
                    // Only the current card gets a video player
                    LoopingVideoPlayer(videoName: videoName, isPlaying: true)
                } else if let imageName = background.imageName,
                          let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
    }
}
