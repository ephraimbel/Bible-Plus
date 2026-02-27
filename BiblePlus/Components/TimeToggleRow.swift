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
                    // Icon in circle
                    Image(systemName: slot.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? .white : palette.accent)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(
                                    isSelected
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [palette.accent, palette.accent.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        : AnyShapeStyle(palette.accent.opacity(0.08))
                                )
                                .shadow(
                                    color: isSelected ? palette.accent.opacity(0.3) : .clear,
                                    radius: 4, y: 2
                                )
                        )

                    // Labels
                    VStack(alignment: .leading, spacing: 3) {
                        Text(slot.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Text(slot.timeRange)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }

                    Spacer()

                    // Toggle circle
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ? palette.accent : palette.border.opacity(0.4),
                                lineWidth: isSelected ? 0 : 1.5
                            )
                            .frame(width: 26, height: 26)

                        if isSelected {
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
                    }
                }
                .padding(16)

                // Notification preview (shown when selected)
                if isSelected {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(palette.accent)

                        Text(slot.notificationPreview(name: userName))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .italic()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .padding(.leading, 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(
                        color: isSelected
                            ? palette.accent.opacity(0.1)
                            : .black.opacity(0.04),
                        radius: isSelected ? 8 : 4,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? palette.accent.opacity(0.3) : palette.border.opacity(0.15),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
