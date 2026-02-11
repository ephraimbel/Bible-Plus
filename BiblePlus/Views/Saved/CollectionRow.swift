import SwiftUI

struct CollectionRow: View {
    let collection: ContentCollection
    @Environment(\.bpPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 20))
                .foregroundStyle(palette.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(BPFont.body)
                    .foregroundStyle(palette.textPrimary)

                Text("\(collection.contentIDs.count) items")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.vertical, 4)
    }
}
