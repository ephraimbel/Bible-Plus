import SwiftUI

struct HeartBurdensView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                Text(viewModel.firstName.isEmpty
                    ? "What's weighing\non your heart right now?"
                    : "\(viewModel.firstName), what's weighing\non your heart right now?")
                    .font(BPFont.headingMedium)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We'll prioritize prayers and verses that\nspeak to these areas. Select up to 3.")
                    .font(BPFont.reference)
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 20)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(Burden.allCases.enumerated()), id: \.element) { index, burden in
                        CompactSelectionCard(
                            title: burden.displayName,
                            icon: burden.icon,
                            isSelected: viewModel.selectedBurdens.contains(burden),
                            action: { viewModel.toggleBurden(burden) }
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
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }
}
