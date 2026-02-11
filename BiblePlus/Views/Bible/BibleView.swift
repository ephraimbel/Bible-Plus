import SwiftUI
import SwiftData

struct BibleView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BibleReaderViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    BibleContentView(viewModel: vm)
                } else {
                    Color.clear.onAppear {
                        viewModel = BibleReaderViewModel(modelContext: modelContext)
                    }
                }
            }
        }
    }
}

// MARK: - Inner Content View

private struct BibleContentView: View {
    @Bindable var viewModel: BibleReaderViewModel
    @State private var showExplainChat = false
    @State private var explainPrompt = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main reader
            ChapterReaderView(
                verses: viewModel.verses,
                chapterTitle: viewModel.chapterTitle,
                selectedVerseNumber: viewModel.selectedVerse?.number,
                onVerseTap: { viewModel.selectVerse($0) }
            )
            .background(BPColorPalette.light.background)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            viewModel.goToNextChapter()
                        } else if value.translation.width > 50 {
                            viewModel.goToPreviousChapter()
                        }
                    }
            )

            // Verse action sheet overlay
            if let verse = viewModel.selectedVerse {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.selectedVerse = nil }

                VerseActionSheet(
                    verse: verse,
                    reference: viewModel.verseReference(for: verse),
                    onExplain: {
                        explainPrompt = viewModel.explainVersePrompt(for: verse)
                        viewModel.selectedVerse = nil
                        showExplainChat = true
                    },
                    onCopy: {
                        viewModel.copyVerse(verse)
                        viewModel.selectedVerse = nil
                    },
                    onShare: {
                        viewModel.copyVerse(verse)
                        viewModel.selectedVerse = nil
                    },
                    onDismiss: {
                        viewModel.selectedVerse = nil
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(BPAnimation.spring, value: viewModel.selectedVerse)
        .navigationTitle(viewModel.selectedBook.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.showBookPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.chapterTitle)
                            .font(BPFont.button)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(BPColorPalette.light.accent)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.goToPreviousChapter()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.canGoBack
                                    ? BPColorPalette.light.accent
                                    : BPColorPalette.light.textMuted
                            )
                    }
                    .disabled(!viewModel.canGoBack)

                    Button {
                        viewModel.goToNextChapter()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.canGoForward
                                    ? BPColorPalette.light.accent
                                    : BPColorPalette.light.textMuted
                            )
                    }
                    .disabled(!viewModel.canGoForward)
                }
            }
        }
        .sheet(isPresented: $viewModel.showBookPicker) {
            BookPickerView(
                onSelectBook: { book in
                    viewModel.selectBook(book)
                },
                onSelectChapter: { book, chapter in
                    viewModel.selectedBook = book
                    viewModel.selectChapter(chapter)
                }
            )
        }
        .sheet(isPresented: $showExplainChat) {
            ChatView(initialContext: explainPrompt)
        }
    }
}
