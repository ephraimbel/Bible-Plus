import SwiftUI

struct TimeToggleRow: View {
    let slot: PrayerTimeSlot
    let isSelected: Bool
    let userName: String
    let action: () -> Void
    @Environment(\.bpPalette) private var palette

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
                            isSelected ? palette.accent : palette.textMuted
                        )
                        .frame(width: 36)

                    // Labels
                    VStack(alignment: .leading, spacing: 3) {
                        Text(slot.displayName)
                            .font(BPFont.button)
                            .foregroundStyle(palette.textPrimary)

                        Text(slot.timeRange)
                            .font(BPFont.reference)
                            .foregroundStyle(palette.textMuted)
                    }

                    Spacer()

                    // Toggle circle
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ? palette.accent : palette.border,
                                lineWidth: 2
                            )
                            .frame(width: 28, height: 28)

                        if isSelected {
                            Circle()
                                .fill(palette.accent)
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
                            .foregroundStyle(palette.accent)

                        Text(slot.notificationPreview(name: userName))
                            .font(BPFont.reference)
                            .foregroundStyle(palette.textSecondary)
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
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? palette.accent.opacity(0.5) : palette.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
