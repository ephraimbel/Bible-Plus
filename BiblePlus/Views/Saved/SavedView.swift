import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @State private var viewModel: SavedViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    SavedContentView(viewModel: vm)
                } else {
                    BPLoadingView().onAppear {
                        viewModel = SavedViewModel(modelContext: modelContext)
                    }
                }
            }
            .navigationTitle("Saved")
            .toolbarBackground(palette.background, for: .navigationBar)
        }
    }
}

// MARK: - Inner Content View

private struct SavedContentView: View {
    @Bindable var viewModel: SavedViewModel
    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $viewModel.selectedTab) {
                Text("Favorites").tag(SavedTab.favorites)
                Text("Verses").tag(SavedTab.verses)
                Text("Collections").tag(SavedTab.collections)
                Text("Journal").tag(SavedTab.journal)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .sensoryFeedback(.selection, trigger: viewModel.selectedTab)

            switch viewModel.selectedTab {
            case .favorites:
                favoritesTab
            case .verses:
                versesTab
            case .collections:
                collectionsTab
            case .journal:
                JournalTabView(viewModel: viewModel)
            }
        }
        .background(palette.background)
    }

    // MARK: - Favorites Tab

    @ViewBuilder
    private var favoritesTab: some View {
        let items = viewModel.favorites
        if items.isEmpty {
            emptyFavorites
        } else {
            List {
                ForEach(items) { content in
                    SavedContentRow(
                        content: content,
                        displayText: viewModel.personalizedText(for: content)
                    )
                }
                .onDelete { offsets in
                    HapticService.notification(.warning)
                    for index in offsets {
                        viewModel.unsave(items[index])
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .listRowBackground(palette.surface)
        }
    }

    private var emptyFavorites: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "heart")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("No Favorites Yet")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text("Double-tap or heart any card\nin the feed to save it here.")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    // MARK: - Verses Tab

    @ViewBuilder
    private var versesTab: some View {
        let items = viewModel.savedVerses
        if items.isEmpty {
            emptyVerses
        } else {
            List {
                ForEach(items) { verse in
                    savedVerseRow(verse)
                }
                .onDelete { offsets in
                    HapticService.notification(.warning)
                    for index in offsets {
                        viewModel.deleteSavedVerse(items[index])
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .listRowBackground(palette.surface)
        }
    }

    private func savedVerseRow(_ verse: SavedBibleVerse) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14))
                .foregroundStyle(
                    verse.highlightColor.map { Color(hex: $0.dotColor) }
                        ?? palette.accent
                )
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(verse.bookName) \(verse.chapter):\(verse.verseNumber)")
                        .font(BPFont.button)
                        .foregroundStyle(palette.textPrimary)

                    Spacer()

                    Text(verse.translation)
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(palette.surface)
                        )
                }

                Text(verse.text)
                    .font(BPFont.body)
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(2)

                if !verse.notes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.accent.opacity(0.7))
                        Text(verse.notes)
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)
                            .italic()
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyVerses: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("No Saved Verses Yet")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text("Tap any verse in the Bible reader\nand save it to find it here.")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    // MARK: - Collections Tab

    @ViewBuilder
    private var collectionsTab: some View {
        let items = viewModel.collections
        if items.isEmpty {
            emptyCollections
        } else {
            List {
                ForEach(items) { collection in
                    NavigationLink {
                        CollectionDetailView(
                            collection: collection,
                            viewModel: viewModel
                        )
                    } label: {
                        CollectionRow(collection: collection)
                    }
                }
                .onDelete { offsets in
                    HapticService.notification(.warning)
                    for index in offsets {
                        viewModel.deleteCollection(items[index])
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .listRowBackground(palette.surface)
        }
    }

    private var emptyCollections: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("No Collections Yet")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text("Pin content from the feed\nto organize it into collections.")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}
