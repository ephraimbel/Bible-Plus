import SwiftUI

struct CollectionDetailView: View {
    let collection: ContentCollection
    let viewModel: SavedViewModel

    var body: some View {
        Group {
            let items = viewModel.contentsForCollection(collection)
            if items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(items) { content in
                        SavedContentRow(
                            content: content,
                            displayText: content.templateText
                        )
                    }
                    .onDelete { offsets in
                        deleteItems(at: offsets, from: items)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(BPColorPalette.light.accent)

            Text("Empty Collection")
                .font(BPFont.headingSmall)
                .foregroundStyle(BPColorPalette.light.textPrimary)

            Text("Pin content from the feed\nto add it here.")
                .font(BPFont.body)
                .foregroundStyle(BPColorPalette.light.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func deleteItems(at offsets: IndexSet, from items: [PrayerContent]) {
        for index in offsets {
            viewModel.removeFromCollection(items[index], collection: collection)
        }
    }
}
