import SwiftUI

struct WelcomeView: View {
    let viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            // Shimmering sea video background
            LoopingVideoPlayer(videoName: "water-ripples")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + Title
                VStack(spacing: 16) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)

                    Text("Bible+")
                        .font(BPFont.headingLarge)
                        .foregroundStyle(.white)

                    Text("Your personal companion for\nprayer, scripture, and peace.")
                        .font(BPFont.onboardingSubtitle)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                .scaleEffect(showContent ? 1 : 0.95)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                Spacer()

                // Begin button
                VStack(spacing: 16) {
                    GoldButton(
                        title: "Begin Your Journey",
                        showGlow: true,
                        action: { viewModel.goNext() }
                    )

                    Text("This takes about 2 minutes and helps us\npersonalize everything for you.")
                        .font(BPFont.reference)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            // Start ambient music
            viewModel.audioService.playResource("heavenlyWorship")

            // Staggered entrance animations
            withAnimation(BPAnimation.spring.delay(0.3)) {
                showContent = true
            }
            withAnimation(BPAnimation.spring.delay(0.8)) {
                showButton = true
            }
        }
    }
}
