import SwiftUI

struct GreetingCardView: View {
    let greeting: String
    let theme: ThemeDefinition
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var pulseChevron = false

    var body: some View {
        ZStack {
            // Background from theme
            LinearGradient(
                colors: theme.previewGradient.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle overlay for readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.2),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                // Flame icon
                Image(systemName: "flame")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(palette.accent)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.6)

                Spacer().frame(height: 28)

                // Greeting text
                Text(greeting)
                    .font(BPFont.prayerLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
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
                .foregroundStyle(.white.opacity(0.5))
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
}
