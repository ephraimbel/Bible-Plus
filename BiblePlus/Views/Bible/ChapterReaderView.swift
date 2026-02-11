import SwiftUI

struct ChapterReaderView: View {
    let verses: [(number: Int, text: String)]
    let chapterTitle: String
    let selectedVerseNumber: Int?
    let isLoading: Bool
    let errorMessage: String?
    let isShowingOfflineFallback: Bool
    let offlineTranslationName: String
    let savedVerseNumbers: Set<Int>
    let highlightColors: [Int: VerseHighlightColor]
    let audioVerseIndex: Int?
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

                        // Verses as flowing text
                        ForEach(verses, id: \.number) { verse in
                            verseRow(number: verse.number, text: verse.text)
                                .id(verse.number)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, audioVerseIndex != nil ? 140 : 80)
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

    private func verseRow(number: Int, text: String) -> some View {
        let isSelected = selectedVerseNumber == number
        let highlight = highlightColors[number]
        let isSaved = savedVerseNumbers.contains(number)
        let isAudioActive = audioVerseIndex != nil
            && (verses.firstIndex(where: { $0.number == number }).map { $0 == audioVerseIndex } ?? false)

        return Button {
            onVerseTap(VerseItem(number: number, text: text))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Verse number with optional bookmark indicator
                ZStack(alignment: .topTrailing) {
                    Text("\(number)")
                        .font(.system(size: max(11, readerFontSize * 0.65), weight: .light, design: .serif))
                        .foregroundStyle(palette.accent)
                        .frame(width: 24, alignment: .trailing)

                    if isSaved {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(
                                highlight != nil
                                    ? Color(hex: highlight!.dotColor)
                                    : palette.accent
                            )
                            .offset(x: 6, y: -2)
                    }
                }

                Text(text)
                    .font(.system(size: readerFontSize, weight: .regular, design: readerFontDesign))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(readerLineSpacing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(verseBackground(isSelected: isSelected, highlight: highlight, isAudioHighlight: isAudioActive))
            )
            .overlay(alignment: .leading) {
                if isAudioActive {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette.accent)
                        .frame(width: 3)
                        .padding(.vertical, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func verseBackground(isSelected: Bool, highlight: VerseHighlightColor?, isAudioHighlight: Bool) -> Color {
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
        return .clear
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(palette.accent)
            Text("Loading chapter...")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("Couldn't Load Chapter")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text(message)
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Button {
                onRetry()
            } label: {
                Text("Try Again")
                    .font(BPFont.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(palette.accent))
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .medium))
            Text("Showing KJV offline. Connect to load \(offlineTranslationName).")
                .font(BPFont.caption)
        }
        .foregroundStyle(palette.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.accentSoft)
        )
        .padding(.horizontal, 0)
        .padding(.top, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("Chapter Not Yet Available")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text("This chapter's text will be\navailable in a future update.")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
