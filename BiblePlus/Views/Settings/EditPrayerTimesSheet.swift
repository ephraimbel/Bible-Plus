import SwiftUI

struct EditPrayerTimesSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("When do you want to pray?")
                    .font(BPFont.headingSmall)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                ForEach(PrayerTimeSlot.allCases) { slot in
                    TimeToggleRow(
                        slot: slot,
                        isSelected: vm.editingPrayerTimes.contains(slot),
                        userName: vm.profile.firstName.isEmpty ? "Friend" : vm.profile.firstName,
                        action: { vm.togglePrayerTime(slot) }
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Prayer Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.savePrayerTimes()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accent)
                }
            }
        }
    }
}
