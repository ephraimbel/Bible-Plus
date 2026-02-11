import SwiftUI

struct TimeToggleRow: View {
    let slot: PrayerTimeSlot
    let isSelected: Bool
    let userName: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    // Icon
                    Image(systemName: slot.icon)
                        .font(.title2)
                        .foregroundStyle(
                            isSelected ? BPColorPalette.light.accent : BPColorPalette.light.textMuted
                        )
                        .frame(width: 36)

                    // Labels
                    VStack(alignment: .leading, spacing: 3) {
                        Text(slot.displayName)
                            .font(BPFont.button)
                            .foregroundStyle(BPColorPalette.light.textPrimary)

                        Text(slot.timeRange)
                            .font(BPFont.reference)
                            .foregroundStyle(BPColorPalette.light.textMuted)
                    }

                    Spacer()

                    // Toggle circle
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ? BPColorPalette.light.accent : BPColorPalette.light.border,
                                lineWidth: 2
                            )
                            .frame(width: 28, height: 28)

                        if isSelected {
                            Circle()
                                .fill(BPColorPalette.light.accent)
                                .frame(width: 28, height: 28)

                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)

                // Notification preview (shown when selected)
                if isSelected {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(BPColorPalette.light.accent)

                        Text(slot.notificationPreview(name: userName))
                            .font(BPFont.reference)
                            .foregroundStyle(BPColorPalette.light.textSecondary)
                            .italic()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .padding(.leading, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(BPColorPalette.light.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? BPColorPalette.light.accent.opacity(0.5) : BPColorPalette.light.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
