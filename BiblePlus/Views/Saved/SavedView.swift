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
            case .notes:
                notesTab
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
            tabButton("Notes", icon: "text.bubble", tab: .notes)
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
        let items = viewModel.savedItems
        if items.isEmpty {
            emptyState(
                icon: "heart",
                title: "No Favorites Yet",
                message: "Double-tap any card in the feed\nor save a prayer from Ask to see it here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                // Summary
                summaryBar(
                    icon: "heart.fill",
                    text: "\(items.count) saved \(items.count == 1 ? "item" : "items")"
                )

                LazyVStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Group {
                            switch item {
                            case .content(let content):
                                Button {
                                    NotificationCenter.default.post(
                                        name: .feedContentDeepLink,
                                        object: nil,
                                        userInfo: ["contentID": content.id]
                                    )
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

                            case .prayer(let entry):
                                NavigationLink {
                                    SavedPrayerDetailView(entry: entry, viewModel: viewModel)
                                } label: {
                                    SavedPrayerCard(entry: entry, palette: palette)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
        let items = viewModel.notedVerses
        if items.isEmpty {
            emptyState(
                icon: "text.bubble",
                title: "No Notes Yet",
                message: "Add notes to any verse in the\nBible reader to see them here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                summaryBar(
                    icon: "text.bubble.fill",
                    text: "\(items.count) \(items.count == 1 ? "note" : "notes")"
                )

                LazyVStack(spacing: 12) {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
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

// MARK: - Note Card

private struct NoteCard: View {
    let verse: SavedBibleVerse
    let palette: BPColorPalette
    let onClearNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Reference row with highlight accent
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.accent)

                    Text("\(verse.bookName) \(verse.chapter):\(verse.verseNumber)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
            }

            // Note text (primary)
            Text(verse.notes)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(3)
                .lineSpacing(3)

            // Verse snippet (secondary)
            Text(verse.text)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(palette.textMuted)
                .italic()
                .lineLimit(2)
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
                onClearNote()
                HapticService.notification(.warning)
            } label: {
                Label("Clear Note", systemImage: "eraser")
            }
        }
    }
}

// MARK: - Saved Prayer Card

private struct SavedPrayerCard: View {
    let entry: PrayerEntry
    let palette: BPColorPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category + answered row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: entry.category.icon)
                        .font(.system(size: 10, weight: .medium))
                    Text(entry.category.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(palette.accent.opacity(0.1))
                )

                Spacer()

                if entry.isAnswered {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text("Answered")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.green)
                }

                if let ref = entry.verseReference, !ref.isEmpty {
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
            }

            // Title
            Text(entry.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)

            // Body preview
            Text(entry.body)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textSecondary)
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
        // Left accent — green if answered, gold otherwise
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(entry.isAnswered ? Color.green.opacity(0.6) : palette.accent.opacity(0.4))
            .frame(width: 3)
        }
    }
}

// MARK: - Saved Prayer Detail View

private struct SavedPrayerDetailView: View {
    let entry: PrayerEntry
    @Bindable var viewModel: SavedViewModel
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Category badge
                HStack(spacing: 4) {
                    Image(systemName: entry.category.icon)
                        .font(.system(size: 11, weight: .medium))
                    Text(entry.category.displayName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(palette.accent.opacity(0.1))
                )

                // Title
                Text(entry.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                // Date
                Text(entry.createdAt, style: .date)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)

                // Full body
                Text(entry.body)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(5)

                // Verse reference
                if let ref = entry.verseReference, !ref.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                        Text(ref)
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .italic()
                    }
                    .foregroundStyle(palette.accent)
                }

                Divider()

                // Answered toggle
                Button {
                    viewModel.toggleAnswered(entry)
                    HapticService.success()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: entry.isAnswered ? "checkmark.seal.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(entry.isAnswered ? .green : palette.textMuted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.isAnswered ? "Marked as Answered" : "Mark as Answered")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.textPrimary)

                            if entry.isAnswered, let date = entry.answeredAt {
                                Text(date, style: .date)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundStyle(palette.textMuted)
                            }
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(entry.isAnswered ? Color.green.opacity(0.06) : palette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(entry.isAnswered ? Color.green.opacity(0.2) : palette.border.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                // Answer notes
                if entry.isAnswered && !entry.answerNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Answer Notes")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                        Text(entry.answerNotes)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                            .lineSpacing(4)
                    }
                }

                // Continue in Chat
                Button {
                    NotificationCenter.default.post(
                        name: .openAIWithContext,
                        object: nil,
                        userInfo: [
                            "context": "I wrote this prayer earlier: \"\(entry.body)\". Help me continue praying about this.",
                            "title": entry.title,
                        ]
                    )
                    HapticService.lightImpact()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Continue in Chat")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                        Text("Delete Prayer")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Prayer")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .confirmationDialog("Delete this prayer?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deletePrayerEntry(entry)
                dismiss()
            }
        }
    }
}
