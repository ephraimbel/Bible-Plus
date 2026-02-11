import SwiftUI
import SwiftData
import UIKit

struct BibleView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BibleReaderViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    BibleContentView(viewModel: vm)
                } else {
                    BPLoadingView().onAppear {
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
    @Environment(\.bpPalette) private var palette
    @State private var showExplainChat = false
    @State private var explainPrompt = ""
    @State private var shareText: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main reader
            ChapterReaderView(
                verses: viewModel.verses,
                chapterTitle: viewModel.chapterTitle,
                selectedVerseNumber: viewModel.selectedVerse?.number,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                isShowingOfflineFallback: viewModel.isShowingOfflineFallback,
                offlineTranslationName: viewModel.translationName,
                onVerseTap: { viewModel.selectVerse($0) },
                onRetry: { viewModel.retryLoading() }
            )
            .background(palette.background)
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
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
                        shareText = viewModel.shareText(for: verse)
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
                    .foregroundStyle(palette.accent)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Translation picker capsule
                    Button {
                        viewModel.showTranslationPicker = true
                    } label: {
                        Text(viewModel.currentTranslation.apiCode)
                            .font(BPFont.caption)
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(
                                Capsule()
                                    .stroke(palette.accent, lineWidth: 1)
                            )
                    }

                    Button {
                        viewModel.goToPreviousChapter()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.canGoBack
                                    ? palette.accent
                                    : palette.textMuted
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
                                    ? palette.accent
                                    : palette.textMuted
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
        .sheet(isPresented: $viewModel.showTranslationPicker) {
            BibleTranslationPickerView(
                currentTranslation: viewModel.currentTranslation,
                onSelect: { viewModel.changeTranslation($0) }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showExplainChat) {
            ChatView(initialContext: explainPrompt)
        }
        .sheet(isPresented: Binding(
            get: { shareText != nil },
            set: { if !$0 { shareText = nil } }
        )) {
            if let text = shareText {
                ShareSheetView(items: [text])
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
