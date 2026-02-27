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
            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        Text("Add ")
                        Text("Bible")
                        Text("+")
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.9), radius: 20)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.6), radius: 40)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.3), radius: 60)
                    }
                    Text("to your Home Screen")
                }
                .font(BPFont.onboardingHeading)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)

                Text("See personalized prayers and verses\nevery time you unlock your phone.")
                    .font(BPFont.onboardingBody)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 28)

            // Step-by-step carousel
            TabView(selection: $currentSetupStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 24) {
                        // Step icon — elevated circle with outer glow
                        ZStack {
                            // Outer glow circle
                            Circle()
                                .fill(palette.accent.opacity(0.06))
                                .frame(width: 120, height: 120)

                            // Main icon circle
                            Circle()
                                .fill(palette.surfaceElevated)
                                .frame(width: 88, height: 88)
                                .shadow(color: palette.accent.opacity(0.12), radius: 10, y: 5)
                                .overlay(
                                    Circle()
                                        .stroke(palette.accent.opacity(0.1), lineWidth: 0.5)
                                )

                            Image(systemName: step.icon)
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(palette.accent)
                        }

                        VStack(spacing: 10) {
                            Text("STEP \(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(palette.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(palette.accent.opacity(0.06))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
                                )

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
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 300)

            // Custom page indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(currentSetupStep == index ? palette.accent : palette.accent.opacity(0.2))
                        .frame(width: currentSetupStep == index ? 20 : 7, height: 7)
                        .shadow(
                            color: currentSetupStep == index ? palette.accent.opacity(0.3) : .clear,
                            radius: 4, y: 0
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentSetupStep)
                }
            }
            .padding(.top, 8)

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

            Spacer().frame(height: 44)
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }
}
