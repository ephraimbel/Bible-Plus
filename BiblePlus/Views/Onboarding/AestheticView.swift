import SwiftUI

struct AestheticView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    private var essentials: [SanctuaryBackground] {
        SanctuaryBackground.allBackgrounds.filter { $0.collection == .essentials }
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

}
