import SwiftUI

struct BookPickerView: View {
    let onSelectBook: (BibleBook) -> Void
    let onSelectChapter: (BibleBook, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var expandedBook: BibleBook? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    bookSection(title: "Old Testament", books: BibleData.oldTestament)
                    bookSection(title: "New Testament", books: BibleData.newTestament)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(palette.background)
            .navigationTitle("Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func bookSection(title: String, books: [BibleBook]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BPFont.button)
                .foregroundStyle(palette.textMuted)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.leading, 4)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                spacing: 8
            ) {
                ForEach(books) { book in
                    bookButton(book)
                }
            }
        }
    }

    private func bookButton(_ book: BibleBook) -> some View {
        Button {
            HapticService.selection()
            if book.chapterCount == 1 {
                onSelectChapter(book, 1)
            } else if expandedBook == book {
                expandedBook = nil
            } else {
                withAnimation(BPAnimation.selection) {
                    expandedBook = book
                }
            }
        } label: {
            Text(book.name)
                .font(BPFont.caption)
                .foregroundStyle(
                    expandedBook == book
                        ? .white
                        : palette.textPrimary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            expandedBook == book
                                ? palette.accent
                                : palette.surface
                        )
                )
        }
        .popover(isPresented: Binding(
            get: { expandedBook == book },
            set: { if !$0 { expandedBook = nil } }
        )) {
            chapterGrid(for: book)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func chapterGrid(for book: BibleBook) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(book.name)
                    .font(BPFont.button)
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 44), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(1...book.chapterCount, id: \.self) { chapter in
                        Button {
                            HapticService.lightImpact()
                            expandedBook = nil
                            onSelectChapter(book, chapter)
                        } label: {
                            Text("\(chapter)")
                                .font(BPFont.body)
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(palette.surface)
                                )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 260, maxHeight: 300)
    }
}
