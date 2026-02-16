import SwiftUI

struct FaithLevelView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
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
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 28)

            VStack(spacing: 14) {
                ForEach(Array(FaithLevel.allCases.enumerated()), id: \.element) { index, level in
                    faithCard(level: level, index: index)
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
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }

    // MARK: - Faith Card

    @ViewBuilder
    private func faithCard(level: FaithLevel, index: Int) -> some View {
        let isSelected = viewModel.selectedFaithLevel == level

        Button {
            HapticService.selection()
            viewModel.selectedFaithLevel = level
        } label: {
            HStack(spacing: 16) {
                // Large icon circle
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? .white.opacity(0.2)
                                : palette.accent.opacity(0.1)
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: level.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? .white : palette.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : palette.textPrimary)

                    Text(level.description)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : palette.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.25))
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(palette.surfaceElevated)
                    )
                    .shadow(
                        color: isSelected
                            ? palette.accent.opacity(0.3)
                            : .black.opacity(0.04),
                        radius: isSelected ? 12 : 4,
                        y: isSelected ? 6 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Color.clear : palette.border.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(BPAnimation.staggered(index: index), value: showContent)
    }
}
