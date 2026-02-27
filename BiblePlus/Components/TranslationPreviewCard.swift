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
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.25))
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(translation.subtitle)
                    .font(BPFont.reference)
                    .foregroundStyle(
                        isSelected ? .white.opacity(0.7) : palette.textMuted
                    )

                Rectangle()
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.15)
                            : palette.border.opacity(0.12)
                    )
                    .frame(height: 0.5)

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
                            : .black.opacity(0.05),
                        radius: isSelected ? 14 : 10,
                        y: isSelected ? 6 : 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : palette.border.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }
}
