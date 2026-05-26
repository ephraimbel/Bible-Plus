import SwiftUI
import SwiftData

struct BookPickerView: View {
    let onSelectBook: (BibleBook) -> Void
    let onSelectChapter: (BibleBook, Int) -> Void
    /// When non-nil, the picker shows book names in the active translation
    /// (e.g. "Génesis" for Spanish Reina-Valera) by looking up
    /// `BibleRepository.localizedBookName`. Falls back to `book.name` (English)
    /// when the cache hasn't been populated yet or when no ref is active.
    var activeRefID: String? = nil
    /// The book/chapter currently open in the reader. When set, the matching
    /// book gets a subtle ring and the matching chapter is filled, so users can
    /// locate where they left off. Nil when unknown.
    var currentBookID: String? = nil
    var currentChapter: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @State private var expandedBook: BibleBook? = nil
    @State private var appeared = false
    /// Chapter numbers already read in the currently-expanded book, derived
    /// from logged `.chapterRead` activity. Loaded when a book is expanded so
    /// the chapter grid can mark progress. Single book at a time matches the
    /// one-popover-open invariant.
    @State private var readChapters: Set<Int> = []

    /// Resolve a book's display name, preferring the helloao-sourced localized
    /// name when the active translation has primed the cache. Thin wrapper
    /// around `BibleRepository.localizedBookName` so the row code stays tidy.
    private func displayName(for book: BibleBook) -> String {
        if let refID = activeRefID,
           let localized = BibleRepository.shared.localizedBookName(refID: refID, bookID: book.id) {
            return localized
        }
        return book.name
    }

    /// Populates `readChapters` for the given book from logged `.chapterRead`
    /// events. Events store `detail` as "<Book> <Chapter>" (English book name,
    /// e.g. "Genesis 1"), so we filter by the book-name prefix and parse the
    /// trailing chapter number. Fetches all chapter-read events and filters in
    /// memory — the set is small and this avoids relying on predicate string
    /// prefix support.
    private func loadReadChapters(for book: BibleBook) {
        let raw = ActivityEventType.chapterRead.rawValue
        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.typeRaw == raw }
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        let prefix = book.name + " "
        var chapters: Set<Int> = []
        for event in events where event.detail.hasPrefix(prefix) {
            if let chapter = Int(event.detail.dropFirst(prefix.count)) {
                chapters.insert(chapter)
            }
        }
        readChapters = chapters
    }

    /// Header subtitle for the chapter grid: a quiet progress count once the
    /// reader has read at least one chapter, otherwise the plain chapter total.
    private func progressSubtitle(for book: BibleBook) -> String {
        if readChapters.isEmpty {
            return "\(book.chapterCount) chapters"
        }
        return "\(min(readChapters.count, book.chapterCount)) of \(book.chapterCount) read"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        bookSection(title: "Old Testament", icon: "scroll", bookCount: 39, books: BibleData.oldTestament)
                            .id("ot")
                        bookSection(title: "New Testament", icon: "book.closed", bookCount: 27, books: BibleData.newTestament)
                            .id("nt")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .background(palette.background)
                .onAppear {
                    // Open the list where the reader left off, so the current
                    // book (and its gold ring) is in view, not off-screen.
                    if let currentBookID {
                        proxy.scrollTo(currentBookID, anchor: .center)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Books")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.accent)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(BPAnimation.spring) {
                        appeared = true
                    }
                }
            }
        }
    }

    // MARK: - Book Section

    @ViewBuilder
    private func bookSection(title: String, icon: String, bookCount: Int, books: [BibleBook]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header with icon and divider
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.1))
                    )

                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .tracking(1.5)

                Text("\(bookCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(palette.accent.opacity(0.08))
                    )

                VStack { Divider() }
                    .padding(.leading, 4)
            }
            .padding(.leading, 4)
            .opacity(appeared ? 1 : 0)
            .animation(BPAnimation.spring.delay(0.05), value: appeared)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    bookButton(book, index: index)
                        .id(book.id)
                }
            }
        }
    }

    // MARK: - Book Button

    private func bookButton(_ book: BibleBook, index: Int) -> some View {
        let isExpanded = expandedBook == book
        let isCurrentBook = currentBookID == book.id

        return Button {
            HapticService.selection()
            if book.chapterCount == 1 {
                onSelectChapter(book, 1)
            } else if expandedBook == book {
                withAnimation(BPAnimation.selection) {
                    expandedBook = nil
                }
            } else {
                loadReadChapters(for: book)
                withAnimation(BPAnimation.selection) {
                    expandedBook = book
                }
            }
        } label: {
            VStack(spacing: 3) {
                Text(displayName(for: book))
                    .font(.system(size: 13, weight: isExpanded ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isExpanded ? .white : palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(book.chapterCount) ch")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isExpanded ? .white.opacity(0.7) : palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isExpanded
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(palette.surfaceElevated)
                    )
                    .shadow(
                        color: isExpanded
                            ? palette.accent.opacity(0.3)
                            : .black.opacity(0.05),
                        radius: isExpanded ? 8 : 4,
                        y: isExpanded ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isExpanded
                            ? Color.clear
                            : (isCurrentBook ? palette.accent.opacity(0.45) : palette.border.opacity(0.1)),
                        lineWidth: (isCurrentBook && !isExpanded) ? 1.2 : 0.5
                    )
            )
            .scaleEffect(isExpanded ? 1.04 : 1.0)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(BPAnimation.spring.delay(0.08 + Double(min(index, 12)) * 0.015), value: appeared)
        .popover(isPresented: Binding(
            get: { expandedBook == book },
            set: { if !$0 { expandedBook = nil } }
        )) {
            chapterGrid(for: book)
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Chapter Grid Popover

    private func chapterGrid(for book: BibleBook) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Book header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(palette.accent.opacity(0.04))
                            .frame(width: 38, height: 38)

                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                            )
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayName(for: book))
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(palette.textPrimary)

                        Text(progressSubtitle(for: book))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(readChapters.isEmpty ? palette.textMuted : palette.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Divider()
                    .padding(.horizontal, 16)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 46), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(1...book.chapterCount, id: \.self) { chapter in
                        let isCurrent = currentBookID == book.id && currentChapter == chapter
                        let isRead = readChapters.contains(chapter)
                        Button {
                            HapticService.lightImpact()
                            expandedBook = nil
                            onSelectChapter(book, chapter)
                        } label: {
                            Text("\(chapter)")
                                .font(.system(size: 15, weight: (isCurrent || isRead) ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(isCurrent ? .white : (isRead ? palette.accent : palette.textPrimary))
                                .frame(width: 46, height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isCurrent
                                                ? AnyShapeStyle(
                                                    LinearGradient(
                                                        colors: [palette.accent, palette.accent.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                : AnyShapeStyle(palette.surfaceElevated)
                                        )
                                        .shadow(
                                            color: isCurrent ? palette.accent.opacity(0.3) : .black.opacity(0.05),
                                            radius: 6, y: 3
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            isCurrent
                                                ? Color.clear
                                                : (isRead ? palette.accent.opacity(0.25) : palette.border.opacity(0.08)),
                                            lineWidth: 0.5
                                        )
                                )
                                .overlay(alignment: .bottom) {
                                    if isRead && !isCurrent {
                                        Circle()
                                            .fill(palette.accent)
                                            .frame(width: 4, height: 4)
                                            .padding(.bottom, 5)
                                    }
                                }
                        }
                        .buttonStyle(ChapterButtonStyle(accent: palette.accent))
                        .accessibilityLabel("Chapter \(chapter)\(isCurrent ? ", currently reading" : isRead ? ", read" : "")")
                        .id(chapter)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
            .frame(minWidth: 290, maxHeight: 340)
            .background(palette.background)
            .onAppear {
                // Bring the current chapter into view in long books (e.g.
                // Psalms) so the highlighted cell isn't buried below the fold.
                if currentBookID == book.id, let currentChapter, currentChapter > 1 {
                    proxy.scrollTo(currentChapter, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Chapter Button Style

private struct ChapterButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(configuration.isPressed ? 0.15 : 0))
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
