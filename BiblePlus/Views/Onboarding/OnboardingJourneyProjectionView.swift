import SwiftUI
import SwiftData

// MARK: - Your Journey (Reveal Act) — "The Light Within"
//
// Instead of charting faith on an axis, we show a person whose heart fills with
// light — the growth happens INSIDE them. After a brief "mapping your journey"
// beat, a small ember at the heart of a silhouette beats like a heart, swelling
// brighter with each beat, then blooms and lights the whole figure from within,
// with a faint cross at the center. Their heart, growing in Christ.
//
// Warm Paper / light, building momentum into the cinematic Personal Verse
// Reveal that follows.
struct OnboardingJourneyProjectionView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage = 0            // 0 = mapping, 1 = revealed
    @State private var contentIn = false
    @State private var figureIn = false
    @State private var tuningPulse = false
    @State private var glowScale: CGFloat = 0.35   // cross-glow size (beats + blooms)
    @State private var glowOpacity: Double = 0
    @State private var choreography: Task<Void, Never>? = nil

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let emberWhite = Color(red: 1.0, green: 0.97, blue: 0.86)
    private let figureDark = Color(red: 0.24, green: 0.21, blue: 0.18)

    private var name: String {
        let n = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "" : n
    }

    var body: some View {
        ZStack {
            background
            if stage == 0 {
                tuningView.transition(.opacity)
            } else {
                journeyView.transition(.opacity)
            }
        }
        .onAppear { begin() }
        .onDisappear { choreography?.cancel(); choreography = nil }
    }

    // MARK: - Tuning beat

    private var tuningView: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().fill(accentGold.opacity(0.10)).frame(width: 88, height: 88)
                    .scaleEffect(tuningPulse ? 1.12 : 0.92)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(accentGold)
                    .scaleEffect(tuningPulse ? 1.08 : 0.94)
            }
            Text(name.isEmpty ? "Mapping your journey…" : "Mapping your journey, \(name)…")
                .font(.custom("Georgia-Italic", size: 17))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                tuningPulse = true
            }
        }
    }

    // MARK: - Journey

    private var journeyView: some View {
        GeometryReader { screen in
            let figureH = min(max(screen.size.height * 0.44, 240), 380)
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Text("THE NEXT 30 DAYS")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(2.6)
                        .foregroundStyle(accentGold)
                    Text(headline)
                        .font(.custom("Baskerville-Bold", size: 27))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 12)

                Spacer(minLength: 12)

                glowingFigure
                    .frame(height: figureH)

                Spacer(minLength: 12)

                Text(outcomeCaption)
                    .font(.custom("Georgia-Italic", size: 15.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .opacity(contentIn ? 1 : 0)

                Spacer(minLength: 20)

                GoldButton(title: "Continue", showGlow: true) { onContinue() }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 16)
                    .opacity(contentIn ? 1 : 0)
            }
            .frame(width: screen.size.width, height: screen.size.height)
        }
    }

    private var headline: String {
        name.isEmpty ? "Growing closer to Christ." : "Growing closer to Christ, \(name)."
    }

    private var outcomeCaption: String {
        // Echo the felt-closeness "before" they gave earlier, so the projection
        // reads as a personal trajectory rather than a generic promise.
        let r = viewModel.closenessRating
        if r > 0 {
            return "Today, God feels about \(r) out of 5 close. Walk this path, and watch that grow — a little more each day."
        }
        return "Deeper in the Word, stronger in faith, closer to Christ — a little more each day."
    }

    // MARK: - The glowing figure

    private var glowingFigure: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let heart = CGPoint(x: w * 0.5, y: h * 0.70)

            ZStack {
                // Radiance spreading beyond the body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentGold.opacity(0.55), accentGold.opacity(0.0)],
                            center: .center, startRadius: 0, endRadius: w * 0.55
                        )
                    )
                    .frame(width: w * 1.3, height: w * 1.3)
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity * 0.6)
                    .blur(radius: 6)
                    .position(heart)

                // The person — the universally recognizable profile icon, so it
                // unmistakably reads as a human.
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: h * 0.94)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(figureDark)

                // The glowing cross on the heart — the focal point.
                crossView
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity)
                    .position(heart)
            }
            .opacity(figureIn ? 1 : 0)
        }
    }

    private var crossView: some View {
        ZStack {
            // Warm halo right behind the cross
            Circle()
                .fill(RadialGradient(colors: [accentGold.opacity(0.75), accentGold.opacity(0.0)], center: .center, startRadius: 0, endRadius: 48))
                .frame(width: 112, height: 112)
                .blur(radius: 8)

            // A single, solid Christian (Latin) cross — one crisp shape with
            // classic proportions (tall stem, crossbar in the upper third), not
            // two overlapping bars.
            LatinCross()
                .fill(
                    LinearGradient(colors: [emberWhite, accentGold], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 28, height: 48)
                .shadow(color: emberWhite.opacity(0.9), radius: 6)
                .shadow(color: accentGold.opacity(0.85), radius: 14)
                .shadow(color: accentGold.opacity(0.5), radius: 26)
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(colors: [accentGold.opacity(0.11), .clear], center: .init(x: 0.5, y: 0.42), startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
        }
    }

    // MARK: - Choreography

    private func begin() {
        if reduceMotion {
            stage = 1
            contentIn = true
            figureIn = true
            glowScale = 1.0
            glowOpacity = 1.0
            return
        }
        choreography = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { stage = 1 }
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.easeOut(duration: 0.6)) { contentIn = true }
            withAnimation(.easeOut(duration: 0.8)) { figureIn = true }
            try? await Task.sleep(nanoseconds: 550_000_000)

            // Heartbeats — each one swells brighter and wider than the last.
            let baseScales: [CGFloat] = [0.42, 0.56, 0.72, 0.9]
            let baseOpac: [Double] = [0.55, 0.70, 0.85, 0.95]
            for i in 0..<4 {
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    glowScale = baseScales[i] * 1.18
                    glowOpacity = baseOpac[i]
                }
                HapticService.lightImpact()
                try? await Task.sleep(nanoseconds: 170_000_000)
                withAnimation(.easeInOut(duration: 0.5)) { glowScale = baseScales[i] }
                try? await Task.sleep(nanoseconds: 560_000_000)
            }
            if Task.isCancelled { return }

            // Bloom — the cross flares to full radiance.
            withAnimation(.easeOut(duration: 1.0)) {
                glowScale = 1.0
                glowOpacity = 1.0
            }
            HapticService.commit()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }

            // Settle into a gentle, living breath.
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowScale = 1.08
            }
        }
    }
}

// MARK: - Latin Cross
//
// A single solid cross outline (12-point polygon) with classic Latin
// proportions — a tall stem and a crossbar set in the upper third — so it reads
// as a real, elegant Christian cross rather than two crossed lines.
private struct LatinCross: Shape {
    var thickness: CGFloat = 0.22   // bar thickness as a fraction of width
    var barTopFrac: CGFloat = 0.28  // crossbar top, as a fraction of height

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let t = w * thickness
        let barTop = rect.minY + h * barTopFrac
        let barBot = barTop + t

        var p = Path()
        p.move(to: CGPoint(x: cx - t / 2, y: rect.minY))
        p.addLine(to: CGPoint(x: cx + t / 2, y: rect.minY))
        p.addLine(to: CGPoint(x: cx + t / 2, y: barTop))
        p.addLine(to: CGPoint(x: rect.maxX, y: barTop))
        p.addLine(to: CGPoint(x: rect.maxX, y: barBot))
        p.addLine(to: CGPoint(x: cx + t / 2, y: barBot))
        p.addLine(to: CGPoint(x: cx + t / 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: cx - t / 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: cx - t / 2, y: barBot))
        p.addLine(to: CGPoint(x: rect.minX, y: barBot))
        p.addLine(to: CGPoint(x: rect.minX, y: barTop))
        p.addLine(to: CGPoint(x: cx - t / 2, y: barTop))
        p.closeSubpath()
        return p
    }
}

#Preview("Your Journey") {
    OnboardingJourneyProjectionView(viewModel: OnboardingViewModel(
        modelContext: try! ModelContainer(for: UserProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext,
        storeKitService: StoreKitService()
    ))
    .environment(\.bpPalette, .light)
}
