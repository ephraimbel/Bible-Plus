import SwiftUI
import SwiftData

// MARK: - Building Your Plan (Reveal-Act Loader)
//
// The Cal AI signature beat: a short, animated "we're crafting this just for
// you" moment. A thin gold ring with the Bible✦ star glowing at its center and
// a small bead riding the arc; beneath it, a personalized checklist ticks each
// line from spinner to gold check as the ring fills. On completion the whole
// ring blooms to the star's gold. Making the effort visible is what makes the
// reveal that follows feel earned. Warm Paper / light.
struct OnboardingBuildingPlanView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var progress: CGFloat = 0
    @State private var completed = 0          // how many checklist lines are done
    @State private var appeared = false
    @State private var sparklePulse = false
    @State private var finished = false       // ring completes → turns star-gold
    @State private var choreography: Task<Void, Never>? = nil

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    // The exact warm, luminous gold of the Bible✦ wordmark star on the home page.
    private let starGold = Color(red: 1.0, green: 0.84, blue: 0.3)

    private let ringSize: CGFloat = 122
    private let ringStroke: CGFloat = 4

    private var name: String {
        let n = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "" : n
    }

    /// Personalized checklist lines, drawn from the interview answers. Each one
    /// ticks from a spinner to a gold check as the ring fills.
    private var steps: [String] {
        let burden = viewModel.selectedBurdens.first?.displayName.lowercased() ?? "your season"
        let minutes = viewModel.selectedTimeCommitment?.minutesLabel ?? "5"
        return [
            "Reading your answers",
            "Gathering verses for \(burden)",
            "Shaping your \(minutes)-minute daily rhythm",
            "Preparing your first 30 days"
        ]
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 34) {
                ring
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.92)

                VStack(spacing: 10) {
                    Text("CRAFTING YOUR PLAN")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(2.8)
                        .foregroundStyle(accentGold)

                    Text(name.isEmpty ? "Building something just for you" : "Building this just for you, \(name)")
                        .font(.custom("Baskerville-Bold", size: 25))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                checklist
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.vertical, 30)
        }
        .onAppear { begin() }
        .onDisappear { choreography?.cancel(); choreography = nil }
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            // Soft luminous halo breathing behind the star — gives the center
            // real depth so the mark feels lit from within, not pasted on.
            Circle()
                .fill(starGold.opacity(0.09))
                .blur(radius: 24)
                .scaleEffect(sparklePulse ? 1.06 : 0.92)

            // Faint full track.
            Circle()
                .stroke(accentGold.opacity(0.12), lineWidth: ringStroke)

            // Progress arc — the warm accent gold as it fills.
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [accentGold.opacity(0.75), accentGold],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Completion ring — the full circle in the star's luminous gold,
            // crossfading in once the arc reaches the top. The ring "turns gold"
            // to match the star at its center, with a soft halo that blooms.
            Circle()
                .stroke(starGold, style: StrokeStyle(lineWidth: ringStroke, lineCap: .round))
                .shadow(color: starGold.opacity(finished ? 0.55 : 0), radius: finished ? 9 : 0)
                .shadow(color: starGold.opacity(finished ? 0.3 : 0), radius: finished ? 18 : 0)
                .opacity(finished ? 1 : 0)
                .scaleEffect(finished ? 1 : 0.96)

            // A small gold bead riding the head of the arc — the detail that
            // makes the loader feel precise and alive rather than static. Fades
            // out as the ring completes and turns gold.
            Circle()
                .fill(starGold)
                .frame(width: 6, height: 6)
                .shadow(color: starGold.opacity(0.7), radius: 3)
                .offset(y: -(ringSize - ringStroke) / 2)
                .rotationEffect(.degrees(Double(progress) * 360))
                .opacity(progress > 0.015 && progress < 0.995 && !finished ? 1 : 0)

            // The Bible✦ glowing star — the exact mark from the home wordmark.
            Image(systemName: "sparkle")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(starGold)
                .shadow(color: starGold.opacity(0.6), radius: 3)
                .shadow(color: starGold.opacity(0.45), radius: 8)
                .shadow(color: starGold.opacity(sparklePulse ? 0.4 : 0.24), radius: 14)
                .shadow(color: starGold.opacity(sparklePulse ? 0.18 : 0.08), radius: 24)
                .scaleEffect(sparklePulse ? 1.05 : 0.95)
        }
        .frame(width: ringSize, height: ringSize)
    }

    // MARK: - Checklist

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 13) {
                    marker(for: index)
                        .frame(width: 22, height: 22)

                    Text(line)
                        .font(.custom("Georgia", size: 15.5))
                        .foregroundStyle(index < completed ? palette.textPrimary
                                         : index == completed ? palette.textPrimary
                                         : palette.textSecondary.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .opacity(index <= completed ? 1 : 0.55)
                .animation(.easeInOut(duration: 0.4), value: completed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func marker(for index: Int) -> some View {
        if index < completed {
            // Done — a clean gold check.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(accentGold)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        } else if index == completed {
            // The line currently being worked on — a small spinning arc that
            // self-animates on appear (survives being re-inserted each step).
            SpinnerArc(color: accentGold, animated: !reduceMotion)
                .frame(width: 18, height: 18)
        } else {
            Circle()
                .stroke(accentGold.opacity(0.22), lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }

    // MARK: - Choreography

    private func begin() {
        if reduceMotion {
            appeared = true
            completed = steps.count
            progress = 1
            finished = true
            choreography = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                onContinue()
            }
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { appeared = true }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { sparklePulse = true }

        choreography = Task { @MainActor in
            let count = steps.count
            try? await Task.sleep(nanoseconds: 400_000_000)
            for i in 0..<count {
                if Task.isCancelled { return }
                // Fill this line's slice of the ring while its spinner turns.
                withAnimation(.easeInOut(duration: 0.95)) {
                    progress = CGFloat(i + 1) / CGFloat(count)
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
                if Task.isCancelled { return }
                // Tick the line off.
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    completed = i + 1
                }
                HapticService.lightImpact()
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            // The arc is full — let it settle, then bloom the whole ring to the
            // star's gold in one clean, beautiful crossfade.
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.6)) { finished = true }
            HapticService.commit()
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            onContinue()
        }
    }

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(colors: [accentGold.opacity(0.10), .clear],
                           center: .init(x: 0.5, y: 0.40), startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Spinner Arc
//
// A self-contained indeterminate spinner. Owns its rotation state and starts
// it in onAppear, so it animates correctly each time the checklist re-inserts
// it for the line currently being worked on.
private struct SpinnerArc: View {
    let color: Color
    var animated: Bool = true
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .onAppear {
                guard animated else { return }
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    spinning = true
                }
            }
    }
}

#Preview("Building Plan") {
    OnboardingBuildingPlanView(viewModel: OnboardingViewModel(
        modelContext: try! ModelContainer(for: UserProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext,
        storeKitService: StoreKitService()
    ))
    .environment(\.bpPalette, .light)
}
