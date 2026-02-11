import SwiftUI

struct SelectionCard: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : BPColorPalette.light.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(BPFont.button)
                        .foregroundStyle(isSelected ? .white : BPColorPalette.light.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(BPFont.reference)
                            .foregroundStyle(
                                isSelected
                                    ? .white.opacity(0.8) : BPColorPalette.light.textSecondary
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
                            ? BPColorPalette.light.accent : BPColorPalette.light.surfaceElevated
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : BPColorPalette.light.border,
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

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : BPColorPalette.light.accent)

                Text(title)
                    .font(BPFont.caption)
                    .foregroundStyle(isSelected ? .white : BPColorPalette.light.textPrimary)
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
                            ? BPColorPalette.light.accent : BPColorPalette.light.surfaceElevated
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.clear : BPColorPalette.light.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
