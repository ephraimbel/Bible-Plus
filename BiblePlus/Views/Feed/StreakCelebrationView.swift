import SwiftUI

struct StreakCelebrationView: View {
    let streakCount: Int
    let milestone: StreakService.MilestoneType?
    let onDismiss: () -> Void

    @Environment(\.bpPalette) private var palette

    // Animation phases
    @State private var showBackground = false
    @State private var showFlame = false
    @State private var showCount = false
    @State private var showMessage = false
    @State private var showParticles = false
    @State private var flameGlow: Double = 0.3
    @State private var displayedCount: Int = 0
    @State private var autoDismissing = false

    private var isMilestone: Bool { milestone != nil }

    private var flameIcon: String {
        milestone?.icon ?? "flame.fill"
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black
                .opacity(showBackground && !autoDismissing ? 0.6 : 0.0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 24) {
                Spacer()

                // Flame icon with glow + particle burst
                ZStack {
                    if isMilestone {
                        particleBurst
                    }

                    Image(systemName: flameIcon)
                        .font(.system(size: isMilestone ? 72 : 64, weight: .thin))
                        .foregroundStyle(palette.accent)
                        .shadow(color: palette.accent.opacity(flameGlow), radius: 20, y: 0)
                        .scaleEffect(showFlame ? 1.0 : 0.3)
                        .opacity(showFlame && !autoDismissing ? 1 : 0)
                }

                // Streak count
                VStack(spacing: 4) {
                    Text("\(displayedCount)")
                        .font(BPFont.headingLarge)
                        .foregroundStyle(isMilestone ? palette.accent : .white)
                        .contentTransition(.numericText())

                    Text("day streak")
                        .font(BPFont.body)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(showCount && !autoDismissing ? 1 : 0)
                .offset(y: showCount ? 0 : 15)

                // Motivational message
                Text(motivationalMessage)
                    .font(isMilestone ? BPFont.prayerMedium : BPFont.prayerSmall)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .opacity(showMessage && !autoDismissing ? 1 : 0)
                    .offset(y: showMessage ? 0 : 10)

                Spacer()
            }
        }
        .onAppear { startAnimation() }
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        // Phase 0: Background dim
        withAnimation(.easeIn(duration: 0.3)) {
            showBackground = true
        }

        // Phase 1: Flame entrance (t=0.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            HapticService.impact(isMilestone ? .heavy : .medium)
            withAnimation(BPAnimation.spring) {
                showFlame = true
            }
            withAnimation(BPAnimation.glowPulse) {
                flameGlow = 0.7
            }
            if isMilestone {
                withAnimation(BPAnimation.spring.delay(0.15)) {
                    showParticles = true
                }
            }
        }

        // Phase 2: Count (t=0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(BPAnimation.spring) {
                showCount = true
            }
            startCountingAnimation()
        }

        // Phase 3: Message (t=0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(BPAnimation.spring) {
                showMessage = true
            }
        }

        // Phase 4: Auto-dismiss (t=3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            dismiss()
        }
    }

    private func startCountingAnimation() {
        let start = max(1, streakCount - 3)
        displayedCount = start
        let steps = streakCount - start
        guard steps > 0 else {
            displayedCount = streakCount
            HapticService.success()
            return
        }
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.snappy(duration: 0.2)) {
                    displayedCount = start + i
                }
                if start + i == streakCount {
                    HapticService.success()
                }
            }
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

    // MARK: - Motivational Messages

    private var motivationalMessage: String {
        if let milestone {
            return milestone.celebrationMessage
        }

        if streakCount == 1 {
            return "Your journey begins today."
        }

        let messages = [
            "God sees your faithfulness.",
            "One day at a time with Him.",
            "Your consistency is a prayer.",
            "He meets you every time you show up.",
            "Building a habit of grace.",
        ]
        // Deterministic pick based on streak count so it's stable within a session
        return messages[streakCount % messages.count]
    }

    // MARK: - Milestone Particle Burst

    private var particleBurst: some View {
        ForEach(0..<8, id: \.self) { i in
            Circle()
                .fill(palette.accent.opacity(0.6))
                .frame(width: 6, height: 6)
                .offset(
                    x: showParticles ? cos(Self.angle(for: i)) * 80 : 0,
                    y: showParticles ? sin(Self.angle(for: i)) * 80 : 0
                )
                .opacity(showParticles ? 0 : 1)
                .scaleEffect(showParticles ? 0.3 : 1.0)
                .animation(
                    BPAnimation.spring.delay(0.3 + Double(i) * 0.04),
                    value: showParticles
                )
        }
    }

    private static func angle(for index: Int) -> Double {
        Double(index) * (.pi * 2 / 8)
    }
}
