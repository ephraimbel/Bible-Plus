import SwiftUI

// MARK: - Showcase Reel (Onboarding S9)
//
// The "Built around you" centerpiece: one persistent iPhone whose screen
// cycles through the app's pillars — AI companion, the verse feed, and the
// Bible reader — each with a synced caption and progress ticks. Auto-advances
// on a calm cadence; tap the device to move on; a Continue CTA lets the user
// proceed whenever they're ready. (Widgets pillar removed.)
//
// (Sanctuary is intentionally omitted — deprecated.)
struct ShowcaseReelView: View {
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var appeared = false
    @State private var advanceTask: Task<Void, Never>? = nil

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private struct Pillar {
        let headline: String
        let sub: String
        let dark: Bool
        /// Seconds this pillar stays on screen before auto-advancing — sized so
        /// each scene's entrance animation finishes (plus a beat to admire it)
        /// before the reel switches. The AI scene is the longest (it types out
        /// a full answer + raises a scripture card), so it gets the most time.
        let duration: Double
    }

    private let pillars: [Pillar] = [
        Pillar(headline: "Ask anything", sub: "Real wisdom for real life — always grounded in Scripture.", dark: false, duration: 8.5),
        Pillar(headline: "A feed that knows you", sub: "Verses chosen for the season you're walking through.", dark: true, duration: 4.5),
        Pillar(headline: "Read deeper, instantly", sub: "Tap any verse and understand it in seconds.", dark: false, duration: 6.5)
    ]

    var body: some View {
        ZStack {
            background

            GeometryReader { geo in
                // Reserve fixed chrome (eyebrow + caption + ticks + CTA), give
                // the rest to the device so it reads larger and more accurate.
                let deviceWidth = min(
                    280,
                    geo.size.width * 0.84,
                    (geo.size.height - 214) / 2.16
                )

                VStack(spacing: 0) {
                    Text("WHAT'S INSIDE")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(accentGold)
                        .opacity(appeared ? 1 : 0)
                        .padding(.top, 6)

                    Spacer(minLength: 10)

                    DeviceFrame(width: deviceWidth, screenBackground: deviceBackground) {
                        sceneView(index)
                    }
                    .id(index)
                    .transition(.opacity)
                    .scaleEffect(appeared ? 1 : 0.94)
                    .opacity(appeared ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { goNext() }

                    Spacer(minLength: 12)

                    caption
                        .id(index)
                        .transition(.opacity.combined(with: .offset(y: 8)))

                    progressTicks
                        .padding(.top, 10)

                    Spacer(minLength: 12)

                    GoldButton(title: "Continue") { onContinue() }
                        .padding(.horizontal, 30)
                        .opacity(appeared ? 1 : 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .padding(.vertical, 14)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.9)) {
                appeared = true
            }
            scheduleAdvance()
        }
        .onDisappear { advanceTask?.cancel(); advanceTask = nil }
    }

    // MARK: - Current scene

    @ViewBuilder
    private func sceneView(_ i: Int) -> some View {
        switch i {
        case 0: AICompanionScene().environment(\.bpPalette, .light)
        case 1: FeedScene()
        default: BibleReaderScene().environment(\.bpPalette, .light)
        }
    }

    private var deviceBackground: Color {
        pillars[index].dark ? .black : Color(hex: "FBF8F3")
    }

    // MARK: - Caption

    private var caption: some View {
        VStack(spacing: 6) {
            Text(pillars[index].headline)
                .font(.custom("Baskerville-Bold", size: 22))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textPrimary)

            Text(pillars[index].sub)
                .font(.custom("Georgia-Italic", size: 13.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Progress ticks

    private var progressTicks: some View {
        HStack(spacing: 6) {
            ForEach(pillars.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? accentGold : palette.textMuted.opacity(0.3))
                    .frame(width: i == index ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(
                colors: [accentGold.opacity(0.12), .clear],
                center: .init(x: 0.5, y: 0.42),
                startRadius: 0,
                endRadius: 330
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Advance

    /// Schedules the next auto-advance after the current pillar's full
    /// duration. Each switch reschedules for the new pillar, so timing tracks
    /// the scene on screen (the AI scene gets ~8.5s to finish typing; the
    /// near-static widgets scene only ~3.8s). Cancellable so a manual tap or
    /// leaving the screen resets it cleanly.
    private func scheduleAdvance() {
        advanceTask?.cancel()
        guard !reduceMotion else { return }
        let seconds = pillars[index].duration
        advanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { return }
            goNext()
        }
    }

    private func goNext() {
        withAnimation(.easeInOut(duration: 0.5)) {
            index = (index + 1) % pillars.count
        }
        scheduleAdvance()
    }
}

#Preview("Showcase Reel") {
    ShowcaseReelView()
        .environment(\.bpPalette, .light)
}
