import SwiftUI

// MARK: - WelcomeView (Lifesum-style)
//
// Full-bleed real photograph, brand wordmark at the top, a large serif promise
// and primary CTA pinned to the bottom over a soft scrim. Clean and confident —
// it should feel like a real, premium app, not a splash animation.
struct WelcomeView: View {
    let viewModel: OnboardingViewModel

    @State private var showWordmark = false
    @State private var showHeadline = false
    @State private var showCTA = false
    @State private var imageScale: CGFloat = 1.0
    @State private var contentOpacity: Double = 1.0
    @State private var isLeaving = false

    private let accentGold = Color(red: 0.82, green: 0.65, blue: 0.35)
    private let warmCream = Color(red: 1.0, green: 0.97, blue: 0.92)
    private let deepSepia = Color(red: 0.14, green: 0.10, blue: 0.06)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                deepSepia.ignoresSafeArea()

                // Full-bleed photograph with a very slow Ken Burns drift.
                Image("WelcomeFriends")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(imageScale)
                    .clipped()
                    .ignoresSafeArea()

                // Legibility scrims: a touch at the top for the wordmark, a
                // deeper one at the bottom for the headline + CTA.
                LinearGradient(
                    stops: [
                        .init(color: deepSepia.opacity(0.45), location: 0.0),
                        .init(color: .clear, location: 0.22),
                        .init(color: .clear, location: 0.45),
                        .init(color: deepSepia.opacity(0.55), location: 0.72),
                        .init(color: deepSepia.opacity(0.92), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                wordmark
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, geo.safeAreaInsets.top > 0 ? 8 : 24)

                bottomContent
            }
            .opacity(contentOpacity)
        }
        .ignoresSafeArea()
        .onAppear(perform: animateIn)
    }

    // MARK: Wordmark

    private var wordmark: some View {
        HStack(spacing: 6) {
            Text("Bible")
                .font(.custom("Baskerville", size: 26))
                .foregroundStyle(warmCream)
            Image(systemName: "sparkle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentGold)
        }
        .shadow(color: deepSepia.opacity(0.5), radius: 8, y: 1)
        .opacity(showWordmark ? 1 : 0)
        .offset(y: showWordmark ? 0 : -8)
    }

    // MARK: Bottom content

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Grow closer\nto God.")
                    .font(.custom("Baskerville", size: 44))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .shadow(color: deepSepia.opacity(0.5), radius: 12, y: 2)

                Text("Scripture, prayer, and a daily walk with Christ.")
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(warmCream.opacity(0.9))
                    .shadow(color: deepSepia.opacity(0.6), radius: 8, y: 1)
            }
            .opacity(showHeadline ? 1 : 0)
            .offset(y: showHeadline ? 0 : 14)

            Button(action: begin) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accentGold)
                    )
                    .shadow(color: accentGold.opacity(0.35), radius: 16, y: 6)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isLeaving)
            .opacity(showCTA ? 1 : 0)
            .offset(y: showCTA ? 0 : 16)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func animateIn() {
        viewModel.audioService.playResource("heavenlyWorship", ext: "m4a")

        withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
            imageScale = 1.07
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) { showWordmark = true }
        withAnimation(.easeOut(duration: 0.9).delay(0.45)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.8).delay(0.75)) { showCTA = true }
    }

    private func begin() {
        guard !isLeaving else { return }
        isLeaving = true
        HapticService.impact(.light)
        withAnimation(.easeInOut(duration: 0.4)) { contentOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            viewModel.goNext()
        }
    }
}
