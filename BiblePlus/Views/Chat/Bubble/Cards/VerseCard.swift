import SwiftUI

struct VerseCard: View {
    let quote: String
    let reference: String
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("\u{201C}")
                .font(.system(size: 44, weight: .bold, design: .serif))
                .foregroundStyle(palette.accent.opacity(0.12))
                .offset(x: 8, y: -2)

            VStack(alignment: .leading, spacing: 10) {
                Text(quote)
                    .font(.custom("Georgia", size: 17))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(6)
                    .italic()

                if !reference.isEmpty {
                    BubbleReferenceButton(reference: reference, onScriptureTap: onScriptureTap)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                }
            }
            .padding(16)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.07), palette.accent.opacity(0.02), palette.accent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: palette.accent.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
    }
}
