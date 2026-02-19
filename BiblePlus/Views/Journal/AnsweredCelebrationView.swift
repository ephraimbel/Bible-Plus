import SwiftUI

// MARK: - Confetti Piece

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let shape: ConfettiShape
    let startX: CGFloat
    let startDelay: Double
    let fallDuration: Double
    let swayAmount: CGFloat
    let rotationSpeed: Double

    enum ConfettiShape {
        case circle, rectangle, roundedRect
    }

    static func random(in width: CGFloat, palette: BPColorPalette) -> ConfettiPiece {
        let colors: [Color] = [
            palette.success,
            palette.success.opacity(0.7),
            Color(red: 1.0, green: 0.84, blue: 0.3),
            Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.7),
            palette.accent,
            .white.opacity(0.8),
            Color(red: 0.4, green: 0.85, blue: 0.5),
            Color(red: 1.0, green: 0.7, blue: 0.3),
        ]
        let shapes: [ConfettiShape] = [.circle, .rectangle, .rectangle, .roundedRect]
        return ConfettiPiece(
            color: colors.randomElement() ?? palette.success,
            size: CGFloat.random(in: 4...9),
            shape: shapes.randomElement() ?? .rectangle,
            startX: CGFloat.random(in: -width / 2...width / 2),
            startDelay: Double.random(in: 0...0.4),
            fallDuration: Double.random(in: 2.5...4.0),
            swayAmount: CGFloat.random(in: -40...40),
            rotationSpeed: Double.random(in: 1...4)
        )
    }
}

// MARK: - Confetti View

private struct ConfettiView: View {
    let pieces: [ConfettiPiece]
    let screenWidth: CGFloat
    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    confettiShape(piece)
                        .foregroundStyle(piece.color)
                        .frame(
                            width: piece.shape == .circle ? piece.size : piece.size * 0.6,
                            height: piece.shape == .rectangle ? piece.size * 1.5 : piece.size
                        )
                        .rotationEffect(.degrees(falling ? piece.rotationSpeed * 360 : 0))
                        .offset(
                            x: piece.startX + (falling ? piece.swayAmount : 0),
                            y: falling ? geo.size.height + 50 : -50
                        )
                        .opacity(falling ? 0 : 1)
                        .animation(
                            .easeIn(duration: piece.fallDuration)
                                .delay(piece.startDelay),
                            value: falling
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            falling = true
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func confettiShape(_ piece: ConfettiPiece) -> some View {
        switch piece.shape {
        case .circle:
            Circle()
        case .rectangle:
            Rectangle()
        case .roundedRect:
            RoundedRectangle(cornerRadius: 2)
        }
    }
}

// MARK: - Answered Celebration

struct AnsweredCelebrationView: View {
    let prayerTitle: String
    let onDismiss: () -> Void

    @Environment(\.bpPalette) private var palette

    @State private var showBackground = false
    @State private var showSeal = false
    @State private var showText = false
    @State private var showParticles = false
    @State private var showConfetti = false
    @State private var glowPulse: Double = 0.4
    @State private var autoDismissing = false
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geo in
        ZStack {
            // Dimmed background
            Color.black
                .opacity(showBackground && !autoDismissing ? 0.7 : 0.0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Confetti layer
            if showConfetti {
                ConfettiView(pieces: confettiPieces, screenWidth: geo.size.width)
                    .ignoresSafeArea()
                    .opacity(autoDismissing ? 0 : 1)
            }

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
        .onAppear { startAnimation(screenWidth: geo.size.width) }
        }
    }

    // MARK: - Animation Sequence

    private func startAnimation(screenWidth: CGFloat) {
        confettiPieces = (0..<60).map { _ in
            ConfettiPiece.random(in: screenWidth, palette: palette)
        }

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
            // Launch confetti
            showConfetti = true
        }

        // Phase 2: Text (t=0.65s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(BPAnimation.spring) {
                showText = true
            }
        }

        // Phase 3: Auto-dismiss (t=4.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
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
