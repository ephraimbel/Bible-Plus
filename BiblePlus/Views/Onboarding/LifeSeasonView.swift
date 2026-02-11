import SwiftUI

struct LifeSeasonView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showContent = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                Text("What season are you\nin right now, \(viewModel.firstName)?")
                    .font(BPFont.headingMedium)
                    .foregroundStyle(BPColorPalette.light.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Select up to 3")
                    .font(BPFont.reference)
                    .foregroundStyle(BPColorPalette.light.textMuted)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 24)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(LifeSeason.allCases.enumerated()), id: \.element) { index, season in
                        CompactSelectionCard(
                            title: season.displayName,
                            icon: season.icon,
                            isSelected: viewModel.selectedLifeSeasons.contains(season),
                            action: { viewModel.toggleLifeSeason(season) }
                        )
                        .opacity(showContent ? 1 : 0)
                        .animation(BPAnimation.staggered(index: index), value: showContent)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 16)

            GoldButton(
                title: "Continue",
                isEnabled: viewModel.canProceed,
                action: { viewModel.goNext() }
            )
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)
        }
        .onAppear {
            withAnimation {
                showContent = true
            }
        }
    }
}
