import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Saved")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
            }
        }
    }
}

// MARK: - Inner Content View

private struct SavedContentView: View {
    @Bindable var viewModel: SavedViewModel
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            tabBar

            // Content
            switch viewModel.selectedTab {
            case .favorites:
                favoritesTab
            case .verses:
                versesTab
            case .collections:
                collectionsTab
            }
        }
        .background(palette.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("Favorites", icon: "heart.fill", tab: .favorites)
            tabButton("Verses", icon: "bookmark.fill", tab: .verses)
            tabButton("Collections", icon: "folder.fill", tab: .collections)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surface)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func tabButton(_ title: String, icon: String, tab: SavedTab) -> some View {
        let isSelected = viewModel.selectedTab == tab

        return Button {
            withAnimation(BPAnimation.spring) {
                viewModel.selectedTab = tab
            }
            HapticService.selection()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? palette.accent : Color.clear)
            )
        }
    }

    // MARK: - Favorites Tab

    @ViewBuilder
    private var favoritesTab: some View {
        let items = viewModel.favorites
        if items.isEmpty {
            emptyState(
                icon: "heart",
                title: "No Favorites Yet",
                message: "Double-tap or heart any card\nin the feed to save it here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                // Summary
                summaryBar(
                    icon: "heart.fill",
                    text: "\(items.count) saved \(items.count == 1 ? "item" : "items")"
                )

                LazyVStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, content in
                        SavedFavoriteCard(
                            content: content,
                            displayText: viewModel.personalizedText(for: content),
                            palette: palette,
                            onUnsave: { viewModel.unsave(content) }
                        )
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(BPAnimation.spring.delay(0.1 + Double(min(index, 8)) * 0.03), value: appeared)
                    }
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Verses Tab

    @ViewBuilder
    private var versesTab: some View {
        let items = viewModel.savedVerses
        if items.isEmpty {
            emptyState(
                icon: "book.closed",
                title: "No Saved Verses Yet",
                message: "Tap any verse in the Bible reader\nand save it to find it here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                summaryBar(
                    icon: "bookmark.fill",
                    text: "\(items.count) saved \(items.count == 1 ? "verse" : "verses")"
                )

                LazyVStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, verse in
                        SavedVerseCard(
                            verse: verse,
                            palette: palette,
                            onDelete: { viewModel.deleteSavedVerse(verse) }
                        )
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(BPAnimation.spring.delay(0.1 + Double(min(index, 8)) * 0.03), value: appeared)
                    }
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Collections Tab

    @ViewBuilder
    private var collectionsTab: some View {
        let items = viewModel.collections
        if items.isEmpty {
            emptyState(
                icon: "folder",
                title: "No Collections Yet",
                message: "Pin content from the feed to\norganize it into collections."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                summaryBar(
                    icon: "folder.fill",
                    text: "\(items.count) \(items.count == 1 ? "collection" : "collections")"
                )

                LazyVStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, collection in
                        NavigationLink {
                            CollectionDetailView(
                                collection: collection,
                                viewModel: viewModel
                            )
                        } label: {
                            CollectionCard(collection: collection, palette: palette)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(BPAnimation.spring.delay(0.1 + Double(min(index, 8)) * 0.03), value: appeared)
                    }
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Summary Bar

    private func summaryBar(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.accent)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.05), value: appeared)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 36, weight: .thin))
                    .foregroundStyle(palette.accent)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(BPAnimation.spring.delay(0.1), value: appeared)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text(message)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
            .animation(BPAnimation.spring.delay(0.2), value: appeared)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Saved Favorite Card

private struct SavedFavoriteCard: View {
    let content: PrayerContent
    let displayText: String
    let palette: BPColorPalette
    let onUnsave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Type + reference row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: typeIcon)
                        .font(.system(size: 10, weight: .medium))
                    Text(content.type.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(palette.accent.opacity(0.1))
                )

                Spacer()

                if let ref = content.verseReference, !ref.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 9))
                        Text(ref)
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                    }
                    .foregroundStyle(palette.accent)
                }
            }

            // Content text
            Text(displayText)
                .font(.system(size: 15, weight: .regular, design: content.type == .verse ? .serif : .rounded))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(3)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
        .contextMenu {
            Button(role: .destructive) {
                onUnsave()
                HapticService.notification(.warning)
            } label: {
                Label("Remove from Favorites", systemImage: "heart.slash")
            }
        }
    }

    private var typeIcon: String {
        switch content.type {
        case .prayer: "hands.sparkles"
        case .verse: "book.closed"
        case .devotional: "text.book.closed"
        case .quote: "quote.opening"
        case .reflection: "bubble.left.and.text.bubble.right"
        }
    }
}

// MARK: - Saved Verse Card

private struct SavedVerseCard: View {
    let verse: SavedBibleVerse
    let palette: BPColorPalette
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Reference + translation row
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(
                            verse.highlightColor.map { Color(hex: $0.dotColor) }
                                ?? palette.accent
                        )

                    Text("\(verse.bookName) \(verse.chapter):\(verse.verseNumber)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }

                Spacer()

                Text(verse.translation)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(palette.surface)
                    )
            }

            // Verse text
            Text(verse.text)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(3)
                .lineSpacing(4)

            // Notes
            if !verse.notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.accent.opacity(0.6))
                        .padding(.top, 2)

                    Text(verse.notes)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                        .italic()
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
        // Left accent with highlight color
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(
                verse.highlightColor.map { Color(hex: $0.dotColor) }
                    ?? palette.accent.opacity(0.4)
            )
            .frame(width: 3)
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
                HapticService.notification(.warning)
            } label: {
                Label("Delete Verse", systemImage: "trash")
            }
        }
    }
}

// MARK: - Collection Card

private struct CollectionCard: View {
    let collection: ContentCollection
    let palette: BPColorPalette

    var body: some View {
        HStack(spacing: 14) {
            // Folder icon with accent background
            Image(systemName: "folder.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(collection.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("\(collection.contentIDs.count) \(collection.contentIDs.count == 1 ? "item" : "items")")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
    }
}
