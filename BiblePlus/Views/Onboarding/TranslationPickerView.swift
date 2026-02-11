import SwiftUI

struct TranslationPickerView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                Text("Which translation speaks\nto your heart, \(viewModel.firstName)?")
                    .font(BPFont.headingMedium)
                    .foregroundStyle(BPColorPalette.light.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Each card shows John 3:16 so you can\ncompare tone and feel.")
                    .font(BPFont.reference)
                    .foregroundStyle(BPColorPalette.light.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(BibleTranslation.allCases) { translation in
                        TranslationPreviewCard(
                            translation: translation,
                            isSelected: viewModel.selectedTranslation == translation,
                            action: {
                                viewModel.selectedTranslation = translation
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollTargetBehavior(.viewAligned)

            Spacer()

            VStack(spacing: 8) {
                Text("You can always change this later.")
                    .font(BPFont.reference)
                    .foregroundStyle(BPColorPalette.light.textMuted)

                GoldButton(
                    title: "Continue",
                    action: { viewModel.goNext() }
                )
            }
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
