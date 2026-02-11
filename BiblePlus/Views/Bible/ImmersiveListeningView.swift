import SwiftUI
import SwiftData

struct ImmersiveListeningView: View {
    @Bindable var viewModel: BibleReaderViewModel
    let audioService: AudioBibleService
    let initialBackground: SanctuaryBackground
    let wasAlreadyPlaying: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    @State private var displayedVerseIndex: Int = 0
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var currentBackground: SanctuaryBackground?
    @State private var showBackgroundPicker = false

    private var background: SanctuaryBackground {
        currentBackground ?? initialBackground
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1: Background
            backgroundLayer

            // Layer 2: Tap target for show/hide controls
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleControls()
                }

            // Layer 3: Content
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 12)
                    .opacity(controlsVisible ? 1 : 0)

                Spacer()

                verseDisplay

                Spacer()

                controlsBar
                    .padding(.bottom, 44)
                    .opacity(controlsVisible ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .sheet(isPresented: $showBackgroundPicker) {
            ListeningBackgroundPickerView(
                selectedBackground: background,
                isPro: {
                    let descriptor = FetchDescriptor<UserProfile>()
                    return (try? modelContext.fetch(descriptor).first?.isPro) ?? false
                }()
            ) { bg in
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentBackground = bg
                }
                // Persist to UserProfile
                let descriptor = FetchDescriptor<UserProfile>()
                if let profile = try? modelContext.fetch(descriptor).first {
                    profile.selectedBackgroundID = bg.id
                    profile.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        }
        .onAppear {
            if wasAlreadyPlaying {
                displayedVerseIndex = audioService.currentVerseIndex
            } else {
                setupAutoAdvance()
                guard !viewModel.verses.isEmpty else { return }
                audioService.play(
                    verses: viewModel.verses,
                    book: viewModel.selectedBook,
                    chapter: viewModel.selectedChapter,
                    translation: viewModel.currentTranslation,
                    versesProvider: versesProvider
                )
            }
            scheduleHide()
        }
        .onDisappear {
            hideTask?.cancel()
        }
        .onChange(of: audioService.currentVerseIndex) { _, newIndex in
            withAnimation(.easeInOut(duration: 0.5)) {
                displayedVerseIndex = newIndex
            }
        }
        .onChange(of: viewModel.chapterTitle) {
            displayedVerseIndex = 0
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: background.gradientColors.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let videoName = background.videoFileName {
                LoopingVideoPlayer(videoName: videoName)
            } else if let imageName = background.imageName,
                      let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("LISTENING")
                    .font(BPFont.caption)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))

                Text(viewModel.chapterTitle)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial.opacity(0.5))
                        .clipShape(Circle())
                }
                Spacer()
                Button {
                    showBackgroundPicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Verse Display

    private var verseDisplay: some View {
        VStack(spacing: 16) {
            if viewModel.verses.isEmpty {
                ProgressView()
                    .tint(.white)
            } else {
                let verse = currentVerse

                Text(verse.text)
                    .font(verseFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .padding(.horizontal, 32)
                    .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 0)
                    .id(verseIdentity)
                    .transition(.opacity)

                Text(verseReference)
                    .font(BPFont.reference)
                    .foregroundStyle(.white.opacity(0.6))
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    .id("ref-\(verseIdentity)")
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: verseIdentity)
    }

    private var currentVerse: (number: Int, text: String) {
        let idx = min(displayedVerseIndex, viewModel.verses.count - 1)
        return viewModel.verses[max(idx, 0)]
    }

    private var verseIdentity: String {
        "\(viewModel.chapterTitle)-\(displayedVerseIndex)"
    }

    private var verseReference: String {
        guard !viewModel.verses.isEmpty else { return "" }
        let verse = currentVerse
        return "\(viewModel.selectedBook.name) \(viewModel.selectedChapter):\(verse.number)"
    }

    private var verseFont: Font {
        let text = viewModel.verses.isEmpty ? "" : currentVerse.text
        return text.count > 300 ? BPFont.prayerSmall : BPFont.prayerMedium
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        VStack(spacing: 16) {
            // Progress bar
            progressBar

            // Transport controls
            HStack(spacing: 28) {
                // Speed
                Button {
                    cycleSpeed()
                } label: {
                    Text(audioService.playbackSpeed.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 44, height: 32)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                }

                // Previous verse
                Button {
                    seekToPreviousVerse()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(displayedVerseIndex > 0 ? 0.9 : 0.3))
                }
                .disabled(displayedVerseIndex <= 0)

                // Play / Pause
                Button {
                    if audioService.isLoading {
                        return
                    }
                    audioService.togglePlayback()
                    scheduleHide()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)

                        if audioService.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.black)
                                .offset(x: audioService.isPlaying ? 0 : 2)
                        }
                    }
                }

                // Next verse
                Button {
                    seekToNextVerse()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(
                            displayedVerseIndex < viewModel.verses.count - 1 ? 0.9 : 0.3
                        ))
                }
                .disabled(displayedVerseIndex >= viewModel.verses.count - 1)

                // Spacer to balance layout
                Color.clear
                    .frame(width: 44, height: 32)
            }

            // Verse counter
            if !viewModel.verses.isEmpty {
                Text("Verse \(displayedVerseIndex + 1) of \(viewModel.verses.count)")
                    .font(BPFont.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            let total = max(viewModel.verses.count, 1)
            let progress = Double(displayedVerseIndex + 1) / Double(total)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 3)

                Capsule()
                    .fill(palette.accent)
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: displayedVerseIndex)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Auto-Advance

    private func setupAutoAdvance() {
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
    }

    private func versesProvider(book: BibleBook, chapter: Int) async -> [(number: Int, text: String)] {
        let repo = BibleRepository.shared
        return (try? await repo.verses(book: book.id, chapter: chapter)) ?? []
    }

    // MARK: - Controls Logic

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.25)) {
            controlsVisible.toggle()
        }
        if controlsVisible {
            scheduleHide()
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            guard audioService.isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                controlsVisible = false
            }
        }
    }

    private func cycleSpeed() {
        let all = PlaybackSpeed.allCases
        if let idx = all.firstIndex(of: audioService.playbackSpeed) {
            let next = all[(idx + 1) % all.count]
            audioService.setSpeed(next)
        }
        HapticService.lightImpact()
        scheduleHide()
    }

    private func seekToPreviousVerse() {
        guard displayedVerseIndex > 0 else { return }
        audioService.seekToVerse(index: displayedVerseIndex - 1)
        HapticService.lightImpact()
        scheduleHide()
    }

    private func seekToNextVerse() {
        guard displayedVerseIndex < viewModel.verses.count - 1 else { return }
        audioService.seekToVerse(index: displayedVerseIndex + 1)
        HapticService.lightImpact()
        scheduleHide()
    }
}

// MARK: - Background Picker

private struct ListeningBackgroundPickerView: View {
    let selectedBackground: SanctuaryBackground
    let isPro: Bool
    let onSelect: (SanctuaryBackground) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(BackgroundCollection.allCases) { collection in
                        let backgrounds = SanctuaryBackground.backgrounds(in: collection)
                        if !backgrounds.isEmpty {
                            Section {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(backgrounds) { bg in
                                        backgroundCard(bg, locked: bg.isProOnly && !isPro)
                                    }
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Text(collection.displayName)
                                        .font(BPFont.button)
                                        .foregroundStyle(.secondary)

                                    if collection.isProOnly {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(hex: "C9A96E"))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(palette.background)
            .navigationTitle("Backgrounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(palette.background)
    }

    @ViewBuilder
    private func backgroundCard(_ bg: SanctuaryBackground, locked: Bool) -> some View {
        Button {
            if !locked {
                HapticService.selection()
                onSelect(bg)
            }
        } label: {
            ZStack {
                if let imageName = bg.imageName,
                   let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1.2, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: bg.gradientColors.map { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(1.2, contentMode: .fit)
                }

                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.2))

                VStack(spacing: 4) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if selectedBackground.id == bg.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }

                    Text(bg.name)
                        .font(BPFont.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                if bg.hasVideo || bg.hasImage {
                    VStack {
                        HStack {
                            Spacer()
                            Text(bg.hasVideo ? "ANIMATED" : "IMAGE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "C9A96E").opacity(0.85))
                                .clipShape(Capsule())
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .opacity(locked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }
}
