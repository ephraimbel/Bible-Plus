import SwiftUI

struct AestheticView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

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

                Text("50+ more backgrounds available inside.")
                    .font(BPFont.reference)
                    .foregroundStyle(palette.textMuted)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 20)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(ThemeDefinition.allThemes.enumerated()), id: \.element.id) {
                        index, theme in
                        ThemeCarouselCard(
                            theme: theme,
                            isSelected: viewModel.selectedThemeID == theme.id,
                            userName: viewModel.firstName,
                            action: { viewModel.selectedThemeID = theme.id }
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
