import SwiftUI

struct CollectionRow: View {
    let collection: ContentCollection

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 20))
                .foregroundStyle(BPColorPalette.light.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(BPFont.body)
                    .foregroundStyle(BPColorPalette.light.textPrimary)

                Text("\(collection.contentIDs.count) items")
                    .font(BPFont.caption)
                    .foregroundStyle(BPColorPalette.light.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BPColorPalette.light.textMuted)
        }
        .padding(.vertical, 4)
    }
}
