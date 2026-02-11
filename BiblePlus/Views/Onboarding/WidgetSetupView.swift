import SwiftUI

struct WidgetSetupView: View {
    let viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false
    @State private var currentSetupStep = 0

    private let steps: [(icon: String, title: String, description: String)] = [
        ("hand.tap", "Long press your Home Screen", "Press and hold on an empty area until the apps start wiggling."),
        ("plus.circle", "Tap the + button", "Look for the + button in the top left corner of your screen."),
        ("magnifyingglass", "Search for Bible+", "Type \"Bible+\" in the search bar to find our widgets."),
        ("square.grid.2x2", "Choose a widget", "Pick your favorite size and tap \"Add Widget\" to place it."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                Text("Add Bible+\nto your Home Screen")
                    .font(BPFont.headingMedium)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("See personalized prayers and verses\nevery time you unlock your phone.")
                    .font(BPFont.reference)
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 32)

            // Step-by-step carousel
            TabView(selection: $currentSetupStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 24) {
                        // Step icon
                        ZStack {
                            Circle()
                                .fill(palette.accentSoft)
                                .frame(width: 100, height: 100)

                            Image(systemName: step.icon)
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(palette.accent)
                        }

                        VStack(spacing: 10) {
                            Text("Step \(index + 1)")
                                .font(BPFont.reference)
                                .foregroundStyle(palette.accent)

                            Text(step.title)
                                .font(BPFont.headingSmall)
                                .foregroundStyle(palette.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(step.description)
                                .font(BPFont.body)
                                .foregroundStyle(palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 40)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 320)

            Spacer()

            VStack(spacing: 12) {
                GoldButton(
                    title: "I'm Ready",
                    showGlow: true,
                    action: {
                        viewModel.completeOnboarding()
                    }
                )

                Button {
                    viewModel.completeOnboarding()
                } label: {
                    Text("Skip for now")
                        .font(BPFont.button)
                        .foregroundStyle(palette.textMuted)
                }
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
