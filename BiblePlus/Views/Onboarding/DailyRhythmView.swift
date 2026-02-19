import SwiftUI

struct DailyRhythmView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                Text(viewModel.firstName.isEmpty
                    ? "When would you like\nto hear from God?"
                    : "When would you like\nto hear from God, \(viewModel.firstName)?")
                    .font(BPFont.onboardingHeading)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We'll send you a gentle reminder\nwith a personalized prayer or verse.")
                    .font(BPFont.onboardingBody)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 28)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(PrayerTimeSlot.allCases.enumerated()), id: \.element) { index, slot in
                        TimeToggleRow(
                            slot: slot,
                            isSelected: viewModel.selectedPrayerTimes.contains(slot),
                            userName: viewModel.firstName,
                            action: { viewModel.togglePrayerTime(slot) }
                        )
                        .opacity(showContent ? 1 : 0)
                        .animation(BPAnimation.staggered(index: index), value: showContent)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 16)

            VStack(spacing: 8) {
                Text("You can skip this and set it up later.")
                    .font(BPFont.onboardingBody)
                    .foregroundStyle(palette.textSecondary)

                GoldButton(
                    title: "Continue",
                    action: { viewModel.goNext() }
                )
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
