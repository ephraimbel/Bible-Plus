import SwiftUI

struct SelectionCard: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.bpPalette) private var palette

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.04))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(palette.accent.opacity(0.08))
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? palette.accent : palette.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? palette.accent.opacity(0.06)
                            : palette.surfaceElevated
                    )
                    .shadow(
                        color: isSelected
                            ? palette.accent.opacity(0.1)
                            : .black.opacity(0.04),
                        radius: isSelected ? 12 : 10,
                        y: isSelected ? 6 : 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? palette.accent : palette.border.opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}

// MARK: - Compact Selection Card (for grid layouts)

struct CompactSelectionCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.bpPalette) private var palette

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.04))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(palette.accent.opacity(0.08))
                        )
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? palette.accent : palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? palette.accent.opacity(0.06)
                            : palette.surfaceElevated
                    )
                    .shadow(
                        color: isSelected
                            ? palette.accent.opacity(0.1)
                            : .black.opacity(0.04),
                        radius: isSelected ? 12 : 10,
                        y: isSelected ? 6 : 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? palette.accent : palette.border.opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
