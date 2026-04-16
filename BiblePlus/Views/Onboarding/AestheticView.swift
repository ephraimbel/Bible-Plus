import SwiftUI

struct AestheticView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: (() -> Void)? = nil
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var selectedFilter: BackgroundFilter = .all
    @Namespace private var chipAnimation

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.3)
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            // Header
            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Text("Make ")
                        Text("Bible")
                        Image(systemName: "sparkle")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.92, blue: 0.55),
                                        gold,
                                        accentGold
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: gold, radius: 4)
                            .shadow(color: gold.opacity(0.7), radius: 12)
                            .shadow(color: gold.opacity(0.3), radius: 30)
                    }
                    Text(viewModel.firstName.isEmpty
                        ? "feel like yours."
                        : "feel like yours, \(viewModel.firstName).")
                }
                .font(BPFont.onboardingHeading)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)

                Text("Choose your background.")
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(palette.textSecondary)
            }
            .opacity(showContent ? 1 : 0)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BackgroundFilter.allCases) { filter in
                        filterChip(for: filter)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .opacity(showContent ? 1 : 0)

            // Background grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(allFilteredBackgrounds.enumerated()), id: \.element.id) { index, bg in
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
                .padding(.horizontal, 20)
            }

            Spacer().frame(height: 16)

            // Continue button — frosted glass + gold border (matches welcome)
            Button {
                HapticService.impact(.light)
                if let onContinue {
                    onContinue()
                } else {
                    viewModel.goNext()
                }
            } label: {
                Text("Continue")
                    .font(.custom("Georgia-Bold", size: 17))
                    .tracking(0.4)
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial.opacity(0.6))
                    )
                    .background(
                        Capsule()
                            .fill(accentGold.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        accentGold.opacity(0.5),
                                        palette.border.opacity(0.2),
                                        accentGold.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: accentGold.opacity(0.2), radius: 10, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 32)

            Spacer().frame(height: 44)
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }

    // MARK: - Filter Chip

    @ViewBuilder
    private func filterChip(for filter: BackgroundFilter) -> some View {
        let isSelected = selectedFilter == filter

        Button {
            HapticService.selection()
            withAnimation(BPAnimation.selection) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11, weight: .medium))

                Text(filter.displayName)
                    .font(.custom("Georgia-Bold", size: 12))
            }
            .foregroundStyle(isSelected ? .white : palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(palette.accent)
                        .shadow(color: palette.accent.opacity(0.25), radius: 4, y: 2)
                        .matchedGeometryEffect(id: "onboardingChip", in: chipAnimation)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .overlay(
                            Capsule()
                                .stroke(accentGold.opacity(0.15), lineWidth: 0.5)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtering

    private var allFilteredBackgrounds: [SanctuaryBackground] {
        SanctuaryBackground.allBackgrounds.filter { selectedFilter.matches($0) }
    }
}
