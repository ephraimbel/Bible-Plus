import AVFoundation
import Foundation

@Observable
@MainActor
final class AudioBibleService {
    // MARK: - Playback State

    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var currentVerseIndex: Int = 0
    private(set) var errorMessage: String? = nil
    var playbackSpeed: PlaybackSpeed = .normal

    // MARK: - Internal

    private var player: AVAudioPlayer?
    private var verseTimings: [VerseTiming] = []
    private var progressTimer: Task<Void, Never>?
    private var generateTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Audio Session Coordination

    private weak var soundscapeService: SoundscapeService?
    private var savedSoundscapeVolume: Float = 0.3

    // MARK: - Chapter Complete Callback

    private var onChapterComplete: (() -> Void)?

    // MARK: - Rate Limiting

    static let freeChapterLimit = 1
    private static let usageKey = "audioBibleDailyUsage"
    private static let usageDateKey = "audioBibleUsageDate"

    // MARK: - Voice

    var selectedVoice: BibleVoice = .onyx

    // MARK: - Prefetch

    private var prefetchTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        setupInterruptionHandling()
    }

    func setSoundscapeService(_ service: SoundscapeService) {
        self.soundscapeService = service
    }

    // MARK: - Prefetch Audio (background generation before user taps play)

    /// Call when a chapter is displayed. Generates audio in the background so
    /// tapping play is instant. Safe to call multiple times — checks cache first.
    func prefetch(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation
    ) {
        prefetchTask?.cancel()
        guard !verses.isEmpty else { return }

        // Skip if already cached
        let voice = selectedVoice
        let cacheKey = Self.makeCacheKey(book: book, chapter: chapter, translation: translation, voice: voice)
        let cacheURL = Self.cacheFileURL(for: cacheKey)
        if FileManager.default.fileExists(atPath: cacheURL.path) { return }

        prefetchTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            _ = try? await self.fetchOrGenerateAudio(
                verses: verses,
                book: book,
                chapter: chapter,
                translation: translation,
                voice: voice
            )
        }
    }

    /// Pre-generates the next chapter's audio during playback so chapter
    /// auto-advance feels seamless.
    func prefetchNextChapter(
        currentBook: BibleBook,
        currentChapter: Int,
        translation: BibleTranslation,
        versesProvider: @escaping (BibleBook, Int) async -> [(number: Int, text: String)]
    ) {
        let nextBook: BibleBook
        let nextChapter: Int

        if currentChapter < currentBook.chapterCount {
            nextBook = currentBook
            nextChapter = currentChapter + 1
        } else if let idx = BibleData.allBooks.firstIndex(of: currentBook),
                  idx + 1 < BibleData.allBooks.count {
            nextBook = BibleData.allBooks[idx + 1]
            nextChapter = 1
        } else {
            return // Last chapter of Revelation — nothing to prefetch
        }

        // Skip if already cached
        let voice = selectedVoice
        let cacheKey = Self.makeCacheKey(book: nextBook, chapter: nextChapter, translation: translation, voice: voice)
        let cacheURL = Self.cacheFileURL(for: cacheKey)
        if FileManager.default.fileExists(atPath: cacheURL.path) { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let verses = await versesProvider(nextBook, nextChapter)
            guard !verses.isEmpty else { return }
            _ = try? await self.fetchOrGenerateAudio(
                verses: verses,
                book: nextBook,
                chapter: nextChapter,
                translation: translation,
                voice: voice
            )
        }
    }

    /// Check if audio for the given chapter is already cached on disk.
    static func isCached(book: BibleBook, chapter: Int, translation: BibleTranslation, voice: BibleVoice = .onyx) -> Bool {
        let cacheKey = makeCacheKey(book: book, chapter: chapter, translation: translation, voice: voice)
        return FileManager.default.fileExists(atPath: cacheFileURL(for: cacheKey).path)
    }

    // MARK: - Play Chapter

    func play(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        startingFromVerseIndex: Int = 0,
        versesProvider: ((BibleBook, Int) async -> [(number: Int, text: String)])? = nil
    ) {
        stop()
        prefetchTask?.cancel() // No longer needed — we're playing now

        guard !verses.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        currentVerseIndex = startingFromVerseIndex

        let voice = selectedVoice
        generateTask = Task {
            do {
                let audioData = try await fetchOrGenerateAudio(
                    verses: verses,
                    book: book,
                    chapter: chapter,
                    translation: translation,
                    voice: voice
                )
                guard !Task.isCancelled else { return }

                let audioPlayer = try AVAudioPlayer(data: audioData)
                audioPlayer.enableRate = true
                audioPlayer.rate = Float(playbackSpeed.rawValue)
                audioPlayer.prepareToPlay()

                self.verseTimings = Self.calculateTimings(
                    verses: verses,
                    totalDuration: audioPlayer.duration
                )
                self.player = audioPlayer

                // Seek to the requested verse
                if startingFromVerseIndex > 0,
                   startingFromVerseIndex < self.verseTimings.count {
                    audioPlayer.currentTime = self.verseTimings[startingFromVerseIndex].startTime
                }

                configureAudioSession()
                duckSoundscape()

                audioPlayer.play()
                isPlaying = true
                isPaused = false
                isLoading = false

                startProgressTracking()
                incrementDailyUsage()

                // Pre-fetch the next chapter while this one plays
                if let provider = versesProvider {
                    prefetchNextChapter(
                        currentBook: book,
                        currentChapter: chapter,
                        translation: translation,
                        versesProvider: provider
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Seek to Verse

    func seekToVerse(index: Int) {
        guard let player,
              index >= 0,
              index < verseTimings.count
        else { return }

        player.currentTime = verseTimings[index].startTime
        currentVerseIndex = index

        if isPaused {
            resume()
        }
    }

    // MARK: - Pause / Resume / Stop

    func pause() {
        player?.pause()
        isPlaying = false
        isPaused = true
        progressTimer?.cancel()
        restoreSoundscape()
    }

    func resume() {
        guard let player, isPaused else { return }
        configureAudioSession()
        duckSoundscape()
        player.play()
        isPlaying = true
        isPaused = false
        startProgressTracking()
    }

    func stop() {
        generateTask?.cancel()
        generateTask = nil
        progressTimer?.cancel()
        progressTimer = nil

        player?.stop()
        player = nil

        isPlaying = false
        isPaused = false
        isLoading = false
        currentVerseIndex = 0
        verseTimings = []
        errorMessage = nil

        restoreSoundscape()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }

    // MARK: - Speed Control

    func setSpeed(_ speed: PlaybackSpeed) {
        playbackSpeed = speed
        player?.rate = Float(speed.rawValue)
    }

    var hasActivePlayback: Bool {
        isPlaying || isPaused || isLoading
    }

    func setOnChapterComplete(_ handler: @escaping () -> Void) {
        onChapterComplete = handler
    }

    // MARK: - TTS Generation

    private func fetchOrGenerateAudio(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        voice: BibleVoice = .onyx
    ) async throws -> Data {
        let cacheKey = Self.makeCacheKey(book: book, chapter: chapter, translation: translation, voice: voice)
        let cacheURL = Self.cacheFileURL(for: cacheKey)

        // Check disk cache
        if let cached = try? Data(contentsOf: cacheURL) {
            return cached
        }

        // Build narration text
        let chapterText = buildNarrationText(
            verses: verses,
            bookName: book.name,
            chapter: chapter
        )

        // OpenAI TTS has 4096 char limit — split long chapters
        let audioData: Data
        if chapterText.count <= 4000 {
            audioData = try await callTTSAPI(text: chapterText, voice: voice)
        } else {
            audioData = try await generateLongChapter(
                verses: verses,
                bookName: book.name,
                chapter: chapter,
                voice: voice
            )
        }

        // Write to disk cache
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        try? audioData.write(to: cacheURL, options: .atomic)

        return audioData
    }

    private func buildNarrationText(
        verses: [(number: Int, text: String)],
        bookName: String,
        chapter: Int
    ) -> String {
        var parts: [String] = []
        parts.append("\(bookName), chapter \(chapter).")
        for verse in verses {
            parts.append(verse.text)
        }
        return parts.joined(separator: " ")
    }

    private func generateLongChapter(
        verses: [(number: Int, text: String)],
        bookName: String,
        chapter: Int,
        voice: BibleVoice = .onyx
    ) async throws -> Data {
        var segments: [[(number: Int, text: String)]] = []
        var current: [(number: Int, text: String)] = []
        var currentLen = "\(bookName), chapter \(chapter). ".count

        for verse in verses {
            let verseLen = verse.text.count + 1
            if currentLen + verseLen > 3800 && !current.isEmpty {
                segments.append(current)
                current = []
                currentLen = 0
            }
            current.append(verse)
            currentLen += verseLen
        }
        if !current.isEmpty { segments.append(current) }

        var allData = Data()
        for (i, segment) in segments.enumerated() {
            guard !Task.isCancelled else { throw CancellationError() }

            let prefix = i == 0 ? "\(bookName), chapter \(chapter). " : ""
            let text = prefix + segment.map(\.text).joined(separator: " ")
            let segmentData = try await callTTSAPI(text: text, voice: voice)
            allData.append(segmentData)
        }

        return allData
    }

    private func callTTSAPI(text: String, voice: BibleVoice = .onyx) async throws -> Data {
        let endpoint = URL(string: "https://api.openai.com/v1/audio/speech")!
        let body: [String: Any] = [
            "model": "tts-1-hd",
            "input": text,
            "voice": voice.apiVoice,
            "response_format": "mp3",
            "speed": 1.0
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(Secrets.openAIAPIKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudioBibleError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw AudioBibleError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }
        guard !data.isEmpty else {
            throw AudioBibleError.emptyAudioData
        }

        return data
    }

    // MARK: - Verse Timing Estimation

    private static func calculateTimings(
        verses: [(number: Int, text: String)],
        totalDuration: TimeInterval
    ) -> [VerseTiming] {
        guard !verses.isEmpty, totalDuration > 0 else { return [] }

        let totalChars = verses.reduce(0) { $0 + $1.text.count }
        guard totalChars > 0 else { return [] }

        var timings: [VerseTiming] = []
        var cumulativeTime: TimeInterval = 0

        for (index, verse) in verses.enumerated() {
            let proportion = Double(verse.text.count) / Double(totalChars)
            let verseDuration = proportion * totalDuration
            let startTime = cumulativeTime
            let endTime = cumulativeTime + verseDuration
            timings.append(VerseTiming(
                verseIndex: index,
                startTime: startTime,
                endTime: endTime
            ))
            cumulativeTime = endTime
        }

        return timings
    }

    // MARK: - Progress Tracking

    private func startProgressTracking() {
        progressTimer?.cancel()
        progressTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                guard !Task.isCancelled, let self else { return }

                guard let player = self.player else { return }

                // Check if playback finished
                if !player.isPlaying && self.isPlaying && !self.isPaused {
                    self.handlePlaybackCompletion()
                    return
                }

                let currentTime = player.currentTime

                for timing in self.verseTimings {
                    if currentTime >= timing.startTime && currentTime < timing.endTime {
                        if self.currentVerseIndex != timing.verseIndex {
                            self.currentVerseIndex = timing.verseIndex
                        }
                        break
                    }
                }

                if let last = self.verseTimings.last, currentTime >= last.endTime {
                    self.currentVerseIndex = last.verseIndex
                }
            }
        }
    }

    private func handlePlaybackCompletion() {
        isPlaying = false
        isPaused = false
        progressTimer?.cancel()
        restoreSoundscape()
        onChapterComplete?()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {}
    }

    private func duckSoundscape() {
        guard let ss = soundscapeService else { return }
        savedSoundscapeVolume = ss.volume
        if ss.isPlaying {
            ss.setVolume(savedSoundscapeVolume * 0.2)
        }
    }

    private func restoreSoundscape() {
        guard let ss = soundscapeService else { return }
        ss.setVolume(savedSoundscapeVolume)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
        } catch {}
    }

    // MARK: - Interruption Handling

    private func setupInterruptionHandling() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                switch type {
                case .began:
                    if self.isPlaying { self.pause() }
                case .ended:
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) && self.isPaused {
                            self.resume()
                        }
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Voice Selection

    func setVoice(_ voice: BibleVoice) {
        selectedVoice = voice
    }

    // MARK: - Cache

    private static func makeCacheKey(book: BibleBook, chapter: Int, translation: BibleTranslation, voice: BibleVoice) -> String {
        "\(book.id)-\(chapter)-\(translation.apiCode)-\(voice.rawValue)"
    }

    private static func cacheFileURL(for key: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("AudioBible", isDirectory: true)
            .appendingPathComponent("\(key).mp3")
    }

    // MARK: - Rate Limiting

    static func chaptersUsedToday() -> Int {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        let stored = defaults.object(forKey: usageDateKey) as? Date ?? .distantPast
        let storedDay = Calendar.current.startOfDay(for: stored)
        if storedDay < today {
            defaults.set(0, forKey: usageKey)
            defaults.set(today, forKey: usageDateKey)
            return 0
        }
        return defaults.integer(forKey: usageKey)
    }

    static func canPlayChapter(isPro: Bool) -> Bool {
        if isPro { return true }
        return chaptersUsedToday() < freeChapterLimit
    }

    private func incrementDailyUsage() {
        let current = Self.chaptersUsedToday()
        UserDefaults.standard.set(current + 1, forKey: Self.usageKey)
        UserDefaults.standard.set(Date(), forKey: Self.usageDateKey)
    }

    static var remainingFreeChapters: Int {
        max(0, freeChapterLimit - chaptersUsedToday())
    }
}

// MARK: - Supporting Types

private struct VerseTiming {
    let verseIndex: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
}

enum AudioBibleError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyAudioData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Received an invalid response. Please try again."
        case .apiError(let code, _):
            "Audio generation failed (\(code)). Please try again."
        case .emptyAudioData:
            "No audio was generated. Please try again."
        }
    }
}
