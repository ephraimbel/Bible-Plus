import SwiftUI

/// "Your Journey Is Ready" — animated personalization screen shown between
/// onboarding and paywall. Simulates the app being built for the user with
/// a staged progress animation before revealing their personalized items.
struct JourneyReadyView: View {
    let viewModel: OnboardingViewModel
    let onContinue: () -> Void

    @Environment(\.bpPalette) private var palette

    // Animation phases
    @State private var phase: AnimationPhase = .building
    @State private var progressValue: Double = 0
    @State private var currentStep = 0
    @State private var showItems: [Bool] = [false, false, false, false]
    @State private var showButton = false
    @State private var sparkleRotation: Double = 0
    @State private var sparkleScale: CGFloat = 1.0
    @State private var checkmarkScale: CGFloat = 0

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.3)
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private enum AnimationPhase {
        case building
        case complete
    }

    private var userName: String {
        let name = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "friend" : name
    }

    /// Building-phase labels echo the user's actual answers so the
    /// "Personalizing..." moment feels like real work happening on their
    /// behalf. Falls back to generic copy if a field is empty. Each label
    /// maps to one of the 4 progress segments.
    private var buildingSteps: [String] {
        let name = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        let primaryBurden = viewModel.selectedBurdens
            .filter { $0 != .none }
            .sorted { $0.rawValue < $1.rawValue }
            .first?
            .displayName.lowercased()
        let firstSeason = viewModel.selectedLifeSeasons
            .sorted { $0.rawValue < $1.rawValue }
            .first?
            .displayName.lowercased()
        let translation = viewModel.selectedTranslation.abbreviation
        let firstTime = viewModel.selectedPrayerTimes
            .sorted { $0.rawValue < $1.rawValue }
            .first?
            .displayName

        let verseLine = primaryBurden.map { "Matching verses to \($0)..." }
            ?? "Matching verses to your heart..."

        let prayerLine = firstSeason.map { "Curating prayers for your \($0) season..." }
            ?? "Curating prayers for this season..."

        let scheduleLine = firstTime.map { "Scheduling gentle moments at \($0)..." }
            ?? "Scheduling your daily rhythm..."

        let companionLine = name.isEmpty
            ? "Preparing your \(translation) companion..."
            : "Preparing \(name)'s \(translation) companion..."

        return [verseLine, prayerLine, scheduleLine, companionLine]
    }

    private var journeyItems: [(icon: String, title: String, detail: String)] {
        var items: [(String, String, String)] = []

        items.append(("sunrise", "Daily Verses & Prayers", "Curated for what you\u{2019}re carrying"))

        if !viewModel.selectedBurdens.isEmpty {
            let burdenNames = viewModel.selectedBurdens
                .prefix(2)
                .map(\.displayName)
                .joined(separator: " & ")
            items.append(("heart", "Content for \(burdenNames)", "Matched to your heart"))
        }

        if !viewModel.selectedPrayerTimes.isEmpty {
            let times = viewModel.selectedPrayerTimes
                .sorted { $0.rawValue < $1.rawValue }
                .map(\.displayName)
                .joined(separator: ", ")
            items.append(("bell", "Gentle reminders", times))
        }

        items.append(("book.closed", "Scripture companion", "Always here for you"))

        return items
    }

    @State private var trackedShown = false
    @State private var trackedCompleted = false

    var body: some View {
        ZStack {
            // Cinematic warm-dark background — builds depth from palette
            // colors rather than layering a blurred image under a flat
            // overlay (which produced the neutral-gray "muddiness").
            // Base: palette.background (warm matte black, R>G>B).
            // Depth: vertical warmth gradient tops-down.
            // Highlights: gold radial glows at top and bottom to frame the
            // content. Biblical texture stays but much more subtly.
            palette.background.ignoresSafeArea()

            Image("biblical_jacob_ladder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 44)
                .scaleEffect(1.22)
                .clipped()
                .opacity(0.20)
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: palette.surface.opacity(0.55), location: 0.0),
                    .init(color: palette.background, location: 0.45),
                    .init(color: palette.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    accentGold.opacity(0.22),
                    accentGold.opacity(0.08),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.02),
                startRadius: 0,
                endRadius: 480
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [
                    accentGold.opacity(0.10),
                    .clear
                ],
                center: .init(x: 0.5, y: 1.0),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)

            VStack(spacing: 0) {
                Spacer()

                if phase == .building {
                    buildingView
                        .transition(.opacity)
                } else {
                    completeView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.97)),
                            removal: .opacity
                        ))
                }

                Spacer()

                // Continue button — premium gold-on-warm-dark CTA
                if phase == .complete {
                    Button {
                        HapticService.impact(.light)
                        onContinue()
                    } label: {
                        HStack(spacing: 10) {
                            Text("Continue")
                                .font(.custom("Georgia-Bold", size: 17))
                                .tracking(0.3)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            palette.surfaceElevated.opacity(0.9),
                                            palette.surface.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .background(
                            Capsule().fill(accentGold.opacity(0.15))
                        )
                        .overlay(
                            // Subtle top sheen for depth
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accentGold.opacity(0.10),
                                            .clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [accentGold.opacity(0.55), palette.border.opacity(0.25), accentGold.opacity(0.55)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: accentGold.opacity(0.28), radius: 16, y: 6)
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 40)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                }

                Spacer().frame(height: 56)
            }
        }
        .onAppear {
            if !trackedShown {
                trackedShown = true
                Analytics.track(.planGeneratedShown)
            }
            startBuildingAnimation()
        }
    }

    // MARK: - Building Phase

    private var buildingView: some View {
        VStack(spacing: 28) {
            // Animated sparkle
            ZStack {
                // Outer glow rings
                Circle()
                    .stroke(accentGold.opacity(0.08), lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(sparkleScale)

                Circle()
                    .stroke(accentGold.opacity(0.05), lineWidth: 1)
                    .frame(width: 110, height: 110)
                    .scaleEffect(sparkleScale * 0.95)

                Image(systemName: "sparkle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.95, blue: 0.6), gold, accentGold],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: gold, radius: 8)
                    .shadow(color: gold.opacity(0.5), radius: 20)
                    .rotationEffect(.degrees(sparkleRotation))
            }

            // Title
            VStack(spacing: 10) {
                Text("Personalizing for you")
                    .font(.custom("Baskerville-Bold", size: 24))
                    .foregroundStyle(palette.textPrimary)

                // Current step text. Each label crossfades with a subtle
                // vertical drift rather than morphing in place — feels
                // intentional, not glitchy. `.id` forces a fresh transition
                // on every text change.
                Text(buildingSteps[min(currentStep, buildingSteps.count - 1)])
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(height: 36)
                    .id("step-\(currentStep)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.88), value: currentStep)
            }

            // Progress bar — fine 3pt line with a bright gold trail-head dot
            // riding the leading edge so the fill feels like light sweeping
            // forward rather than a flat bar advancing.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(accentGold.opacity(0.10))
                        .frame(height: 3)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentGold.opacity(0.7), gold],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progressValue), height: 3)
                        .shadow(color: gold.opacity(0.45), radius: 5)

                    // Trail-head: slightly oversized gold dot that rides the
                    // filled edge. Pulsing shadow keeps it feeling alive.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 1.0, green: 0.95, blue: 0.65), gold],
                                center: .center,
                                startRadius: 0,
                                endRadius: 5
                            )
                        )
                        .frame(width: 8, height: 8)
                        .shadow(color: gold, radius: 5)
                        .shadow(color: gold.opacity(0.6), radius: 12)
                        .offset(x: max(0, geo.size.width * progressValue - 4))
                        .opacity(progressValue > 0 && progressValue < 1 ? 1 : 0)
                }
            }
            .frame(height: 10)
            .padding(.horizontal, 60)
        }
    }

    // MARK: - Complete Phase

    private var completeView: some View {
        VStack(spacing: 26) {
            // Checkmark with layered glow — outer soft halo, gold-filled
            // disc, inner white sheen, crisp gold check.
            ZStack {
                // Outer breath ring
                Circle()
                    .stroke(accentGold.opacity(0.18), lineWidth: 0.6)
                    .frame(width: 108, height: 108)

                // Mid halo
                Circle()
                    .fill(accentGold.opacity(0.06))
                    .frame(width: 92, height: 92)

                // Core disc with gold gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentGold.opacity(0.28),
                                accentGold.opacity(0.10)
                            ],
                            center: .init(x: 0.35, y: 0.30),
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.95, blue: 0.65).opacity(0.55),
                                        accentGold.opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: accentGold.opacity(0.35), radius: 14, y: 0)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.65),
                                accentGold
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                    .scaleEffect(checkmarkScale)
            }

            VStack(spacing: 10) {
                Text("Your journey is ready,\n\(userName).")
                    .font(.custom("Baskerville-Bold", size: 27))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .tracking(0.3)

                Text("Here\u{2019}s what we prepared for you")
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundStyle(palette.textSecondary)
            }

            // Personalized items — staggered entrance. Each row slides up
            // from +14pt while scaling from 0.97 → 1.0 so the cascade has
            // a touch of weight without bouncing.
            VStack(spacing: 8) {
                ForEach(Array(journeyItems.prefix(4).enumerated()), id: \.offset) { index, item in
                    if index < showItems.count && showItems[index] {
                        journeyItem(icon: item.icon, title: item.title, detail: item.detail)
                            .transition(.asymmetric(
                                insertion: .opacity
                                    .combined(with: .offset(y: 14))
                                    .combined(with: .scale(scale: 0.97, anchor: .top)),
                                removal: .opacity
                            ))
                    }
                }
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Journey Item

    private func journeyItem(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(accentGold)
                .frame(width: 34, height: 34)
                .background(Circle().fill(accentGold.opacity(0.08)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Georgia-Bold", size: 13))
                    .foregroundStyle(palette.textPrimary)
                Text(detail)
                    .font(.custom("Georgia", size: 11))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accentGold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            // Premium warm-dark card. Uses palette.surface (R>G>B warm
            // dark) instead of .ultraThinMaterial (cold neutral gray) so
            // it reads as part of the warm palette, not a system card
            // parachuted in.
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surfaceElevated.opacity(0.85),
                            palette.surface.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Subtle top gold sheen for depth
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentGold.opacity(0.08),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentGold.opacity(0.22),
                            palette.border.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }

    // MARK: - Animation Sequence

    private func startBuildingAnimation() {
        // Sparkle rotation — slow, never calls attention to itself
        withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }

        // Sparkle breathing — pairs with the progress-bar rhythm
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            sparkleScale = 1.10
        }

        // Progress fills in segments. Each segment uses a spring so the
        // fill eases into its stop rather than linear-flat. Haptic ticks
        // are reserved for the final transition — step ticks were too
        // noisy (4 beats back-to-back registered as haptic spam).
        let stepDuration: Double = 0.75

        for i in 0..<buildingSteps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                    currentStep = i
                }
                withAnimation(.spring(response: stepDuration, dampingFraction: 0.92)) {
                    progressValue = Double(i + 1) / Double(buildingSteps.count)
                }
            }
        }

        // Hold beat after the bar fills — gives the final label a moment
        // to read before the screen pivots.
        let totalBuildTime = stepDuration * Double(buildingSteps.count) + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalBuildTime) {
            HapticService.commit()
            if !trackedCompleted {
                trackedCompleted = true
                Analytics.track(.planGeneratedCompleted)
            }

            // Hand off to the complete phase with a quick consecrate spring
            withAnimation(BPAnimation.consecrate) {
                phase = .complete
            }

            // Checkmark scales in with a touch of overshoot — the moment
            // the user feels their plan land.
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(0.18)) {
                checkmarkScale = 1.0
            }

            // Items cascade in. Tighter 0.1s stagger keeps the rhythm fast
            // but readable. Spring is slightly softer than before so each
            // row lands with weight rather than snapping in.
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(i) * 0.10) {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                        if i < showItems.count {
                            showItems[i] = true
                        }
                    }
                }
            }

            // Button appears last with a bit of scale to breathe
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    showButton = true
                }
            }
        }
    }
}
