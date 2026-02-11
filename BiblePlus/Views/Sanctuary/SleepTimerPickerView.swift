import SwiftUI

struct SleepTimerPickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Active timer status
                if let formatted = vm.sleepTimerFormatted {
                    VStack(spacing: 6) {
                        Text("Timer Active")
                            .font(BPFont.button)
                            .foregroundStyle(.secondary)
                        Text(formatted)
                            .font(BPFont.headingSmall)
                            .foregroundStyle(palette.accent)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 20)
                }

                // Duration options
                List {
                    ForEach(SleepTimerDuration.allCases) { duration in
                        Button {
                            HapticService.selection()
                            vm.startSleepTimer(duration)
                            dismiss()
                        } label: {
                            HStack {
                                Text(duration.displayName)
                                    .font(BPFont.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if vm.sleepTimer == duration {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(palette.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Cancel timer
                    if vm.sleepTimer != nil {
                        Button(role: .destructive) {
                            vm.cancelSleepTimer()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Cancel Timer")
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(palette.background)
                .listRowBackground(palette.surface)
            }
            .background(palette.background)
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationBackground(palette.background)
    }
}
