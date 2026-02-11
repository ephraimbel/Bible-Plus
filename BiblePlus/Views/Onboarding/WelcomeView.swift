import SwiftUI

struct WelcomeView: View {
    let viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            SunriseBackground()

            VStack(spacing: 0) {
                Spacer()

                // App icon / cross symbol
                Image(systemName: "book.pages")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(palette.accent)
                    .scaleEffect(showContent ? 1 : 0.6)
                    .opacity(showContent ? 1 : 0)

                Spacer().frame(height: 32)

                // Title
                VStack(spacing: 14) {
                    Text("Bible+")
                        .font(BPFont.headingLarge)
                        .foregroundStyle(palette.textPrimary)

                    Text("Your personal companion for\nprayer, scripture, and peace.")
                        .font(BPFont.onboardingSubtitle)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
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
                        .foregroundStyle(palette.textMuted)
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
            viewModel.audioService.playResource("ambient-piano")

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
