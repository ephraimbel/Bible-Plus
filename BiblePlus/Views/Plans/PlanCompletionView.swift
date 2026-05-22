import SwiftUI

struct PlanCompletionView: View {
    let planName: String
    /// Plan-specific gradient hex values for the trophy + glow. When empty,
    /// the celebration falls back to the app accent.
    var gradientHex: [String] = []
    /// Plan artwork key used as a dimmed radial backdrop so finishing a plan
    /// visually references the journey the user just completed. Optional.
    var imageKey: String = ""
    let onDismiss: () -> Void

    @Environment(\.bpPalette) private var palette
    @State private var showIcon = false
    @State private var showText = false
    @State private var showButton = false
    @State private var glowOpacity: Double = 0.3
    @State private var outerRingScale: CGFloat = 0.9

    /// Plan tint — leads the trophy, ring strokes, and card eyebrow. Falls
    /// back to the palette accent when no gradient was provided, so legacy
    /// callers still render correctly.
    private var planTint: Color {
        gradientHex.first.map(Color.init(hex:)) ?? palette.accent
    }

    private var planTintSecondary: Color {
        gradientHex.dropFirst().first.map(Color.init(hex:)) ?? planTint.opacity(0.82)
    }

    private var planArt: UIImage? {
        guard !imageKey.isEmpty else { return nil }
        return BiblicalImageService.rawImage(for: imageKey)
    }

    var body: some View {
        ZStack {
            // Plan-specific ambient backdrop. The artwork sits behind the
            // dimming layer — heavily blurred and low-opacity so it reads as
            // mood, not content. Falls back to a pure dim when no art exists.
            if let art = planArt {
                Image(uiImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60, opaque: true)
                    .opacity(0.55)
                    .ignoresSafeArea()
            }

            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Subtle plan-tint radial wash behind the trophy so the whole
            // overlay picks up the plan's palette, not just the medallion.
            RadialGradient(
                colors: [planTint.opacity(0.28), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 28) {
                trophyMedallion

                cardContent

                if showButton {
                    GoldButton(title: "Continue", showGlow: true) {
                        HapticService.lightImpact()
                        onDismiss()
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear(perform: runEntrance)
    }

    // MARK: - Trophy Medallion

    /// Layered glow rings + trophy. Outer ring breathes; inner glow pulses
    /// around the trophy to read as light, not just color.
    private var trophyMedallion: some View {
        ZStack {
            Circle()
                .stroke(planTint.opacity(0.10), lineWidth: 1)
                .frame(width: 160, height: 160)
                .scaleEffect(outerRingScale)

            Circle()
                .stroke(planTint.opacity(0.14), lineWidth: 1)
                .frame(width: 140, height: 140)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            planTint.opacity(0.22),
                            planTint.opacity(0.05),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)

            // Trophy keeps the gold accent so "completion" still reads as
            // universal success (gold = trophy), while the surrounding rings,
            // glow, and ambient wash carry the plan's palette.
            Image(systemName: "trophy.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: planTint.opacity(glowOpacity), radius: 24)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        }
        .scaleEffect(showIcon ? 1 : 0.3)
        .opacity(showIcon ? 1 : 0)
    }

    // MARK: - Card

    private var cardContent: some View {
        VStack(spacing: 14) {
            // Eyebrow uses the plan's own tint but mixed with warm white so
            // mid-tone plan gradients (deep greens, browns) still read as
            // luminous against the dark glass card.
            Text("PLAN COMPLETE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [planTint, planTintSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .brightness(0.15)

            Text("You finished")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Text(planName)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 16)

            Rectangle()
                .fill(planTint.opacity(0.55))
                .frame(width: 40, height: 0.5)
                .padding(.top, 2)

            Text("Your faithfulness in God's Word\nis building something beautiful.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [planTint.opacity(0.40), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .opacity(showText ? 1 : 0)
        .offset(y: showText ? 0 : 20)
    }

    // MARK: - Entrance

    private func runEntrance() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.1)) {
            showIcon = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            HapticService.success()
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.42)) {
            showText = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.85)) {
            showButton = true
        }
        withAnimation(BPAnimation.glowPulse) {
            glowOpacity = 0.85
        }
        withAnimation(
            .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
        ) {
            outerRingScale = 1.04
        }
    }
}
