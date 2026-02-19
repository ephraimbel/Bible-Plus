import SwiftUI

struct BookPickerView: View {
    let onSelectBook: (BibleBook) -> Void
    let onSelectChapter: (BibleBook, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var expandedBook: BibleBook? = nil
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    bookSection(title: "Old Testament", books: BibleData.oldTestament)
                    bookSection(title: "New Testament", books: BibleData.newTestament)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(palette.background)
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

    @ViewBuilder
    private func bookSection(title: String, books: [BibleBook]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textMuted)
                .textCase(.uppercase)
                .tracking(1.5)
                .padding(.leading, 4)
                .opacity(appeared ? 1 : 0)
                .animation(BPAnimation.spring.delay(0.05), value: appeared)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    bookButton(book, index: index)
                }
            }
        }
    }

    private func bookButton(_ book: BibleBook, index: Int) -> some View {
        let isExpanded = expandedBook == book

        return Button {
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
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(isExpanded ? .white : palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
                                : .black.opacity(0.04),
                            radius: isExpanded ? 6 : 4,
                            y: isExpanded ? 3 : 2
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isExpanded
                                ? Color.clear
                                : palette.border.opacity(0.15),
                            lineWidth: 0.5
                        )
                )
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

    private func chapterGrid(for book: BibleBook) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(book.name)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 44), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(1...book.chapterCount, id: \.self) { chapter in
                        Button {
                            HapticService.lightImpact()
                            expandedBook = nil
                            onSelectChapter(book, chapter)
                        } label: {
                            Text("\(chapter)")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(palette.surfaceElevated)
                                        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(minWidth: 280, maxHeight: 320)
        .background(palette.background)
    }
}
