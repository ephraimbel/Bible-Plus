import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
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
                Text("Collections").tag(SavedTab.collections)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            switch viewModel.selectedTab {
            case .favorites:
                favoritesTab
            case .collections:
                collectionsTab
            }
        }
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
                    for index in offsets {
                        viewModel.unsave(items[index])
                    }
                }
            }
            .listStyle(.insetGrouped)
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
                    for index in offsets {
                        viewModel.deleteCollection(items[index])
                    }
                }
            }
            .listStyle(.insetGrouped)
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
    }
}
