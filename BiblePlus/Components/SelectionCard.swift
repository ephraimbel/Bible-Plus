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
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : palette.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(BPFont.button)
                        .foregroundStyle(isSelected ? .white : palette.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(BPFont.reference)
                            .foregroundStyle(
                                isSelected
                                    ? .white.opacity(0.8) : palette.textSecondary
                            )
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? palette.accent : palette.surfaceElevated
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : palette.border,
                        lineWidth: 1
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
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : palette.accent)

                Text(title)
                    .font(BPFont.caption)
                    .foregroundStyle(isSelected ? .white : palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? palette.accent : palette.surfaceElevated
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : palette.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
