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
    @Namespace private var tabNamespace
    @State private var appeared = false

    // SwiftData @Query observes the store and re-renders the view the
    // moment a saved item flips `isSaved`, gets deleted, or has its
    // note cleared — no need to navigate away and back. Previously these
    // lists came from `viewModel.favorites`/etc. (computed properties
    // that re-fetched on access), which SwiftUI couldn't observe, so
    // save/unsave changes only appeared on a fresh tab mount.
    @Query(
        filter: #Predicate<PrayerContent> { $0.isSaved == true },
        sort: \PrayerContent.createdAt,
        order: .reverse
    )
    private var favorites: [PrayerContent]

    @Query(sort: \SavedBibleVerse.createdAt, order: .reverse)
    private var savedVerses: [SavedBibleVerse]

    @Query(
        filter: #Predicate<SavedBibleVerse> { $0.notes != "" },
        sort: \SavedBibleVerse.updatedAt,
        order: .reverse
    )
    private var notedVerses: [SavedBibleVerse]

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            tabBar

            // Content
            Group {
                switch viewModel.selectedTab {
                case .favorites:
                    favoritesTab
                case .verses:
                    versesTab
                case .notes:
                    notesTab
                }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
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
            tabButton("Notes", icon: "note.text", tab: .notes)
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
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(palette.accent)
                        .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                }
            }
        }
    }

    // MARK: - Favorites Tab

    @ViewBuilder
    private var favoritesTab: some View {
        let items = favorites
        if items.isEmpty {
            emptyState(
                icon: "heart",
                accentIcon: "heart.fill",
                title: "No Favorites Yet",
                message: "Double-tap any card in the feed\nto save it here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                summaryBar(
                    icon: "heart.fill",
                    text: "\(items.count) saved \(items.count == 1 ? "item" : "items")"
                )

                LazyVStack(spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, content in
                        Button {
                            // If this saved item came from an AI chat, jump
                            // back to the original conversation (and message,
                            // if we have it). Older saves without source IDs
                            // fall through to the legacy feed-sheet path.
                            if let convId = content.sourceConversationId {
                                var userInfo: [String: Any] = [
                                    "conversationId": convId.uuidString
                                ]
                                if let msgId = content.sourceMessageId {
                                    userInfo["messageId"] = msgId.uuidString
                                }
                                NotificationCenter.default.post(
                                    name: .navigateToConversation,
                                    object: nil,
                                    userInfo: userInfo
                                )
                            } else {
                                NotificationCenter.default.post(
                                    name: .feedContentDeepLink,
                                    object: nil,
                                    userInfo: ["contentID": content.id]
                                )
                            }
                            HapticService.lightImpact()
                        } label: {
                            SavedFavoriteCard(
                                content: content,
                                displayText: viewModel.personalizedText(for: content),
                                palette: palette,
                                onUnsave: { viewModel.unsave(content) }
                            )
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

    // MARK: - Verses Tab

    @ViewBuilder
    private var versesTab: some View {
        let items = savedVerses
        if items.isEmpty {
            emptyState(
                icon: "book.closed",
                accentIcon: "bookmark.fill",
                title: "No Saved Verses Yet",
                message: "Tap any verse in the Bible reader\nand save it to find it here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                summaryBar(
                    icon: "bookmark.fill",
                    text: "\(items.count) saved \(items.count == 1 ? "verse" : "verses")"
                )

                LazyVStack(spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, verse in
                        Button {
                            NotificationCenter.default.post(
                                name: .scriptureDeepLink,
                                object: nil,
                                userInfo: [
                                    "bookName": verse.bookName,
                                    "chapter": verse.chapter,
                                    "verse": verse.verseNumber
                                ]
                            )
                            HapticService.lightImpact()
                        } label: {
                            SavedVerseCard(
                                verse: verse,
                                palette: palette,
                                colorScheme: colorScheme,
                                onDelete: { viewModel.deleteSavedVerse(verse) }
                            )
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

    // MARK: - Notes Tab

    @ViewBuilder
    private var notesTab: some View {
        let items = notedVerses
        if items.isEmpty {
            emptyState(
                icon: "note.text",
                accentIcon: "pencil.line",
                title: "No Notes Yet",
                message: "Add notes to any verse in the\nBible reader to see them here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                summaryBar(
                    icon: "note.text",
                    text: "\(items.count) \(items.count == 1 ? "note" : "notes")"
                )

                LazyVStack(spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, verse in
                        Button {
                            NotificationCenter.default.post(
                                name: .scriptureDeepLink,
                                object: nil,
                                userInfo: [
                                    "bookName": verse.bookName,
                                    "chapter": verse.chapter,
                                    "verse": verse.verseNumber
                                ]
                            )
                            HapticService.lightImpact()
                        } label: {
                            NoteCard(
                                verse: verse,
                                palette: palette,
                                onClearNote: { viewModel.clearNote(verse) }
                            )
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
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.accent)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(palette.accent.opacity(0.08))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.05), value: appeared)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, accentIcon: String, title: String, message: String) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Outer glow ring
                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 140, height: 140)

                // Inner glow ring
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 100, height: 100)

                // Center icon circle
                Circle()
                    .fill(palette.surfaceElevated)
                    .frame(width: 72, height: 72)
                    .shadow(color: palette.accent.opacity(0.1), radius: 12, y: 4)
                    .overlay(
                        Circle()
                            .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
                    )

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(palette.accent)

                // Small floating accent icon
                Image(systemName: accentIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.5))
                    .offset(x: 36, y: -28)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(BPAnimation.spring.delay(0.1), value: appeared)

            VStack(spacing: 10) {
                Text(title)
                    .font(BPFont.elegantHeadingLarge)
                    .foregroundStyle(palette.textPrimary)

                Text(message)
                    .font(BPFont.elegantBody)
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
                .foregroundStyle(typeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(typeColor.opacity(0.1))
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
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
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        // Left accent colored by content type
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(typeColor.opacity(0.6))
            .frame(width: 3)
        }
        .contextMenu {
            Button(role: .destructive) {
                onUnsave()
                HapticService.notification(.warning)
            } label: {
                Label("Remove from Favorites", systemImage: "heart.slash")
            }
        }
    }

    private var typeColor: Color {
        switch content.type {
        case .prayer: Color(hex: "9B7BD5")
        case .verse: Color(hex: "C9A96E")
        case .devotional: Color(hex: "5B9BD5")
        case .quote: Color(hex: "E8944A")
        case .reflection: Color(hex: "4ABFB5")
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
    let colorScheme: ColorScheme
    let onDelete: () -> Void

    private var accentColor: Color {
        verse.highlightColor.map { Color(hex: $0.dotColor) } ?? palette.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Reference + translation row
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor)

                    Text("\(verse.bookName) \(verse.chapter):\(verse.verseNumber)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }

                Spacer()

                Text(verse.translation)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(palette.surface)
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
            }

            // Verse text
            Text(verse.text)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(3)
                .lineSpacing(4)

            // Notes — marginalia style
            if !verse.notes.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(palette.accent.opacity(0.4))
                        .frame(width: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NOTE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(palette.accent.opacity(0.6))

                        Text(verse.notes)
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(2)
                    }
                    .padding(.leading, 8)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        // Highlight color tinted background wash
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    verse.highlightColor.map {
                        Color(hex: colorScheme == .dark ? $0.darkTint : $0.lightTint).opacity(0.3)
                    } ?? Color.clear
                )
        )
        // Left accent with highlight color
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(accentColor.opacity(0.6))
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

// MARK: - Note Card (Marginalia Style)

private struct NoteCard: View {
    let verse: SavedBibleVerse
    let palette: BPColorPalette
    let onClearNote: () -> Void

    private var accentColor: Color {
        verse.highlightColor.map { Color(hex: $0.dotColor) } ?? palette.accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Gold accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 10) {
                // Reference row
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 9, weight: .semibold))
                        Text("NOTE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(accentColor)

                    Text("\(verse.bookName) \(verse.chapter):\(verse.verseNumber)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.textMuted.opacity(0.5))
                }

                // Note text (primary — italic serif)
                Text(verse.notes)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(4)
                    .lineSpacing(4)

                // Verse snippet (secondary)
                Text(verse.text)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textMuted.opacity(0.7))
                    .lineLimit(2)
                    .lineSpacing(3)
            }
            .padding(.leading, 12)
            .padding(.vertical, 14)
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated.opacity(0.9))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        .contextMenu {
            Button(role: .destructive) {
                onClearNote()
                HapticService.notification(.warning)
            } label: {
                Label("Clear Note", systemImage: "eraser")
            }
        }
    }
}

