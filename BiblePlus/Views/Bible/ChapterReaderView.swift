import SwiftUI

struct ChapterReaderView: View {
    let verses: [(number: Int, text: String)]
    let chapterTitle: String
    let selectedVerseNumber: Int?
    let onVerseTap: (VerseItem) -> Void

    var body: some View {
        if verses.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Chapter heading
                    Text(chapterTitle)
                        .font(BPFont.headingSmall)
                        .foregroundStyle(BPColorPalette.light.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)

                    // Verses as flowing text
                    ForEach(verses, id: \.number) { verse in
                        verseRow(number: verse.number, text: verse.text)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 80)
            }
        }
    }

    private func verseRow(number: Int, text: String) -> some View {
        let isSelected = selectedVerseNumber == number

        return Button {
            onVerseTap(VerseItem(number: number, text: text))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number)")
                    .font(BPFont.reference)
                    .foregroundStyle(BPColorPalette.light.accent)
                    .frame(width: 24, alignment: .trailing)

                Text(text)
                    .font(BPFont.bibleMedium)
                    .foregroundStyle(BPColorPalette.light.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? BPColorPalette.light.accentSoft : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(BPColorPalette.light.accent)

            Text("Chapter Not Yet Available")
                .font(BPFont.headingSmall)
                .foregroundStyle(BPColorPalette.light.textPrimary)

            Text("This chapter's text will be\navailable in a future update.")
                .font(BPFont.body)
                .foregroundStyle(BPColorPalette.light.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
