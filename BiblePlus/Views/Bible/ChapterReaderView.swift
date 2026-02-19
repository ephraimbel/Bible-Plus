import SwiftUI

struct ChapterReaderView: View {
    let verses: [(number: Int, text: String)]
    let chapterTitle: String
    let bookID: String
    let chapterNumber: Int
    let selectedVerseNumber: Int?
    let isLoading: Bool
    let errorMessage: String?
    let isShowingOfflineFallback: Bool
    let offlineTranslationName: String
    let savedVerseNumbers: Set<Int>
    let highlightColors: [Int: VerseHighlightColor]
    let verseNotes: [Int: String]
    let audioVerseIndex: Int?
    let lastReadVerseNumber: Int?
    let readerFontSize: Double
    let readerFontDesign: Font.Design
    let readerLineSpacing: Double
    let onVerseTap: (VerseItem) -> Void
    let onRetry: () -> Void
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isLoading && verses.isEmpty {
            loadingState
        } else if let error = errorMessage, verses.isEmpty {
            errorState(message: error)
        } else if verses.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Offline fallback banner
                        if isShowingOfflineFallback {
                            offlineBanner
                        }

                        // Chapter heading
                        Text(chapterTitle)
                            .font(BPFont.headingSmall)
                            .foregroundStyle(palette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)

                        // Ornamental divider below chapter heading
                        OrnamentalDivider(color: palette.accent, opacity: 0.3)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 16)

                        // Verses as flowing text
                        ForEach(verses, id: \.number) { verse in
                            let isRed = RedLetterData.isRedLetter(
                                book: bookID,
                                chapter: chapterNumber,
                                verse: verse.number
                            )
                            verseRow(number: verse.number, text: verse.text, isRedLetter: isRed)
                                .id(verse.number)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, audioVerseIndex != nil ? 140 : 80)
                }
                .background(palette.parchment)
                .overlay(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.06)
                        ],
                        center: .center,
                        startRadius: 300,
                        endRadius: 600
                    )
                    .allowsHitTesting(false)
                )
                .onAppear {
                    if let lastRead = lastReadVerseNumber, audioVerseIndex == nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(lastRead, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: audioVerseIndex) { _, newIndex in
                    guard let newIndex, newIndex < verses.count else { return }
                    let verseNumber = verses[newIndex].number
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(verseNumber, anchor: .center)
                    }
                }
            }
        }
    }

    private func verseRow(number: Int, text: String, isRedLetter: Bool = false) -> some View {
        let isSelected = selectedVerseNumber == number
        let highlight = highlightColors[number]
        let isSaved = savedVerseNumbers.contains(number)
        let hasNote = verseNotes[number] != nil
        let isAudioActive = audioVerseIndex != nil
            && (verses.firstIndex(where: { $0.number == number }).map { $0 == audioVerseIndex } ?? false)
        let isLastRead = lastReadVerseNumber == number && !isAudioActive

        return Button {
            HapticService.selection()
            onVerseTap(VerseItem(number: number, text: text))
        } label: {
            buildVerseText(
                number: number,
                text: text,
                isRedLetter: isRedLetter,
                isSaved: isSaved,
                hasNote: hasNote,
                highlight: highlight
            )
            .multilineTextAlignment(.leading)
            .lineSpacing(readerLineSpacing)
            .padding(.vertical, 0)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(verseBackground(isSelected: isSelected, highlight: highlight, isAudioHighlight: isAudioActive, isLastRead: isLastRead))
            )
        }
        .buttonStyle(.plain)
    }

    private func buildVerseText(
        number: Int,
        text: String,
        isRedLetter: Bool,
        isSaved: Bool,
        hasNote: Bool,
        highlight: VerseHighlightColor?
    ) -> Text {
        let superscriptSize = max(9, readerFontSize * 0.55)

        var result = Text("\(number)")
            .font(.system(size: superscriptSize, weight: .semibold, design: .serif))
            .foregroundColor(palette.accent)
            .baselineOffset(6)

        if isSaved {
            result = result + Text(Image(systemName: "bookmark.fill"))
                .font(.system(size: 7))
                .foregroundColor(
                    highlight != nil
                        ? Color(hex: highlight!.dotColor)
                        : palette.accent
                )
                .baselineOffset(6)
        }

        if hasNote {
            result = result + Text(Image(systemName: "text.bubble.fill"))
                .font(.system(size: 6))
                .foregroundColor(palette.accent)
                .baselineOffset(6)
        }

        result = result + Text("\u{2009}")
            .font(.system(size: readerFontSize, design: readerFontDesign))

        result = result + Text(text)
            .font(.system(size: readerFontSize, weight: .regular, design: readerFontDesign))
            .foregroundColor(isRedLetter ? palette.jesusWords : palette.textPrimary)

        return result
    }

    private func verseBackground(isSelected: Bool, highlight: VerseHighlightColor?, isAudioHighlight: Bool, isLastRead: Bool = false) -> Color {
        if isAudioHighlight {
            return palette.accent.opacity(0.15)
        }
        if isSelected {
            return palette.accentSoft
        }
        if let highlight {
            let hex = colorScheme == .dark ? highlight.darkTint : highlight.lightTint
            return Color(hex: hex)
        }
        if isLastRead {
            return palette.accent.opacity(0.08)
        }
        return .clear
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 72, height: 72)

                ProgressView()
                    .tint(palette.accent)
                    .scaleEffect(1.1)
            }

            Text("Loading chapter...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(palette.parchment)
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 88, height: 88)

                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundStyle(palette.accent)
            }

            VStack(spacing: 10) {
                Text("Couldn't Load Chapter")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text(message)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                onRetry()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Try Again")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.3), radius: 8, y: 4)
                )
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(palette.parchment)
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(palette.accent.opacity(0.1))
                )

            Text("Showing KJV offline. Connect to load \(offlineTranslationName).")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
        )
        .padding(.top, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 88, height: 88)

                Image(systemName: "book.closed")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundStyle(palette.accent)
            }

            VStack(spacing: 10) {
                Text("Chapter Not Yet Available")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("This chapter's text will be\navailable in a future update.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.parchment)
    }
}
