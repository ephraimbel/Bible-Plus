import SwiftUI

struct AestheticView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var shakeLockedID: String?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    // 6 hand-picked Pro backgrounds for visual diversity
    private let proPickIDs: [String] = [
        "forest-sunlight",   // Nature video — green forest
        "candle-flicker",    // Warmth — cozy candlelight
        "ocean-aerial",      // Ocean — blue aerial
        "coral-sunset",      // Warmth — vibrant gradient
        "stained-glass",     // Sacred — multicolor gradient
        "spring-bloom",      // Seasonal — pink/green gradient
    ]

    private var essentials: [SanctuaryBackground] {
        SanctuaryBackground.allBackgrounds.filter { $0.collection == .essentials }
    }

    private var proPicks: [SanctuaryBackground] {
        proPickIDs.compactMap { SanctuaryBackground.background(for: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Header
            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        Text("Make ")
                        Text("Bible")
                        Text("+")
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.9), radius: 20)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.6), radius: 40)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.3), radius: 60)
                    }
                    Text(viewModel.firstName.isEmpty
                        ? "feel like yours."
                        : "feel like yours, \(viewModel.firstName).")
                }
                .font(BPFont.headingMedium)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)

                Text("Choose your background.")
                    .font(BPFont.reference)
                    .foregroundStyle(palette.textMuted)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 20)

            // Background grid
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    // MARK: Essentials Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("ESSENTIALS", count: essentials.count, showCrown: false)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(essentials.enumerated()), id: \.element.id) { index, bg in
                                OnboardingBackgroundCard(
                                    background: bg,
                                    isSelected: viewModel.selectedBackgroundID == bg.id,
                                    isLocked: false,
                                    action: {
                                        HapticService.selection()
                                        viewModel.selectedBackgroundID = bg.id
                                    }
                                )
                                .opacity(showContent ? 1 : 0)
                                .animation(BPAnimation.staggered(index: index), value: showContent)
                            }
                        }
                    }

                    // MARK: Pro Picks Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("PRO PICKS", count: proPicks.count, showCrown: true)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(proPicks.enumerated()), id: \.element.id) { index, bg in
                                OnboardingBackgroundCard(
                                    background: bg,
                                    isSelected: viewModel.selectedBackgroundID == bg.id,
                                    isLocked: true,
                                    action: {
                                        HapticService.notification(.warning)
                                        withAnimation(.default.speed(3)) {
                                            shakeLockedID = bg.id
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            shakeLockedID = nil
                                        }
                                    }
                                )
                                .offset(x: shakeLockedID == bg.id ? shakeOffset : 0)
                                .opacity(showContent ? 1 : 0)
                                .animation(
                                    BPAnimation.staggered(index: index + essentials.count),
                                    value: showContent
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer().frame(height: 16)

            GoldButton(
                title: "Continue",
                action: { viewModel.goNext() }
            )
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int, showCrown: Bool) -> some View {
        HStack(spacing: 6) {
            if showCrown {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.accent)
            }

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted.opacity(0.6))
        }
    }

    // MARK: - Shake Animation

    private var shakeOffset: CGFloat {
        // Simple horizontal shake
        let t = Date.timeIntervalSinceReferenceDate
        let phase = sin(t * 40) * 6
        return CGFloat(phase)
    }
}
