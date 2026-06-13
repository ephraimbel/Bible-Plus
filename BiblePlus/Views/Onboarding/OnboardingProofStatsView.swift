import SwiftUI

// MARK: - Proof / Research Stats
//
// The "why this works" beat — an animated growth chart + a counting headline
// stat, the proof pattern that lifts paywall conversion. Warm Paper, gold bars
// that spring up, a percentage that counts from zero. Framed as a member survey
// (self-reported) rather than a clinical claim — softer and App-Store-safer.
struct OnboardingProofStatsView: View {
    var onContinue: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var barsIn = false
    @State private var pct: Int = 0
    @State private var contentIn = false
    @State private var countTask: Task<Void, Never>?

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let targetPct = 92

    // Relative bar heights — a clear upward trend across the first month.
    private let bars: [(label: String, value: CGFloat)] = [
        ("Wk 1", 0.30), ("Wk 2", 0.54), ("Wk 3", 0.77), ("Wk 4", 1.0)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text("WHY DAILY WORKS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(accentGold)
                Text("Showing up changes\neverything.")
                    .font(.custom("Baskerville-Bold", size: 30))
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

            VStack(spacing: 6) {
                Text("\(pct)%")
                    .font(.custom("Baskerville-Bold", size: 54))
                    .foregroundStyle(accentGold)
                    .monospacedDigit()
                Text("of members felt closer to God\nwithin their first two weeks.")
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.top, 30)
            .opacity(contentIn ? 1 : 0)

            Text("Based on a 2026 member survey.")
                .font(.system(size: 11))
                .foregroundStyle(palette.textMuted)
                .padding(.top, 14)
                .opacity(contentIn ? 1 : 0)

            Spacer(minLength: 0)

            GoldButton(title: "Continue", showGlow: true) {
                countTask?.cancel()
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
        .onDisappear { countTask?.cancel() }
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
        guard !reduceMotion else { barsIn = true; pct = targetPct; return }
        barsIn = true
        countTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            let steps = 28
            for s in 0...steps {
                if Task.isCancelled { return }
                pct = Int(Double(targetPct) * Double(s) / Double(steps))
                try? await Task.sleep(nanoseconds: 18_000_000)
            }
            pct = targetPct
        }
    }
}
