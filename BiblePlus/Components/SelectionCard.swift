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
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? .white : palette.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                    ? Color.white.opacity(0.2)
                                    : palette.accent.opacity(0.08)
                            )
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : palette.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(
                                isSelected
                                    ? .white.opacity(0.8) : palette.textSecondary
                            )
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.25))
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(palette.surfaceElevated)
                    )
                    .shadow(
                        color: isSelected
                            ? palette.accent.opacity(0.3)
                            : .black.opacity(0.04),
                        radius: isSelected ? 8 : 4,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : palette.border.opacity(0.15),
                        lineWidth: 0.5
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
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? .white : palette.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                    ? Color.white.opacity(0.2)
                                    : palette.accent.opacity(0.08)
                            )
                    )

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : palette.textPrimary)
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
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(palette.surfaceElevated)
                    )
                    .shadow(
                        color: isSelected
                            ? palette.accent.opacity(0.3)
                            : .black.opacity(0.04),
                        radius: isSelected ? 8 : 4,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : palette.border.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
