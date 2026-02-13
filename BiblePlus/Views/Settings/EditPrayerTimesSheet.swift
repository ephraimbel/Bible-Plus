import SwiftUI

struct EditPrayerTimesSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Choose when you'd like to hear from us")
                        .font(BPFont.reference)
                        .foregroundStyle(palette.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.bottom, 4)

                    ForEach(PrayerTimeSlot.allCases) { slot in
                        TimeToggleRow(
                            slot: slot,
                            isSelected: vm.editingPrayerTimes.contains(slot),
                            userName: vm.profile.firstName.isEmpty ? "Friend" : vm.profile.firstName,
                            action: { vm.togglePrayerTime(slot) }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Prayer Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(palette.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.savePrayerTimes()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accent)
                }
            }
            .background(palette.background)
            .toolbarBackground(palette.background, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.background)
    }
}
