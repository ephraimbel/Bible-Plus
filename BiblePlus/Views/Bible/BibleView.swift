import SwiftUI
import SwiftData
import UIKit

struct BibleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioBibleService.self) private var audioBibleService
    @Environment(\.bpPalette) private var palette
    @State private var viewModel: BibleReaderViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    BibleContentView(viewModel: vm, audioService: audioBibleService)
                } else {
                    BPLoadingView().onAppear {
                        viewModel = BibleReaderViewModel(modelContext: modelContext)
                    }
                }
            }
            .background(palette.background)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Inner Content View

private struct BibleContentView: View {
    @Bindable var viewModel: BibleReaderViewModel
    let audioService: AudioBibleService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var showExplainChat = false
    @State private var explainPrompt = ""
    @State private var explainConversationId = UUID()
    @State private var shareText: String?
    @State private var searchViewModel: BibleSearchViewModel?
    @State private var showAudioProGate = false
    @State private var showVoicePicker = false
    @State private var showImmersiveListening = false
    @State private var showPaywall = false

    // MARK: - Page Flip State

    @State private var isPageFlipping = false
    @State private var flipAngle: Double = 0
    @State private var flipAnchor: UnitPoint = .leading
    @State private var cachedVerses: [(number: Int, text: String)] = []
    @State private var cachedChapterTitle: String = ""
    @State private var cachedSavedVerseNumbers: Set<Int> = []
    @State private var cachedHighlightColors: [Int: VerseHighlightColor] = [:]

    private var resolvedBackground: SanctuaryBackground {
        let descriptor = FetchDescriptor<UserProfile>()
        let bgID = (try? modelContext.fetch(descriptor).first?.selectedBackgroundID) ?? "warm-gold"
        return SanctuaryBackground.background(for: bgID)
            ?? SanctuaryBackground.allBackgrounds[0]
    }

    private var currentColorMode: ColorMode {
        let descriptor = FetchDescriptor<UserProfile>()
        return (try? modelContext.fetch(descriptor).first?.colorMode) ?? .auto
    }

    private func updateColorMode(_ mode: ColorMode) {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else { return }
        profile.colorMode = mode
        try? modelContext.save()
    }

    private var paperColor: Color {
        colorScheme == .dark
            ? Color(red: 43/255, green: 42/255, blue: 39/255)
            : Color(red: 250/255, green: 248/255, blue: 244/255)
    }

    private func createExplainConversation() {
        let title = String(explainPrompt.prefix(40))
        let conversation = Conversation(title: title)
        modelContext.insert(conversation)
        try? modelContext.save()
        explainConversationId = conversation.id
    }

    // MARK: - Audio Bible

    /// Provides verses for a given book/chapter — used by prefetch for next-chapter lookups.
    private func versesProvider(book: BibleBook, chapter: Int) async -> [(number: Int, text: String)] {
        let repo = BibleRepository.shared
        return (try? await repo.verses(book: book.id, chapter: chapter)) ?? []
    }

    private func handleAudioTap() {
        if audioService.isPlaying || audioService.isPaused {
            audioService.togglePlayback()
            return
        }

        // Rate limit check
        let descriptor = FetchDescriptor<UserProfile>()
        let isPro = (try? modelContext.fetch(descriptor).first?.isPro) ?? false

        guard AudioBibleService.canPlayChapter(isPro: isPro) else {
            showAudioProGate = true
            return
        }

        guard !viewModel.verses.isEmpty else { return }

        // Set up auto-advance
        audioService.setOnChapterComplete {
            if viewModel.canGoForward {
                viewModel.goToNextChapter()
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !viewModel.verses.isEmpty else { return }
                    audioService.play(
                        verses: viewModel.verses,
                        book: viewModel.selectedBook,
                        chapter: viewModel.selectedChapter,
                        translation: viewModel.currentTranslation,
                        versesProvider: versesProvider
                    )
                }
            }
        }

        // Resume from last-read verse if available
        let startIndex: Int
        if let lastVerse = viewModel.lastReadVerseNumber,
           let idx = viewModel.verses.firstIndex(where: { $0.number == lastVerse }) {
            startIndex = idx
        } else {
            startIndex = 0
        }

        audioService.play(
            verses: viewModel.verses,
            book: viewModel.selectedBook,
            chapter: viewModel.selectedChapter,
            translation: viewModel.currentTranslation,
            startingFromVerseIndex: startIndex,
            versesProvider: versesProvider
        )
    }

    // MARK: - Immersive Listening

    private func handleImmersiveListeningTap() {
        if audioService.hasActivePlayback {
            showImmersiveListening = true
            return
        }

        // Rate limit check for fresh playback
        let descriptor = FetchDescriptor<UserProfile>()
        let isPro = (try? modelContext.fetch(descriptor).first?.isPro) ?? false

        guard AudioBibleService.canPlayChapter(isPro: isPro) else {
            showAudioProGate = true
            return
        }

        guard !viewModel.verses.isEmpty else { return }

        showImmersiveListening = true
    }

    // MARK: - Page Flip

    private func performPageFlip(forward: Bool) {
        guard !isPageFlipping else { return }

        // Stop audio when manually changing chapter
        if audioService.hasActivePlayback {
            audioService.stop()
        }

        // Snapshot the current page content into local state
        cachedVerses = viewModel.verses
        cachedChapterTitle = viewModel.chapterTitle
        cachedSavedVerseNumbers = viewModel.savedVerseNumbers
        cachedHighlightColors = viewModel.highlightColors
        flipAnchor = forward ? .leading : .trailing
        flipAngle = 0
        isPageFlipping = true

        // Navigate (this clears verses and starts async load)
        if forward {
            viewModel.goToNextChapter()
        } else {
            viewModel.goToPreviousChapter()
        }

        // Animate the cached page flipping away
        withAnimation(.easeInOut(duration: 0.5)) {
            flipAngle = forward ? -90 : 90
        }

        // Clean up after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            isPageFlipping = false
            flipAngle = 0
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page container
            ZStack {
                // Current / new page (underneath)
                ChapterReaderView(
                    verses: viewModel.verses,
                    chapterTitle: viewModel.chapterTitle,
                    selectedVerseNumber: viewModel.selectedVerse?.number,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    isShowingOfflineFallback: viewModel.isShowingOfflineFallback,
                    offlineTranslationName: viewModel.translationName,
                    savedVerseNumbers: viewModel.savedVerseNumbers,
                    highlightColors: viewModel.highlightColors,
                    audioVerseIndex: audioService.isPlaying ? audioService.currentVerseIndex : nil,
                    lastReadVerseNumber: viewModel.lastReadVerseNumber,
                    readerFontSize: viewModel.readerFontSize,
                    readerFontDesign: viewModel.readerFontDesign,
                    readerLineSpacing: viewModel.readerLineSpacing,
                    onVerseTap: { viewModel.selectVerse($0) },
                    onRetry: { viewModel.retryLoading() }
                )

                // Shadow cast onto the revealed page by the turning page above
                if isPageFlipping {
                    Color.black
                        .opacity(0.2 * (1 - abs(flipAngle) / 90))
                        .allowsHitTesting(false)
                }

                // Cached previous page (on top — this is the page being flipped)
                if isPageFlipping {
                    ChapterReaderView(
                        verses: cachedVerses,
                        chapterTitle: cachedChapterTitle,
                        selectedVerseNumber: nil,
                        isLoading: false,
                        errorMessage: nil,
                        isShowingOfflineFallback: false,
                        offlineTranslationName: "",
                        savedVerseNumbers: cachedSavedVerseNumbers,
                        highlightColors: cachedHighlightColors,
                        audioVerseIndex: nil,
                        lastReadVerseNumber: nil,
                        readerFontSize: viewModel.readerFontSize,
                        readerFontDesign: viewModel.readerFontDesign,
                        readerLineSpacing: viewModel.readerLineSpacing,
                        onVerseTap: { _ in },
                        onRetry: { }
                    )
                    .background(paperColor)
                    .overlay(
                        // Lighting: darkens toward the lifting edge
                        LinearGradient(
                            colors: [
                                .clear,
                                .black.opacity(abs(flipAngle) / 200)
                            ],
                            startPoint: flipAnchor == .leading ? .leading : .trailing,
                            endPoint: flipAnchor == .leading ? .trailing : .leading
                        )
                        .allowsHitTesting(false)
                    )
                    .rotation3DEffect(
                        .degrees(flipAngle),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: flipAnchor,
                        anchorZ: 0,
                        perspective: 0.25
                    )
                    .shadow(
                        color: .black.opacity(min(abs(flipAngle) / 100, 0.45)),
                        radius: abs(flipAngle) / 4,
                        x: flipAnchor == .leading
                            ? -(abs(flipAngle) / 5)
                            : abs(flipAngle) / 5
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                        if value.translation.width < -50 {
                            performPageFlip(forward: true)
                        } else if value.translation.width > 50 {
                            performPageFlip(forward: false)
                        }
                    }
            )

            // Audio error banner
            if let errorMsg = audioService.errorMessage {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.accent)

                        Text(errorMsg)
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(2)

                        Spacer()

                        Button {
                            audioService.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(palette.textMuted)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(palette.surface)
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { audioService.errorMessage = nil }
                    }
                }
            }

            // Audio mini player
            if audioService.hasActivePlayback {
                AudioMiniPlayerView(
                    audioService: audioService,
                    chapterTitle: viewModel.chapterTitle,
                    totalVerses: viewModel.verses.count,
                    onClose: { audioService.stop() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Verse action sheet overlay
            if let verse = viewModel.selectedVerse {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.selectedVerse = nil }

                VerseActionSheet(
                    verse: verse,
                    reference: viewModel.verseReference(for: verse),
                    isSaved: viewModel.isVerseSaved(verse.number),
                    currentHighlight: viewModel.highlightColor(for: verse.number),
                    onExplain: {
                        // Verse explain counts toward AI rate limit
                        let descriptor = FetchDescriptor<UserProfile>()
                        let isPro = (try? modelContext.fetch(descriptor).first?.isPro) ?? false
                        let allMsgDescriptor = FetchDescriptor<ChatMessage>(
                            sortBy: [SortDescriptor(\.createdAt)]
                        )
                        let allMessages = (try? modelContext.fetch(allMsgDescriptor)) ?? []
                        if !AIService.canSendMessage(messages: allMessages, isPro: isPro) {
                            viewModel.selectedVerse = nil
                            showPaywall = true
                            return
                        }

                        explainPrompt = viewModel.explainVersePrompt(for: verse)
                        createExplainConversation()
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
                    onSave: {
                        viewModel.saveVerse(verse)
                        viewModel.selectedVerse = nil
                    },
                    onUnsave: {
                        viewModel.unsaveVerse(verse)
                        viewModel.selectedVerse = nil
                    },
                    onHighlight: { color in
                        viewModel.highlightVerse(verse, color: color)
                    },
                    onRemoveHighlight: {
                        viewModel.removeHighlight(verse)
                    },
                    onPlayFromHere: {
                        let verseIndex = viewModel.verses.firstIndex(where: { $0.number == verse.number }) ?? 0
                        viewModel.selectedVerse = nil

                        if audioService.hasActivePlayback {
                            // Already playing — just seek
                            audioService.seekToVerse(index: verseIndex)
                        } else {
                            // Start fresh from this verse
                            let descriptor = FetchDescriptor<UserProfile>()
                            let isPro = (try? modelContext.fetch(descriptor).first?.isPro) ?? false

                            guard AudioBibleService.canPlayChapter(isPro: isPro) else {
                                showAudioProGate = true
                                return
                            }

                            audioService.setOnChapterComplete {
                                if viewModel.canGoForward {
                                    viewModel.goToNextChapter()
                                    Task {
                                        try? await Task.sleep(nanoseconds: 500_000_000)
                                        guard !viewModel.verses.isEmpty else { return }
                                        audioService.play(
                                            verses: viewModel.verses,
                                            book: viewModel.selectedBook,
                                            chapter: viewModel.selectedChapter,
                                            translation: viewModel.currentTranslation,
                                            versesProvider: versesProvider
                                        )
                                    }
                                }
                            }

                            audioService.play(
                                verses: viewModel.verses,
                                book: viewModel.selectedBook,
                                chapter: viewModel.selectedChapter,
                                translation: viewModel.currentTranslation,
                                startingFromVerseIndex: verseIndex,
                                versesProvider: versesProvider
                            )
                        }
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
        .animation(BPAnimation.spring, value: audioService.hasActivePlayback)
        .animation(.easeInOut(duration: 0.3), value: audioService.errorMessage != nil)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 10) {
                    Button {
                        viewModel.showBookPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.chapterTitle)
                                .font(.system(size: 17, weight: .semibold, design: .serif))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(palette.textPrimary)
                    }
                    .accessibilityLabel("Choose book and chapter")

                    Button {
                        viewModel.showTranslationPicker = true
                    } label: {
                        Text(viewModel.currentTranslation.apiCode)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(palette.accent.opacity(0.12))
                            )
                    }
                    .accessibilityLabel("Change translation")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Audio Bible
                    Button {
                        handleAudioTap()
                    } label: {
                        Image(systemName: audioService.hasActivePlayback
                            ? "mic.circle.fill"
                            : "mic"
                        )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            audioService.hasActivePlayback
                                ? palette.accent
                                : palette.textSecondary
                        )
                    }
                    .accessibilityLabel("Listen to chapter")

                    // Search
                    Button {
                        if searchViewModel == nil {
                            searchViewModel = BibleSearchViewModel(translation: viewModel.currentTranslation)
                        }
                        viewModel.showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                    }
                    .accessibilityLabel("Search Bible")

                    // Chapter navigation
                    Button {
                        performPageFlip(forward: false)
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
                    .accessibilityLabel("Previous chapter")

                    Button {
                        performPageFlip(forward: true)
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
                    .accessibilityLabel("Next chapter")

                    // More options menu
                    Menu {
                        Button {
                            handleImmersiveListeningTap()
                        } label: {
                            Label("Immersive Listening", systemImage: "tv.and.mediabox")
                        }

                        Button {
                            showVoicePicker = true
                        } label: {
                            Label("Voice", systemImage: "person.wave.2")
                        }

                        Button {
                            viewModel.showReaderSettings = true
                        } label: {
                            Label("Reader Settings", systemImage: "textformat.size")
                        }

                        Divider()

                        Picker(selection: Binding(
                            get: { currentColorMode },
                            set: { updateColorMode($0) }
                        )) {
                            Label("Golden Hour", systemImage: "sun.max")
                                .tag(ColorMode.light)
                            Label("Midnight Study", systemImage: "moon")
                                .tag(ColorMode.dark)
                            Label("Auto", systemImage: "circle.lefthalf.filled")
                                .tag(ColorMode.auto)
                        } label: {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                    }
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
        .sheet(isPresented: $viewModel.showSearch) {
            if let searchVM = searchViewModel {
                BibleSearchView(
                    viewModel: searchVM,
                    onSelectResult: { book, chapter, verseNumber in
                        viewModel.navigateToVerse(book: book, chapter: chapter, verseNumber: verseNumber)
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showReaderSettings) {
            ReaderSettingsView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showExplainChat) {
            NavigationStack {
                ChatView(
                    conversationId: explainConversationId,
                    initialContext: explainPrompt
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { shareText != nil },
            set: { if !$0 { shareText = nil } }
        )) {
            if let text = shareText {
                ShareSheetView(items: [text])
            }
        }
        .sheet(isPresented: $showVoicePicker) {
            VoicePickerView(
                audioService: audioService,
                isPro: {
                    let descriptor = FetchDescriptor<UserProfile>()
                    return (try? modelContext.fetch(descriptor).first?.isPro) ?? false
                }()
            ) { voice in
                let wasPlaying = audioService.isPlaying || audioService.isPaused
                let resumeIndex = audioService.currentVerseIndex

                audioService.setVoice(voice)
                // Persist to UserProfile
                let descriptor = FetchDescriptor<UserProfile>()
                if let profile = try? modelContext.fetch(descriptor).first {
                    profile.selectedBibleVoiceID = voice.rawValue
                    try? modelContext.save()
                }

                if wasPlaying && !viewModel.verses.isEmpty {
                    // Restart playback with the new voice from the same verse
                    audioService.play(
                        verses: viewModel.verses,
                        book: viewModel.selectedBook,
                        chapter: viewModel.selectedChapter,
                        translation: viewModel.currentTranslation,
                        startingFromVerseIndex: resumeIndex,
                        versesProvider: versesProvider
                    )
                } else if !viewModel.verses.isEmpty {
                    // Not playing — just prefetch with the new voice
                    audioService.prefetch(
                        verses: viewModel.verses,
                        book: viewModel.selectedBook,
                        chapter: viewModel.selectedChapter,
                        translation: viewModel.currentTranslation,
                        versesProvider: versesProvider
                    )
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: showAudioProGate) { _, show in
            if show {
                showAudioProGate = false
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            SummaryPaywallView()
        }
        .fullScreenCover(isPresented: $showImmersiveListening) {
            ImmersiveListeningView(
                viewModel: viewModel,
                audioService: audioService,
                initialBackground: resolvedBackground,
                wasAlreadyPlaying: audioService.hasActivePlayback
            )
        }
        .onAppear {
            // Load saved voice preference
            let descriptor = FetchDescriptor<UserProfile>()
            if let profile = try? modelContext.fetch(descriptor).first,
               let voice = BibleVoice.voice(for: profile.selectedBibleVoiceID) {
                audioService.setVoice(voice)
            }
        }
        .onChange(of: viewModel.verses.count) {
            // Pre-fetch audio as soon as chapter text is loaded — by the time
            // the user reads a few verses and taps play, the audio is cached.
            guard !viewModel.verses.isEmpty else { return }
            audioService.prefetch(
                verses: viewModel.verses,
                book: viewModel.selectedBook,
                chapter: viewModel.selectedChapter,
                translation: viewModel.currentTranslation,
                versesProvider: versesProvider
            )
        }
        .onChange(of: audioService.currentVerseIndex) { _, newIndex in
            guard audioService.isPlaying, newIndex < viewModel.verses.count else { return }
            let verseNumber = viewModel.verses[newIndex].number
            viewModel.updateLastReadVerse(verseNumber)
        }
        .onChange(of: audioService.isPaused) { _, paused in
            if paused {
                let idx = audioService.currentVerseIndex
                guard idx < viewModel.verses.count else { return }
                let verseNumber = viewModel.verses[idx].number
                viewModel.updateLastReadVerse(verseNumber)
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
