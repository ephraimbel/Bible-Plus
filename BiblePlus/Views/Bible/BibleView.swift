import SwiftUI
import SwiftData
import UIKit

struct BibleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioBibleService.self) private var audioBibleService
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: BibleReaderViewModel?
    @State private var pendingNavBookName: String?
    @State private var pendingNavChapter: Int?
    @State private var pendingNavVerse: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    BibleContentView(viewModel: vm, audioService: audioBibleService)
                } else {
                    BPLoadingView().onAppear {
                        viewModel = BibleReaderViewModel(modelContext: modelContext)
                        applyPendingNavigation()
                    }
                }
            }
            .background(palette.parchment)
            .toolbarBackground(palette.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .scriptureBibleNavigate)) { notification in
                guard let bookName = notification.userInfo?["bookName"] as? String,
                      let chapter = notification.userInfo?["chapter"] as? Int
                else { return }
                let verse = notification.userInfo?["verse"] as? Int ?? 0

                if let vm = viewModel,
                   let book = BibleView.findBook(named: bookName),
                   chapter >= 1, chapter <= book.chapterCount {
                    vm.navigateToVerse(book: book, chapter: chapter, verseNumber: verse)
                } else {
                    pendingNavBookName = bookName
                    pendingNavChapter = chapter
                    pendingNavVerse = verse
                }
            }
        }
    }

    private func applyPendingNavigation() {
        guard let bookName = pendingNavBookName,
              let chapter = pendingNavChapter,
              let vm = viewModel,
              let book = BibleView.findBook(named: bookName),
              chapter >= 1, chapter <= book.chapterCount
        else { return }
        pendingNavBookName = nil
        pendingNavChapter = nil
        let verse = pendingNavVerse
        pendingNavVerse = 0
        vm.navigateToVerse(book: book, chapter: chapter, verseNumber: verse)
    }

    /// Finds a BibleBook by name, handling common variations (e.g. "Psalm" → "Psalms").
    static func findBook(named name: String) -> BibleBook? {
        // Exact match first
        if let book = BibleData.allBooks.first(where: { $0.name == name }) {
            return book
        }
        // Try adding "s" (Psalm → Psalms)
        if let book = BibleData.allBooks.first(where: { $0.name == name + "s" }) {
            return book
        }
        // Try case-insensitive match
        let lowered = name.lowercased()
        if let book = BibleData.allBooks.first(where: { $0.name.lowercased() == lowered }) {
            return book
        }
        return nil
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
    @State private var showVoicePicker = false
    @State private var showImmersiveListening = false
    @State private var showPaywall = false
    @State private var showReadingPlans = false
    @State private var showStillListeningAlert = false
    @State private var verseImageData: (text: String, reference: String, translation: String)?
    @State private var showSanctuary = false
    @State private var sanctuaryVerseText: String?
    @State private var sanctuaryVerseReference: String?
    @State private var selectedVerseFrame: CGRect = .zero
    @State private var pinchStartFontSize: Double?
    @State private var isPinching = false
    @Environment(SoundscapeService.self) private var soundscapeService

    // MARK: - Page Flip State

    @State private var isPageFlipping = false
    @State private var flipAngle: Double = 0
    @State private var flipAnchor: UnitPoint = .leading
    @State private var cachedVerses: [(number: Int, text: String)] = []
    @State private var cachedChapterTitle: String = ""
    @State private var cachedSavedVerseNumbers: Set<Int> = []
    @State private var cachedHighlightColors: [Int: VerseHighlightColor] = [:]
    @State private var cachedVerseNotes: [Int: String] = [:]
    @State private var cachedBookID: String = ""
    @State private var cachedChapterNumber: Int = 0

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
        modelContext.safeSave()
    }

    private var paperColor: Color {
        palette.parchment
    }

    private func createExplainConversation() {
        let title = String(explainPrompt.prefix(40))
        let conversation = Conversation(title: title)
        modelContext.insert(conversation)
        modelContext.safeSave()
        explainConversationId = conversation.id
    }

    // MARK: - Pro Check

    private var isPro: Bool {
        let descriptor = FetchDescriptor<UserProfile>()
        return (try? modelContext.fetch(descriptor).first?.isPro) ?? false
    }

    // MARK: - Audio Bible

    private func handleAudioTap() {
        // Allow pause/resume for active playback
        if audioService.isPlaying || audioService.isPaused {
            audioService.togglePlayback()
            return
        }

        // Pro gate — audio Bible requires subscription
        guard isPro else {
            showPaywall = true
            return
        }

        guard !viewModel.verses.isEmpty else { return }

        // Set up auto-advance. `isAutoAdvance: true` keeps the consecutive
        // counter climbing so the still-listening prompt triggers after a
        // handful of chapters instead of playing indefinitely.
        audioService.setOnChapterComplete { [modelContext] in
            ActivityService.log(.audioChapterCompleted, detail: "\(viewModel.selectedBook.name) \(viewModel.selectedChapter)", in: modelContext)
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
                        isAutoAdvance: true
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
            startingFromVerseIndex: startIndex
        )

        // Prefetch next chapter
        prefetchNextChapter()
    }

    // MARK: - Immersive Listening

    private func handleImmersiveListeningTap() {
        if audioService.hasActivePlayback {
            showImmersiveListening = true
            return
        }

        // Pro gate
        guard isPro else {
            showPaywall = true
            return
        }

        guard !viewModel.verses.isEmpty else { return }

        showImmersiveListening = true
    }

    // MARK: - Prefetch

    private func prefetchNextChapter() {
        guard viewModel.canGoForward else { return }
        let nextChapter = viewModel.selectedChapter + 1
        let book = viewModel.selectedBook
        guard nextChapter <= book.chapterCount else { return }
        let translation = viewModel.currentTranslation
        Task {
            guard let verses = try? await BibleRepository.shared.verses(book: book.id, chapter: nextChapter, translation: translation),
                  !verses.isEmpty else { return }
            audioService.prefetchAudio(
                verses: verses,
                book: book,
                chapter: nextChapter,
                translation: translation
            )
        }
    }

    // MARK: - Page Flip

    private func performPageFlip(forward: Bool) {
        guard !isPageFlipping else { return }

        // Stop audio and cancel prefetches when manually changing chapter
        if audioService.hasActivePlayback {
            audioService.stop()
        }
        audioService.cancelPrefetches()

        // Snapshot the current page content into local state
        cachedVerses = viewModel.verses
        cachedChapterTitle = viewModel.chapterTitle
        cachedSavedVerseNumbers = viewModel.savedVerseNumbers
        cachedHighlightColors = viewModel.highlightColors
        cachedVerseNotes = viewModel.verseNotes
        cachedBookID = viewModel.selectedBook.id
        cachedChapterNumber = viewModel.selectedChapter
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
                    bookID: viewModel.selectedBook.id,
                    chapterNumber: viewModel.selectedChapter,
                    selectedVerseNumbers: viewModel.selectedVerseNumbers,
                    anchorVerseNumber: viewModel.anchorVerseNumber,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    isShowingOfflineFallback: viewModel.isShowingOfflineFallback,
                    offlineTranslationName: viewModel.translationName,
                    savedVerseNumbers: viewModel.savedVerseNumbers,
                    highlightColors: viewModel.highlightColors,
                    verseNotes: viewModel.verseNotes,
                    audioVerseIndex: audioService.isPlaying ? audioService.currentVerseIndex : nil,
                    isAudioPlayerVisible: audioService.hasActivePlayback,
                    lastReadVerseNumber: viewModel.lastReadVerseNumber,
                    readerFontSize: viewModel.readerFontSize,
                    readerFontDesign: viewModel.readerFontDesign,
                    readerFontWeight: viewModel.readerFontWeight.fontWeight,
                    readerLineSpacing: viewModel.readerLineSpacing,
                    readerTextAlignmentJustified: viewModel.readerTextAlignmentJustified,
                    readerShowVerseNumbers: viewModel.readerShowVerseNumbers,
                    onVerseTap: { viewModel.selectVerse($0) },
                    onNoteCardTap: { viewModel.selectVerse($0) },
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
                        bookID: cachedBookID,
                        chapterNumber: cachedChapterNumber,
                        selectedVerseNumbers: [],
                        anchorVerseNumber: nil,
                        isLoading: false,
                        errorMessage: nil,
                        isShowingOfflineFallback: false,
                        offlineTranslationName: "",
                        savedVerseNumbers: cachedSavedVerseNumbers,
                        highlightColors: cachedHighlightColors,
                        verseNotes: cachedVerseNotes,
                        audioVerseIndex: nil,
                        isAudioPlayerVisible: false,
                        lastReadVerseNumber: nil,
                        readerFontSize: viewModel.readerFontSize,
                        readerFontDesign: viewModel.readerFontDesign,
                        readerFontWeight: viewModel.readerFontWeight.fontWeight,
                        readerLineSpacing: viewModel.readerLineSpacing,
                        readerTextAlignmentJustified: viewModel.readerTextAlignmentJustified,
                        readerShowVerseNumbers: viewModel.readerShowVerseNumbers,
                        onVerseTap: { _ in },
                        onNoteCardTap: nil,
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
            .background(palette.parchment)
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Don't let a pinch's centroid drift trigger a chapter flip.
                        guard !isPinching else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                        if value.translation.width < -50 {
                            performPageFlip(forward: true)
                        } else if value.translation.width > 50 {
                            performPageFlip(forward: false)
                        }
                    }
            )
            // Pinch to adjust reading font size — the most common reading tweak,
            // without digging into Reader Settings. Clamped to the same 14–30pt
            // range as the slider and persisted on release.
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        if pinchStartFontSize == nil { pinchStartFontSize = viewModel.readerFontSize }
                        isPinching = true
                        let base = pinchStartFontSize ?? viewModel.readerFontSize
                        let proposed = (base * Double(value.magnification)).rounded()
                        viewModel.readerFontSize = min(max(proposed, 14), 30)
                    }
                    .onEnded { _ in
                        pinchStartFontSize = nil
                        isPinching = false
                        viewModel.persistReaderSettings()
                        HapticService.selection()
                    }
            )

            // Audio error banner
            if let errorMsg = audioService.errorMessage {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.1))
                            )

                        Text(errorMsg)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(2)

                        Spacer()

                        Button {
                            audioService.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(palette.textMuted)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(palette.surface)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
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

            // Verse floating toolbar overlay
            if viewModel.hasSelection {
                VerseToolbarOverlay(
                    reference: viewModel.selectionReference(),
                    isSaved: viewModel.allSelectionSaved,
                    isPro: {
                        let descriptor = FetchDescriptor<UserProfile>()
                        return (try? modelContext.fetch(descriptor).first?.isPro) ?? false
                    }(),
                    currentHighlight: viewModel.commonSelectionHighlight,
                    currentNote: viewModel.anchorNote,
                    verseFrame: selectedVerseFrame,
                    onExplain: {
                        // Verse explain counts toward AI rate limit
                        let profileDescriptor = FetchDescriptor<UserProfile>()
                        let profile = try? modelContext.fetch(profileDescriptor).first
                        let isPro = profile?.isPro ?? false
                        let allMsgDescriptor = FetchDescriptor<ChatMessage>(
                            sortBy: [SortDescriptor(\.createdAt)]
                        )
                        let allMessages = (try? modelContext.fetch(allMsgDescriptor)) ?? []
                        if !AIService.canSendMessage(allMessages: allMessages, isPro: isPro) {
                            viewModel.clearSelection()
                            showPaywall = true
                            return
                        }

                        explainPrompt = viewModel.selectionExplainPrompt()
                        createExplainConversation()
                        viewModel.clearSelection()
                        showExplainChat = true
                    },
                    onCopy: {
                        viewModel.copySelection()
                        // stays open (multi-action)
                    },
                    onShare: {
                        shareText = viewModel.selectionCopyShareText()
                        viewModel.clearSelection()
                    },
                    onSave: {
                        viewModel.saveSelection()
                        // stays open (multi-action)
                    },
                    onUnsave: {
                        viewModel.unsaveSelection()
                        // stays open (multi-action)
                    },
                    onHighlight: { color in
                        viewModel.highlightSelection(color)
                        // stays open (multi-action)
                    },
                    onRemoveHighlight: {
                        viewModel.removeHighlightSelection()
                        // stays open (multi-action)
                    },
                    onSaveNote: { note in
                        if let target = viewModel.anchorVerse {
                            viewModel.saveNote(for: target, note: note)
                        }
                    },
                    onPlayFromHere: {
                        let startNum = viewModel.selectedVerseNumbers.min() ?? 0
                        let verseIndex = viewModel.verses.firstIndex(where: { $0.number == startNum }) ?? 0
                        viewModel.clearSelection()

                        if audioService.hasActivePlayback {
                            audioService.seekToVerse(index: verseIndex)
                        } else {
                            // Pro gate
                            guard isPro else {
                                showPaywall = true
                                return
                            }

                            audioService.setOnChapterComplete { [modelContext] in
                                ActivityService.log(.audioChapterCompleted, detail: "\(viewModel.selectedBook.name) \(viewModel.selectedChapter)", in: modelContext)
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
                                            isAutoAdvance: true
                                        )
                                    }
                                }
                            }

                            audioService.play(
                                verses: viewModel.verses,
                                book: viewModel.selectedBook,
                                chapter: viewModel.selectedChapter,
                                translation: viewModel.currentTranslation,
                                startingFromVerseIndex: verseIndex
                            )
                        }
                    },
                    onCreateVerseImage: {
                        verseImageData = (
                            text: viewModel.selectionText(),
                            reference: viewModel.selectionReference(),
                            translation: viewModel.currentTranslation.abbreviation
                        )
                        viewModel.clearSelection()
                    },
                    onMeditateInSanctuary: {
                        sanctuaryVerseText = viewModel.selectionText()
                        sanctuaryVerseReference = viewModel.selectionReference()
                        viewModel.clearSelection()
                        showSanctuary = true
                    },
                    onShowPaywall: {
                        viewModel.clearSelection()
                        showPaywall = true
                    },
                    onDismiss: {
                        viewModel.clearSelection()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .coordinateSpace(name: "bibleContent")
        .onPreferenceChange(SelectedVerseFrameKey.self) { frame in
            if frame != .zero { selectedVerseFrame = frame }
        }
        .animation(BPAnimation.spring, value: viewModel.anchorVerseNumber)
        .animation(BPAnimation.spring, value: audioService.hasActivePlayback)
        .animation(.easeInOut(duration: 0.3), value: audioService.errorMessage != nil)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // MARK: Leading — Chapter Navigation
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    Button {
                        performPageFlip(forward: false)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(viewModel.canGoBack ? palette.accent : palette.textMuted)
                    }
                    .disabled(!viewModel.canGoBack)
                    .accessibilityLabel("Previous chapter")

                    Button {
                        performPageFlip(forward: true)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(viewModel.canGoForward ? palette.accent : palette.textMuted)
                    }
                    .disabled(!viewModel.canGoForward)
                    .accessibilityLabel("Next chapter")
                }
                // Reserve equal width to the trailing group so the principal
                // title+translation centers on screen for any book name / device.
                .frame(width: 104, alignment: .leading)
            }

            // MARK: Center — Book Title · Translation
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Button {
                        viewModel.showBookPicker = true
                    } label: {
                        HStack(spacing: 3) {
                            Text(viewModel.chapterTitle)
                                .font(.system(size: 17, weight: .semibold, design: .serif))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(palette.textPrimary)
                    }
                    .accessibilityLabel("Choose book and chapter")

                    Button {
                        viewModel.showTranslationPicker = true
                    } label: {
                        HStack(spacing: 3) {
                            Text(viewModel.currentTranslation.apiCode)
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .foregroundStyle(palette.accent)
                        .frame(minWidth: 46)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(palette.accent.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                    .accessibilityLabel("Change translation")
                }
            }

            // MARK: Trailing — Search + Overflow
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 6) {
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

                    // Reading Plans
                    Button {
                        showReadingPlans = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                    }
                    .accessibilityLabel("Reading Plans")

                    // More options menu
                    Menu {
                        Section {
                            Button {
                                handleAudioTap()
                            } label: {
                                Label(
                                    audioService.hasActivePlayback ? "Pause Audio" : "Listen to Chapter",
                                    systemImage: audioService.hasActivePlayback ? "pause.circle" : "headphones"
                                )
                            }

                            Button {
                                handleImmersiveListeningTap()
                            } label: {
                                Label("Immersive Listening", systemImage: "tv.and.mediabox")
                            }

                            Button {
                                showVoicePicker = true
                            } label: {
                                Label("Narrator Voice", systemImage: "person.wave.2")
                            }
                        }

                        Section {
                            Button {
                                viewModel.showReaderSettings = true
                            } label: {
                                Label("Reader Settings", systemImage: "textformat.size")
                            }

                            Picker(selection: Binding(
                                get: { currentColorMode },
                                set: { updateColorMode($0) }
                            )) {
                                Label("Light", systemImage: "sun.max")
                                    .tag(ColorMode.light)
                                Label("Dark", systemImage: "moon")
                                    .tag(ColorMode.dark)
                                Label("Auto", systemImage: "circle.lefthalf.filled")
                                    .tag(ColorMode.auto)
                            } label: {
                                Label("Appearance", systemImage: "circle.lefthalf.filled")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                    }
                }
                // Matches the leading group's reserved width so the centered
                // title stays screen-centered, not biased toward either side.
                .frame(width: 104, alignment: .trailing)
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
                },
                activeRefID: viewModel.currentRefID,
                currentBookID: viewModel.selectedBook.id,
                currentChapter: viewModel.selectedChapter
            )
        }
        .sheet(isPresented: $viewModel.showTranslationPicker) {
            BibleTranslationPickerView(
                currentTranslation: viewModel.currentTranslation,
                currentRefID: viewModel.currentRefID,
                isPro: isPro,
                onSelectLegacy: { viewModel.changeTranslation($0) },
                onSelectRef: { viewModel.changeTranslationRef($0.id) }
            )
            .presentationDetents([.medium, .large])
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
                .presentationDetents([.large])
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
        .sheet(isPresented: Binding(
            get: { verseImageData != nil },
            set: { if !$0 { verseImageData = nil } }
        )) {
            if let data = verseImageData {
                VerseImageSheet(
                    verseText: data.text,
                    reference: data.reference,
                    translation: data.translation,
                    isPro: {
                        let descriptor = FetchDescriptor<UserProfile>()
                        return (try? modelContext.fetch(descriptor).first?.isPro) ?? false
                    }()
                )
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
                    modelContext.safeSave()
                }

                if wasPlaying && !viewModel.verses.isEmpty {
                    // Restart playback with the new voice from the same verse
                    audioService.play(
                        verses: viewModel.verses,
                        book: viewModel.selectedBook,
                        chapter: viewModel.selectedChapter,
                        translation: viewModel.currentTranslation,
                        startingFromVerseIndex: resumeIndex
                    )
                }

                // Prefetch next chapter with new voice
                prefetchNextChapter()
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainerView()
        }
        .sheet(isPresented: $showReadingPlans) {
            ReadingPlansView(
                isPro: {
                    let descriptor = FetchDescriptor<UserProfile>()
                    return (try? modelContext.fetch(descriptor).first?.isPro) ?? false
                }()
            )
        }
        .fullScreenCover(isPresented: $showImmersiveListening) {
            ImmersiveListeningView(
                viewModel: viewModel,
                audioService: audioService,
                initialBackground: resolvedBackground,
                wasAlreadyPlaying: audioService.hasActivePlayback
            )
        }
        .fullScreenCover(isPresented: $showSanctuary) {
            SanctuaryView(
                soundscapeService: soundscapeService,
                verseText: sanctuaryVerseText,
                verseReference: sanctuaryVerseReference
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
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: audioService.currentVerseIndex) { _, newIndex in
            guard audioService.isPlaying, newIndex < viewModel.verses.count else { return }
            let verseNumber = viewModel.verses[newIndex].number
            viewModel.updateLastReadVerse(verseNumber)
        }
        .onChange(of: audioService.showStillListeningPrompt) { _, showing in
            showStillListeningAlert = showing
        }
        .alert("Still listening?", isPresented: $showStillListeningAlert) {
            Button("Keep going") { audioService.confirmStillListening() }
            Button("Stop", role: .cancel) { audioService.dismissStillListening() }
        } message: {
            Text("You've listened for a while. Tap Keep going to continue, or Stop to pause playback.")
        }
        .onChange(of: audioService.isPaused) { _, paused in
            if paused {
                let idx = audioService.currentVerseIndex
                guard idx < viewModel.verses.count else { return }
                let verseNumber = viewModel.verses[idx].number
                viewModel.updateLastReadVerse(verseNumber)
            }
        }
        .onChange(of: viewModel.verses.count) {
            // Prefetch audio for this chapter as soon as verses load
            guard isPro, !viewModel.verses.isEmpty else { return }
            audioService.prefetchCurrentChapter(
                verses: viewModel.verses,
                book: viewModel.selectedBook,
                chapter: viewModel.selectedChapter
            )
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
