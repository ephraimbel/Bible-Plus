import SwiftUI

struct SavedContentRow: View {
    let content: PrayerContent
    let displayText: String

    var body: some View {
        HStack(spacing: 12) {
            // Type badge
            Image(systemName: typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BPColorPalette.light.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayText)
                    .font(BPFont.body)
                    .foregroundStyle(BPColorPalette.light.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(content.type.displayName)
                        .font(BPFont.caption)
                        .foregroundStyle(BPColorPalette.light.textMuted)

                    if let ref = content.verseReference, !ref.isEmpty {
                        Text("·")
                            .foregroundStyle(BPColorPalette.light.textMuted)
                        Text(ref)
                            .font(BPFont.caption)
                            .foregroundStyle(BPColorPalette.light.textMuted)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var typeIcon: String {
        switch content.type {
        case .prayer: "hands.sparkles"
        case .verse: "book.closed"
        case .devotional: "text.book.closed"
        case .quote: "quote.opening"
        case .guidedPrayer: "figure.mind.and.body"
        case .reflection: "bubble.left.and.text.bubble.right"
        }
    }
}
