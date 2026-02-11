import SwiftUI

struct SleepTimerPickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss

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
                            .foregroundStyle(Color(hex: "C9A96E"))
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
                                        .foregroundStyle(Color(hex: "C9A96E"))
                                }
                            }
                        }
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
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "C9A96E"))
                }
            }
        }
    }
}
