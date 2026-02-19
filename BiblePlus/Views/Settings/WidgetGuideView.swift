import SwiftUI

struct WidgetGuideView: View {
    enum Mode {
        case homeScreen
        case lockScreen
    }

    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var currentStep = 0
    @State private var showContent = false

    private var steps: [(icon: String, title: String, description: String)] {
        switch mode {
        case .homeScreen:
            return [
                ("hand.tap", "Long press your Home Screen", "Press and hold on an empty area until the apps start wiggling."),
                ("plus.circle", "Tap the + button", "Look for the + button in the top left corner of your screen."),
                ("magnifyingglass", "Search for \"Bible+\"", "Type \"Bible+\" in the search bar to find our widgets."),
                ("square.grid.2x2", "Choose a widget size", "Pick your favorite size and tap \"Add Widget\" to place it."),
            ]
        case .lockScreen:
            return [
                ("hand.tap", "Long press your Lock Screen", "Press and hold on your Lock Screen until options appear."),
                ("slider.horizontal.3", "Tap \"Customize\"", "Select \"Customize\" then choose your Lock Screen to edit."),
                ("rectangle.and.hand.point.up.left", "Tap the widget area", "Tap the widget area above or below the clock to add widgets."),
                ("magnifyingglass", "Search for \"Bible+\"", "Find Bible+ in the widget list and tap to add it."),
            ]
        }
    }

    private var title: String {
        switch mode {
        case .homeScreen: return "Home Screen Widget"
        case .lockScreen: return "Lock Screen Widget"
        }
    }

    private var subtitle: String {
        switch mode {
        case .homeScreen: return "See personalized prayers and verses\nevery time you unlock your phone."
        case .lockScreen: return "Glance at daily verses right\nfrom your Lock Screen."
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // Header
                VStack(spacing: 10) {
                    Text(title)
                        .font(BPFont.headingMedium)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(BPFont.reference)
                        .foregroundStyle(palette.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

                Spacer().frame(height: 32)

                // Step-by-step carousel
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepCard(index: index, step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 300)

                // Custom capsule page indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(currentStep == index ? palette.accent : palette.accent.opacity(0.2))
                            .frame(width: currentStep == index ? 20 : 7, height: 7)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentStep)
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                }
            }
            .onAppear {
                withAnimation(BPAnimation.spring.delay(0.2)) {
                    showContent = true
                }
            }
        }
    }

    // MARK: - Step Card

    private func stepCard(index: Int, step: (icon: String, title: String, description: String)) -> some View {
        VStack(spacing: 24) {
            // Icon with glow circle
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(palette.surfaceElevated)
                    .frame(width: 88, height: 88)
                    .shadow(color: palette.accent.opacity(0.12), radius: 8, y: 4)
                    .overlay(
                        Circle()
                            .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
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
    }
}
