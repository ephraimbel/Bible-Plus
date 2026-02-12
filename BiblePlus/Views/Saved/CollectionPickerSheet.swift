import SwiftUI
import SwiftData

struct CollectionPickerSheet: View {
    let content: PrayerContent
    let isPro: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Query(sort: \ContentCollection.updatedAt, order: .reverse)
    private var collections: [ContentCollection]

    @State private var showNewCollectionAlert = false
    @State private var newCollectionName = ""
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    emptyState
                } else {
                    collectionList
                }
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        handleNewCollection()
                    } label: {
                        Label("New Collection", systemImage: "plus.circle.fill")
                            .foregroundStyle(palette.accent)
                    }
                }
            }
            .alert("New Collection", isPresented: $showNewCollectionAlert) {
                TextField("Collection name", text: $newCollectionName)
                Button("Cancel", role: .cancel) {
                    newCollectionName = ""
                }
                Button("Create") {
                    createCollection()
                }
            } message: {
                Text("Enter a name for your collection.")
            }
            .sheet(isPresented: $showPaywall) {
                SummaryPaywallView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("No Collections Yet")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text("Create a collection to organize\nyour favorite content.")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Button {
                handleNewCollection()
            } label: {
                Label("Create Collection", systemImage: "plus.circle.fill")
                    .font(BPFont.button)
                    .foregroundStyle(palette.accent)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    // MARK: - Collection List

    private var collectionList: some View {
        List {
            ForEach(collections) { collection in
                collectionRow(for: collection)
            }
            .onDelete(perform: deleteCollections)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .listRowBackground(palette.surface)
    }

    private func collectionRow(for collection: ContentCollection) -> some View {
        let isInCollection = collection.contentIDs.contains(content.id)

        return Button {
            toggleContent(in: collection)
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(BPFont.body)
                        .foregroundStyle(palette.textPrimary)
                    Text("\(collection.contentIDs.count) items")
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                if isInCollection {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleNewCollection() {
        if !isPro && collections.count >= 1 {
            showPaywall = true
        } else {
            newCollectionName = ""
            showNewCollectionAlert = true
        }
    }

    private func createCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let collection = ContentCollection(name: name, contentIDs: [content.id])
        modelContext.insert(collection)
        try? modelContext.save()
        newCollectionName = ""
        HapticService.success()
    }

    private func toggleContent(in collection: ContentCollection) {
        if let index = collection.contentIDs.firstIndex(of: content.id) {
            collection.contentIDs.remove(at: index)
        } else {
            collection.contentIDs.append(content.id)
        }
        collection.updatedAt = Date()
        try? modelContext.save()
        HapticService.selection()
    }

    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(collections[index])
        }
        try? modelContext.save()
    }
}
