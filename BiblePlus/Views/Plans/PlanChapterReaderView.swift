import SwiftUI

struct PlanChapterReaderView: View {
    let reading: PlanReading

    @Environment(\.bpPalette) private var palette
    @State private var verses: [(number: Int, text: String)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var bookName: String {
        BibleData.book(id: reading.bookID)?.name ?? reading.bookID
    }

    private var chapterTitle: String {
        "\(bookName) \(reading.chapter)"
    }

    private var displayVerses: [(number: Int, text: String)] {
        guard let start = reading.verseStart, let end = reading.verseEnd else {
            return verses
        }
        return verses.filter { $0.number >= start && $0.number <= end }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingState
            } else if let error = errorMessage {
                errorState(message: error)
            } else if displayVerses.isEmpty {
                emptyState
            } else {
                readerContent
            }
        }
        .background(palette.parchment)
        .navigationTitle(reading.displayReference)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadVerses()
        }
    }

    // MARK: - Reader Content

    private var readerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(chapterTitle)
                    .font(BPFont.headingSmall)
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)

                OrnamentalDivider(color: palette.accent, opacity: 0.3)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)

                ForEach(displayVerses, id: \.number) { verse in
                    let isRed = RedLetterData.isRedLetter(
                        book: reading.bookID,
                        chapter: reading.chapter,
                        verse: verse.number
                    )
                    verseRow(number: verse.number, text: verse.text, isRedLetter: isRed)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 80)
        }
        .background(palette.parchment)
    }

    // MARK: - Verse Row

    private func verseRow(number: Int, text: String, isRedLetter: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(number) ")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundStyle(palette.accent.opacity(0.5))
                .baselineOffset(4)

            Text(text)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(isRedLetter ? palette.jesusWords : palette.textPrimary)
                .lineSpacing(8)
        }
        .padding(.vertical, 2)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 72, height: 72)
                ProgressView()
                    .tint(palette.accent)
            }
            Text("Loading chapter...")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(palette.accent)

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await loadVerses() }
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(palette.accent))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(palette.textMuted)

            Text("Chapter not available yet")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func loadVerses() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await BibleRepository.shared.verses(book: reading.bookID, chapter: reading.chapter)
            verses = result
        } catch {
            errorMessage = "Could not load chapter. Please try again."
        }
        isLoading = false
    }
}
