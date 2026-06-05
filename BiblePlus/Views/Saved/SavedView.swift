import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: SavedViewModel?

    var body: some View {
        // No own NavigationStack — pushed from Settings (Profile ▸ Bible),
        // which already provides one.
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
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .serif))
                .foregroundStyle(isSelected ? .white : palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
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
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .opacity(appeared ? 1 : 0)
            .animation(BPAnimation.spring.delay(0.05), value: appeared)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, accentIcon: String, title: String, message: String) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.accent.opacity(0.10), palette.accent.opacity(0)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 110
                        )
                    )
                    .frame(width: 200, height: 200)

                Circle()
                    .stroke(palette.accent.opacity(0.13), lineWidth: 1)
                    .frame(width: 104, height: 104)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: palette.accent.opacity(0.25), radius: 10)
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
        VStack(alignment: .leading, spacing: 11) {
            // Type label + reference — small caps, gold, no icon or colored pill.
            HStack(spacing: 8) {
                Text(content.type.displayName.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(palette.accent.opacity(0.8))

                Spacer()

                if let ref = content.verseReference, !ref.isEmpty {
                    Text(ref)
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.accent)
                }
            }

            // Content text — serif, the editorial voice.
            Text(displayText)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(3)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
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
        VStack(alignment: .leading, spacing: 11) {
            // Reference + translation — a subtle highlight dot (user's colour),
            // serif reference, quiet translation label. No icons, no chevron.
            HStack(spacing: 8) {
                if verse.highlightColor != nil {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)
                }

                Text("\(verse.bookName) \(verse.chapter):\(verse.verseNumber)")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                Text(verse.translation)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(palette.textMuted)
            }

            Text(verse.text)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(3)
                .lineSpacing(4)

            // Notes — marginalia style
            if !verse.notes.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(palette.accent.opacity(0.45))
                        .frame(width: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NOTE")
                            .font(.system(size: 8.5, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(palette.accent.opacity(0.7))

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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
        )
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

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Quiet gold marginalia rule.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(palette.accent.opacity(0.5))
                .frame(width: 2.5)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("NOTE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(palette.accent.opacity(0.8))

                    Text("\(verse.bookName) \(verse.chapter):\(verse.verseNumber)")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(palette.textMuted)

                    Spacer()
                }

                // Note text (primary — italic serif)
                Text(verse.notes)
                    .font(.system(size: 16, weight: .regular, design: .serif))
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
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
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

