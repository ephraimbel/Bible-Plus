import SwiftUI

struct DailyRhythmView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                Text("When would you like\nto hear from God, \(viewModel.firstName)?")
                    .font(BPFont.headingMedium)
                    .foregroundStyle(BPColorPalette.light.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We'll send you a gentle reminder\nwith a personalized prayer or verse.")
                    .font(BPFont.reference)
                    .foregroundStyle(BPColorPalette.light.textMuted)
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
            withAnimation {
                showContent = true
            }
        }
    }
}
