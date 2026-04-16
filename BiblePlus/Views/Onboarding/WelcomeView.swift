import SwiftUI

struct WelcomeView: View {
    let viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showLogo = false
    @State private var showButton = false
    @State private var imageScale: CGFloat = 1.05
    @State private var glowIntensity: Double = 0

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.3)
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // LAYER 1: Biblical art — fills entire screen
                Image("biblical_jacob_ladder")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(imageScale)
                    .clipped()
                    .ignoresSafeArea()

                // LAYER 2: Warm sepia tint
                Color(red: 0.22, green: 0.16, blue: 0.08)
                    .opacity(0.2)
                    .ignoresSafeArea()

                // LAYER 3: Center radial darkening for text legibility
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.08)
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: geo.size.width * 0.9
                )
                .ignoresSafeArea()

                // LAYER 4: Bottom gradient for button
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.32)
                }
                .ignoresSafeArea()

                // LAYER 5: Content
                VStack(spacing: 0) {
                    Spacer()

                    // Logo + tagline — centered
                    VStack(spacing: 18) {
                        // "Bible" + golden sparkle
                        HStack(spacing: 4) {
                            Text("Bible")
                                .font(.custom("Baskerville-Bold", size: 54))
                                .foregroundStyle(.white)

                            Image(systemName: "sparkle")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.92, blue: 0.55),
                                            gold,
                                            accentGold
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: gold, radius: 6)
                                .shadow(color: gold.opacity(glowIntensity), radius: 14)
                                .shadow(color: gold.opacity(glowIntensity * 0.6), radius: 30)
                                .shadow(color: gold.opacity(glowIntensity * 0.3), radius: 50)
                        }
                        .shadow(color: .black.opacity(0.6), radius: 16, y: 4)

                        // Gold rule
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [accentGold.opacity(0.2), accentGold, accentGold.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 48, height: 1.5)

                        // Tagline
                        Text("Your personal companion for\nprayer, scripture, and peace.")
                            .font(.custom("Georgia", size: 16))
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                    }
                    .scaleEffect(showLogo ? 1 : 0.92)
                    .opacity(showLogo ? 1 : 0)

                    Spacer()

                    // Button — frosted glass with gold accent
                    Button {
                        HapticService.impact(.light)
                        viewModel.goNext()
                    } label: {
                        Text("Begin Your Journey")
                            .font(.custom("Georgia-Bold", size: 17))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial.opacity(0.5))
                            )
                            .background(
                                Capsule()
                                    .fill(accentGold.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                accentGold.opacity(0.6),
                                                .white.opacity(0.25),
                                                accentGold.opacity(0.6)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: accentGold.opacity(0.25), radius: 12, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 40)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)

                    Spacer().frame(height: 56)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.audioService.playResource("heavenlyWorship", ext: "m4a")

            // Slow Ken Burns zoom
            withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
                imageScale = 1.12
            }

            // Logo fade in
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                showLogo = true
            }

            // Sparkle glow bloom
            withAnimation(.easeInOut(duration: 1.2).delay(0.8)) {
                glowIntensity = 1.0
            }

            // Gentle glow pulse after initial bloom
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.5
                }
            }

            // Button entrance
            withAnimation(.easeOut(duration: 0.8).delay(1.2)) {
                showButton = true
            }
        }
    }
}
