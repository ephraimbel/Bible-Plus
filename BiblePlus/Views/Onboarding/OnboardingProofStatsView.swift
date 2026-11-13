import SwiftUI

// MARK: - Proof / Research Stats
//
// The "why this works" beat — an animated growth chart + a counting headline
// stat, the proof pattern that lifts paywall conversion. Warm Paper, gold bars
// that spring up, and a Scripture anchor. The chart is illustrative only — no
// statistics are claimed (Guideline 2.3.1).
struct OnboardingProofStatsView: View {
    var onContinue: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var barsIn = false
    @State private var contentIn = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    // Relative bar heights — a clear upward trend across the first month.
    private let bars: [(label: String, value: CGFloat)] = [
        ("Wk 1", 0.30), ("Wk 2", 0.54), ("Wk 3", 0.77), ("Wk 4", 1.0)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text("WHY DAILY WORKS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(2.8)
                    .foregroundStyle(accentGold)
                Text("Showing up changes\neverything.")
                    .font(.custom("Baskerville", size: 31))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentIn ? 1 : 0)
            .offset(y: contentIn ? 0 : 12)
            .padding(.bottom, 30)

            chart
                .frame(height: 170)
                .padding(.horizontal, 44)
                .opacity(contentIn ? 1 : 0)

            // App Store 2.3.1: no unverified statistics. (Previously showed
            // "92% of members felt closer to God… 2026 member survey".) If a
            // real, documented survey exists, the stat can be restored with a
            // citation; until then we use Scripture, not numbers.
            VStack(spacing: 10) {
                Text("A few minutes a day,\nevery day.")
                    .font(.custom("Baskerville-Bold", size: 26))
                    .foregroundStyle(accentGold)
                    .multilineTextAlignment(.center)
                Text(verbatim: "But his delight is in the law of the LORD; and in his law doth he meditate day and night.")
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
                Text(verbatim: "Psalm 1:2 (KJV)")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textMuted)
            }
            .padding(.top, 30)
            .opacity(contentIn ? 1 : 0)

            Spacer(minLength: 0)

            GoldButton(title: "Continue", showGlow: true) {
                HapticService.lightImpact()
                onContinue()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .opacity(contentIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
        .onAppear { animateIn() }
    }

    private var chart: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 20) {
                ForEach(bars.indices, id: \.self) { i in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accentGold, accentGold.opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(height: max(6, (barsIn ? geo.size.height * 0.82 * bars[i].value : 6)))
                            .frame(maxWidth: .infinity)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(0.25 + Double(i) * 0.12),
                                value: barsIn
                            )
                        Text(bars[i].label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.6)) { contentIn = true }
        barsIn = true
    }
}
