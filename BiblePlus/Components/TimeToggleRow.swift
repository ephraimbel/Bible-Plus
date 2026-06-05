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
                HStack(spacing: 12) {
                    // Text-forward labels — no icon gem. The moment name in serif
                    // with its clock window in gold, matching the library/onboarding.
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(slot.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(palette.textPrimary)

                        Text(slot.timeRange)
                            .font(.system(size: 11.5, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(palette.accent)
                    }

                    Spacer()

                    // Selection check — gold fill with a white check when on.
                    ZStack {
                        Circle()
                            .fill(isSelected ? palette.accent : Color.clear)
                        Circle()
                            .strokeBorder(isSelected ? Color.clear : palette.border.opacity(0.55), lineWidth: 1.5)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .padding(16)

                // Notification preview (shown when selected) — quiet italic line.
                if isSelected {
                    Text(slot.notificationPreview(name: userName))
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
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
