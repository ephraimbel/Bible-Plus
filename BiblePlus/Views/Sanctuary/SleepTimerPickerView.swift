import SwiftUI

struct SleepTimerPickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Active timer status
                    if let formatted = vm.sleepTimerFormatted {
                        VStack(spacing: 8) {
                            // Double-layer icon ring
                            ZStack {
                                Circle()
                                    .fill(palette.accent.opacity(0.04))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(palette.accent)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(palette.accent.opacity(0.08))
                                    )
                            }

                            Text("TIMER ACTIVE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(palette.textMuted)

                            Text(formatted)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.accent)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(palette.surfaceElevated)
                                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
                        )
                    }

                    // Duration options
                    VStack(spacing: 0) {
                        ForEach(Array(SleepTimerDuration.allCases.enumerated()), id: \.element.id) { index, duration in
                            let isActive = vm.sleepTimer == duration

                            Button {
                                HapticService.selection()
                                vm.startSleepTimer(duration)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    // Double-layer icon ring
                                    ZStack {
                                        Circle()
                                            .fill(palette.accent.opacity(isActive ? 0.12 : 0.04))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: iconForDuration(duration))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(isActive ? .white : palette.accent)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(
                                                        isActive
                                                            ? AnyShapeStyle(
                                                                LinearGradient(
                                                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                                                    startPoint: .topLeading,
                                                                    endPoint: .bottomTrailing
                                                                )
                                                            )
                                                            : AnyShapeStyle(palette.accent.opacity(0.08))
                                                    )
                                            )
                                    }

                                    Text(duration.displayName)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(palette.textPrimary)

                                    Spacer()

                                    if isActive {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [palette.accent, palette.accent.opacity(0.85)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 26, height: 26)
                                                .shadow(color: palette.accent.opacity(0.25), radius: 3, y: 1)

                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(palette.textMuted.opacity(0.4))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < SleepTimerDuration.allCases.count - 1 {
                                Rectangle()
                                    .fill(palette.border.opacity(0.12))
                                    .frame(height: 0.5)
                                    .padding(.leading, 66)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
                    )

                    // Cancel timer
                    if vm.sleepTimer != nil {
                        Button {
                            vm.cancelSleepTimer()
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Cancel Timer")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Sleep Timer")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationBackground(palette.background)
    }

    private func iconForDuration(_ duration: SleepTimerDuration) -> String {
        switch duration {
        case .fifteenMin: "clock.badge.fill"
        case .thirtyMin: "clock"
        case .oneHour: "clock.fill"
        case .twoHours: "timer"
        case .untilClose: "moon.stars"
        }
    }
}
