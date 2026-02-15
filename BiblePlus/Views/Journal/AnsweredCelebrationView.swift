import SwiftUI

struct AnsweredCelebrationView: View {
    let prayerTitle: String
    let onDismiss: () -> Void

    @Environment(\.bpPalette) private var palette

    @State private var showBackground = false
    @State private var showSeal = false
    @State private var showText = false
    @State private var showParticles = false
    @State private var glowPulse: Double = 0.4
    @State private var autoDismissing = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black
                .opacity(showBackground && !autoDismissing ? 0.7 : 0.0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Spacer()

                // Glowing seal with particle burst
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(palette.success.opacity(glowPulse * 0.15))
                        .frame(width: 160, height: 160)
                        .opacity(showSeal && !autoDismissing ? 1 : 0)

                    Circle()
                        .fill(palette.success.opacity(glowPulse * 0.08))
                        .frame(width: 120, height: 120)
                        .opacity(showSeal && !autoDismissing ? 1 : 0)

                    particleBurst

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(palette.success)
                        .shadow(color: palette.success.opacity(glowPulse), radius: 24, y: 0)
                        .scaleEffect(showSeal ? 1.0 : 0.2)
                        .opacity(showSeal && !autoDismissing ? 1 : 0)
                }

                Spacer().frame(height: 32)

                // "Prayer Answered!" heading
                Text("Prayer Answered!")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(showText && !autoDismissing ? 1 : 0)
                    .offset(y: showText ? 0 : 15)

                Spacer().frame(height: 12)

                // Prayer title in serif
                Text("\u{201C}\(prayerTitle)\u{201D}")
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .padding(.horizontal, 44)
                    .opacity(showText && !autoDismissing ? 1 : 0)
                    .offset(y: showText ? 0 : 10)

                Spacer().frame(height: 20)

                // Encouraging scripture
                VStack(spacing: 4) {
                    Text("God is faithful.")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\u{2014} 1 Corinthians 1:9")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(palette.success.opacity(0.6))
                }
                .opacity(showText && !autoDismissing ? 1 : 0)

                Spacer()
                Spacer()
            }
        }
        .onAppear { startAnimation() }
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        // Phase 0: Background dim
        withAnimation(.easeIn(duration: 0.35)) {
            showBackground = true
        }

        // Phase 1: Seal entrance (t=0.25s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            HapticService.success()
            withAnimation(BPAnimation.spring) {
                showSeal = true
            }
            withAnimation(BPAnimation.spring.delay(0.15)) {
                showParticles = true
            }
            // Start glow pulse
            withAnimation(BPAnimation.glowPulse) {
                glowPulse = 0.8
            }
        }

        // Phase 2: Text (t=0.65s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(BPAnimation.spring) {
                showText = true
            }
        }

        // Phase 3: Auto-dismiss (t=3.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            dismiss()
        }
    }

    private func dismiss() {
        guard !autoDismissing else { return }
        withAnimation(.easeOut(duration: 0.4)) {
            autoDismissing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }

    // MARK: - Particle Burst (gold + green sparkles)

    private var particleBurst: some View {
        ForEach(0..<12, id: \.self) { i in
            Circle()
                .fill(i % 3 == 0 ? palette.success.opacity(0.7) : Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.6))
                .frame(width: i % 2 == 0 ? 5 : 7, height: i % 2 == 0 ? 5 : 7)
                .offset(
                    x: showParticles ? cos(Self.angle(for: i)) * (i % 2 == 0 ? 70 : 90) : 0,
                    y: showParticles ? sin(Self.angle(for: i)) * (i % 2 == 0 ? 70 : 90) : 0
                )
                .opacity(showParticles ? 0 : 1)
                .scaleEffect(showParticles ? 0.2 : 1.0)
                .animation(
                    BPAnimation.spring.delay(0.25 + Double(i) * 0.035),
                    value: showParticles
                )
        }
    }

    private static func angle(for index: Int) -> Double {
        Double(index) * (.pi * 2 / 12)
    }
}
