import SwiftUI

struct TranslationPreviewCard: View {
    let translation: BibleTranslation
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(translation.displayName)
                        .font(BPFont.headingSmall)
                        .foregroundStyle(
                            isSelected ? .white : BPColorPalette.light.textPrimary
                        )

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }

                Text(translation.subtitle)
                    .font(BPFont.reference)
                    .foregroundStyle(
                        isSelected ? .white.opacity(0.7) : BPColorPalette.light.textMuted
                    )

                Divider()
                    .overlay(
                        isSelected
                            ? Color.white.opacity(0.2) : BPColorPalette.light.border
                    )

                Text(translation.john316)
                    .font(BPFont.bibleSmall)
                    .foregroundStyle(
                        isSelected ? .white.opacity(0.9) : BPColorPalette.light.textSecondary
                    )
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("John 3:16")
                    .font(BPFont.reference)
                    .foregroundStyle(
                        isSelected ? .white.opacity(0.6) : BPColorPalette.light.textMuted
                    )
            }
            .padding(20)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected
                            ? BPColorPalette.light.accent : BPColorPalette.light.surfaceElevated
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : BPColorPalette.light.border,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? BPColorPalette.light.accent.opacity(0.3) : Color.black.opacity(0.05),
                radius: isSelected ? 12 : 4,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
