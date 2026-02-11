import SwiftUI

struct TranslationPreviewCard: View {
    let translation: BibleTranslation
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.bpPalette) private var palette

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
                            isSelected ? .white : palette.textPrimary
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
                        isSelected ? .white.opacity(0.7) : palette.textMuted
                    )

                Divider()
                    .overlay(
                        isSelected
                            ? Color.white.opacity(0.2) : palette.border
                    )

                Text(translation.john316)
                    .font(BPFont.bibleSmall)
                    .foregroundStyle(
                        isSelected ? .white.opacity(0.9) : palette.textSecondary
                    )
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("John 3:16")
                    .font(BPFont.reference)
                    .foregroundStyle(
                        isSelected ? .white.opacity(0.6) : palette.textMuted
                    )
            }
            .padding(20)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected
                            ? palette.accent : palette.surfaceElevated
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : palette.border,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? palette.accent.opacity(0.3) : Color.black.opacity(0.05),
                radius: isSelected ? 12 : 4,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
