import SwiftUI

struct ConversationRow: View {
    let title: String
    let preview: String
    let date: Date
    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(BPFont.button)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(date, style: .relative)
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
            }

            Text(preview)
                .font(BPFont.caption)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}
