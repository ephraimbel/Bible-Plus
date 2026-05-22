import SwiftUI

struct OriginalWordCard: View {
    let word: String
    let language: String
    let transliteration: String
    let meaning: String

    @Environment(\.bpPalette) private var palette

    private var languageLabel: String {
        language.isEmpty ? "ORIGINAL LANGUAGE" : language.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.8))
                Text(languageLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(palette.accent.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(word)
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !transliteration.isEmpty {
                    Text(transliteration)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textMuted.opacity(0.85))
                }
            }

            Rectangle()
                .fill(palette.accent.opacity(0.25))
                .frame(width: 36, height: 1)

            Text(meaning)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surfaceElevated.opacity(0.55),
                            palette.surfaceElevated.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.vertical, 6)
    }
}
