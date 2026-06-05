import SwiftUI

// MARK: - "You're Seen" Mirror Beat
//
// The highest-ROI "feel seen" moment: reflects the user's "what holds you back"
// answer back to them — we built around exactly that — with the key words lit
// in gold. Warm Paper, serif, slow arrival.
struct OnboardingMirrorView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void

    @Environment(\.bpPalette) private var palette
    @State private var contentIn = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    /// Tailored copy for each "what holds you back" answer — a headline split
    /// into (lead · gold highlight · tail) plus a reassuring support line that
    /// speaks to that specific blocker.
    private func blockerCopy() -> (lead: String, highlight: String, tail: String, support: String) {
        guard let b = viewModel.selectedGrowthBlockers.first else {
            return ("Something tends to ", "get in the way", ".",
                    "Whatever it is, your daily path is built to work around it — just five honest minutes a day.")
        }
        switch b {
        case .busyness:
            return ("Life can feel ", "too full", " for one more thing.",
                    "We get it — so your path is just five honest minutes. Small enough to keep, even on the busiest days.")
        case .distraction:
            return ("There's ", "too much noise", " pulling at you.",
                    "So we made this a single, quiet focus each day — one verse, one prayer, nothing fighting for your attention.")
        case .whereToStart:
            return ("You're not sure ", "where to start", ".",
                    "That's the easy part now — we've mapped your first step, and the next, so you never face a blank page.")
        case .consistency:
            return ("Staying ", "consistent", " is the hard part.",
                    "That's the whole point of a daily path — small, repeatable steps and a gentle streak to keep you going.")
        case .tooTired:
            return ("You're often ", "too tired", " for it.",
                    "Then let this be rest, not another task — five quiet minutes that fill you back up instead of draining you.")
        case .boredom:
            return ("It can start to ", "feel boring", ".",
                    "So every day brings something new — a fresh verse, a real question, sacred art — never the same dry routine.")
        case .comprehension:
            return ("The Bible can be ", "hard to understand", ".",
                    "That's why every passage comes with plain-English meaning, and you can ask anything, anytime. No theology degree required.")
        case .focus:
            return ("It's ", "hard to stay focused", ".",
                    "So each day is short and single-minded — one thing to sit with, made to hold your attention, not lose it.")
        case .accountability:
            return ("There's ", "no one to keep you going", ".",
                    "Now there is — gentle daily nudges and a path that walks beside you, so you're never doing this alone.")
        case .unworthy:
            return ("Sometimes you ", "feel unworthy", " of it.",
                    "You're exactly who this is for. Grace isn't earned — come as you are, and let these few minutes be a gift.")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(accentGold.opacity(0.9))

                Text("THE REAL TALK")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(accentGold)

                headline
                    .font(.custom("Baskerville-Bold", size: 28))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(supportLine)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 30)
            .opacity(contentIn ? 1 : 0)
            .offset(y: contentIn ? 0 : 16)

            Spacer()

            GoldButton(title: "I'm ready", showGlow: true) {
                HapticService.lightImpact()
                onContinue()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
            .opacity(contentIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.86)) { contentIn = true }
        }
    }

    private var headline: Text {
        let c = blockerCopy()
        return Text(c.lead).foregroundStyle(palette.textPrimary)
            + Text(c.highlight).foregroundStyle(accentGold)
            + Text(c.tail).foregroundStyle(palette.textPrimary)
    }

    private var supportLine: String {
        blockerCopy().support
    }
}
