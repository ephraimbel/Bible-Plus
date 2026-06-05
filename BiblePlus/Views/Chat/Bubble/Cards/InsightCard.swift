import SwiftUI

struct InsightCard: View {
    let text: String

    @Environment(\.bpPalette) private var palette

    var body: some View {
        // A compact, left-accented pull-quote that flows with the document
        // instead of a tall centered box — distinct and premium, far less space.
        VStack(alignment: .leading, spacing: 5) {
            Text("KEY INSIGHT")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(palette.accent.opacity(0.75))

            Text(text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 14)
        // The gold rule is an overlay so it hugs the text's height exactly
        // rather than stretching the row.
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(palette.accent.opacity(0.55))
                .frame(width: 2.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}
