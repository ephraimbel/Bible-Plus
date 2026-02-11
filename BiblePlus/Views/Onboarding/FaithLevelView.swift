import SwiftUI

struct FaithLevelView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showContent = false

    private var greeting: String {
        viewModel.firstName.isEmpty
            ? "Where are you in\nyour faith journey?"
            : "Where are you in your\njourney with God, \(viewModel.firstName)?"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            Text(greeting)
                .font(BPFont.headingMedium)
                .foregroundStyle(BPColorPalette.light.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                ForEach(Array(FaithLevel.allCases.enumerated()), id: \.element) { index, level in
                    SelectionCard(
                        title: level.displayName,
                        subtitle: level.description,
                        icon: level.icon,
                        isSelected: viewModel.selectedFaithLevel == level,
                        action: { viewModel.selectedFaithLevel = level }
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(BPAnimation.staggered(index: index), value: showContent)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

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
