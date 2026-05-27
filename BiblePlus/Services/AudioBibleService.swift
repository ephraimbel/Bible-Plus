import ActivityKit
import AVFoundation
import CryptoKit
import Foundation
import UIKit

// MARK: - Audio Bible Error

enum AudioBibleError: Error, LocalizedError {
    case noVerses
    case networkError(Error)
    case apiError(String)
    case audioDecodingFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noVerses: "No verses to play"
        case .networkError: "Network error — using device voice"
        case .apiError(let msg): msg
        case .audioDecodingFailed: "Audio decoding failed"
        case .cancelled: "Playback cancelled"
        }
    }
}

// MARK: - Audio Bible Service

@Observable
@MainActor
final class AudioBibleService {
    // MARK: - Playback State

    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var currentVerseIndex: Int = 0
    var errorMessage: String? = nil
    var playbackSpeed: PlaybackSpeed = .normal

    // MARK: - Voice

    var selectedVoice: BibleVoice = .onyx

    // MARK: - AVQueuePlayer (per-verse streaming playback)

    private var queuePlayer: AVQueuePlayer?
    private var playerItems: [AVPlayerItem] = []
    private var itemToVerseIndex: [AVPlayerItem: Int] = [:]
    nonisolated(unsafe) private var playerObserver: NSObjectProtocol?
    /// Periodic observer that keeps `currentVerseIndex` (and thus the on-screen
    /// highlight) locked to whatever item is actually playing — so the
    /// highlight never drifts behind the audio over a long chapter.
    nonisolated(unsafe) private var timeObserverToken: Any?
    private var tempFileURLs: [URL] = []

    // MARK: - Speech Fallback

    private var speechSynthesizer: AVSpeechSynthesizer?
    private var speechDelegate: SpeechDelegate?
    private var isFallbackMode: Bool = false

    // MARK: - Current Chapter Info

    private var currentVerses: [(number: Int, text: String)] = []
    private var currentBook: BibleBook?
    private var currentChapter: Int = 0
    private var currentTranslation: BibleTranslation = .kjv
    private var currentBookName: String = ""
    private var currentTranslationName: String = ""
    private var currentTotalVerses: Int = 0

    // MARK: - Audio Session Coordination

    private weak var soundscapeService: SoundscapeService?
    private var savedSoundscapeVolume: Float = 0.3

    // MARK: - Chapter Complete Callback

    private var onChapterComplete: (() -> Void)?

    // MARK: - Streaming State
    //
    // `hasQueuedAllVerses` flips to true only once every verse in the
    // current chapter has been fetched and inserted into the queue. Until
    // then, an empty queue means "waiting on more audio," NOT "chapter
    // done." Before this flag existed, a slow TTS stream caused audio to
    // cut after the first 2-4 verses because the queue drained faster
    // than verses could arrive, which fired premature chapter completion.
    private var hasQueuedAllVerses: Bool = false

    // MARK: - Still-Listening Safeguard
    //
    // After this many consecutive auto-advances (no user interaction),
    // playback pauses and prompts the user to confirm they're still
    // listening. Prevents audio running all night when someone falls
    // asleep, which would drive both the TTS cost and battery drain sky
    // high. If the user doesn't answer the prompt within
    // `stillListeningTimeoutSeconds`, playback stops automatically.
    var showStillListeningPrompt: Bool = false
    private var consecutiveAutoAdvances: Int = 0
    private var stillListeningTimeoutTask: Task<Void, Never>?
    private static let stillListeningThreshold: Int = 4
    private static let stillListeningTimeoutSeconds: TimeInterval = 60

    // MARK: - Live Activity

    private var bibleActivity: Activity<BibleSessionAttributes>?
    /// When true, the internal stop() done at the start of an auto-advanced
    /// play() leaves the Live Activity alive so it can be UPDATED for the next
    /// chapter rather than ended + recreated (recreation made a dismissed
    /// activity keep reappearing each chapter).
    private var preserveActivityOnStop = false

    /// Starts the session's Live Activity if there isn't one, otherwise updates
    /// the existing one — so a single activity carries through every chapter.
    private func syncLiveActivity(isPlaying: Bool) {
        guard let book = currentBook else { return }
        if let activity = bibleActivity {
            LiveActivityService.updateBibleSession(
                activity,
                bookName: book.name,
                chapter: currentChapter,
                translationName: currentTranslation.abbreviation,
                totalVerses: currentTotalVerses,
                currentVerse: currentVerseIndex + 1,
                isPlaying: isPlaying
            )
        } else {
            bibleActivity = LiveActivityService.startBibleSession(
                bookName: book.name,
                chapter: currentChapter,
                translationName: currentTranslation.abbreviation,
                totalVerses: currentTotalVerses,
                currentVerse: currentVerseIndex + 1
            )
        }
    }

    // MARK: - Interruption Handling

    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    // MARK: - Auto-Stop (Background Timer)

    nonisolated(unsafe) private var backgroundObserver: NSObjectProtocol?
    nonisolated(unsafe) private var foregroundObserver: NSObjectProtocol?
    private var autoStopTask: Task<Void, Never>?
    private static let autoStopDelay: TimeInterval = 120

    // MARK: - Network Task

    private var fetchTask: Task<Void, Never>?
    private var prefetchTasks: [Task<Void, Never>] = []

    // MARK: - Prefetch Deduplication

    /// Tracks chapter keys currently being prefetched to avoid duplicate work.
    private var prefetchingChapters: Set<String> = []

    // MARK: - Concurrency

    /// Max parallel TTS requests for verse generation. Kept modest so a long
    /// listening session doesn't burst the TTS API into rate-limiting (which
    /// used to throw and drop playback to the robotic device voice).
    private static let maxConcurrentFetches = 4

    /// How many times to retry a single verse's TTS fetch before giving up.
    /// Rate-limit (429), server (5xx), and transient network errors are all
    /// retried with exponential backoff so we stay on the premium AI voice
    /// instead of falling back to the device synthesizer.
    private static let maxFetchRetries = 4

    // MARK: - Cache Directory

    private nonisolated static var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioBibleCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private nonisolated static var tempDirectory: URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioBibleTemp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - TTS Endpoint

    private nonisolated static let ttsEndpoint = URL(string: "\(Secrets.supabaseURL)/functions/v1/tts")!

    // MARK: - Init

    init() {
        Self.cleanupOrphanedTempFiles()
        setupInterruptionHandling()
        setupBackgroundObservers()
    }

    deinit {
        let i = interruptionObserver
        let b = backgroundObserver
        let f = foregroundObserver
        let p = playerObserver
        if let obs = i { NotificationCenter.default.removeObserver(obs) }
        if let obs = b { NotificationCenter.default.removeObserver(obs) }
        if let obs = f { NotificationCenter.default.removeObserver(obs) }
        if let obs = p { NotificationCenter.default.removeObserver(obs) }
    }

    /// Removes any orphaned temp files from previous sessions (e.g. after a crash).
    private nonisolated static func cleanupOrphanedTempFiles() {
        let fm = FileManager.default
        let dir = tempDirectory
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    func setSoundscapeService(_ service: SoundscapeService) {
        self.soundscapeService = service
    }

    // MARK: - Play Chapter (Per-Verse Streaming)

    func play(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        startingFromVerseIndex: Int = 0,
        isAutoAdvance: Bool = false
    ) {
        // On auto-advance, keep the existing Live Activity alive across this
        // internal stop() so the next chapter updates it (no respawn).
        preserveActivityOnStop = isAutoAdvance && bibleActivity != nil
        stop()
        preserveActivityOnStop = false

        guard !verses.isEmpty else { return }

        // A user-initiated play is fresh — reset the auto-advance counter.
        // Chapter-complete callbacks pass `isAutoAdvance: true` so the
        // counter keeps climbing toward the still-listening threshold.
        if !isAutoAdvance {
            consecutiveAutoAdvances = 0
        }

        self.currentVerses = verses
        self.currentBook = book
        self.currentChapter = chapter
        self.currentTranslation = translation
        self.currentBookName = book.name
        self.currentTranslationName = translation.abbreviation
        self.currentTotalVerses = verses.count
        self.currentVerseIndex = startingFromVerseIndex
        self.isLoading = true
        self.isFallbackMode = false
        self.hasQueuedAllVerses = false

        let versesToPlay = Array(verses[startingFromVerseIndex...])

        fetchTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.streamVersePlayback(
                    verses: versesToPlay,
                    allVerses: verses,
                    startIndex: startingFromVerseIndex,
                    book: book,
                    chapter: chapter,
                    translation: translation
                )
            } catch is CancellationError {
                // Cancelled
            } catch AudioBibleError.cancelled {
                // Cancelled
            } catch {
                guard !Task.isCancelled else { return }
                // Fallback to AVSpeechSynthesizer
                self.errorMessage = "Using device voice"
                self.playWithSpeechFallback(
                    verses: verses,
                    book: book,
                    chapter: chapter,
                    translation: translation,
                    startingFromVerseIndex: startingFromVerseIndex
                )
            }
        }
    }

    // MARK: - Per-Verse Streaming Playback

    /// Fetches verse audio in parallel batches, starts playback as soon as the first verse is ready,
    /// and queues remaining verses seamlessly via AVQueuePlayer.
    private func streamVersePlayback(
        verses: [(number: Int, text: String)],
        allVerses: [(number: Int, text: String)],
        startIndex: Int,
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation
    ) async throws {
        guard !verses.isEmpty else { throw AudioBibleError.noVerses }

        let voice = selectedVoice

        // Build text for each verse (first verse gets chapter intro)
        var verseTexts: [(index: Int, text: String)] = []
        for (i, verse) in verses.enumerated() {
            let globalIndex = startIndex + i
            var text = verse.text
            if i == 0 {
                text = "\(book.name), chapter \(chapter). \(text)"
            }
            verseTexts.append((index: globalIndex, text: text))
        }

        // Fetch all verse audio in parallel with controlled concurrency.
        // Use an array of optionals so we can fill slots out of order.
        let count = verseTexts.count
        let audioSlots = UnsafeMutableBufferPointer<Data?>.allocate(capacity: count)
        audioSlots.initialize(repeating: nil)
        defer { audioSlots.deallocate() }

        var firstVerseReady = false
        let player = AVQueuePlayer()
        player.actionAtItemEnd = .advance

        try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var queued = 0      // how many tasks are in-flight
            var nextToSend = 0  // next verse index to send to API
            var nextToQueue = 0 // next verse to queue into player (must be in order)

            // Seed initial batch
            while nextToSend < count && queued < Self.maxConcurrentFetches {
                let vt = verseTexts[nextToSend]
                let idx = nextToSend
                group.addTask { [weak self] in
                    guard let self else { throw AudioBibleError.cancelled }
                    let data = try await self.fetchVerseAudio(text: vt.text, voice: voice)
                    return (idx, data)
                }
                nextToSend += 1
                queued += 1
            }

            // Process results as they complete
            for try await (slotIndex, data) in group {
                guard !Task.isCancelled else { throw AudioBibleError.cancelled }

                audioSlots[slotIndex] = data
                queued -= 1

                // Send more work if available
                if nextToSend < count {
                    let vt = verseTexts[nextToSend]
                    let idx = nextToSend
                    group.addTask { [weak self] in
                        guard let self else { throw AudioBibleError.cancelled }
                        let data = try await self.fetchVerseAudio(text: vt.text, voice: voice)
                        return (idx, data)
                    }
                    nextToSend += 1
                    queued += 1
                }

                // Queue all consecutive ready verses into the player
                while nextToQueue < count, let verseData = audioSlots[nextToQueue] {
                    let globalIdx = startIndex + nextToQueue
                    let fileURL = Self.tempDirectory
                        .appendingPathComponent("verse-\(UUID().uuidString).mp3")
                    try verseData.write(to: fileURL)
                    self.tempFileURLs.append(fileURL)

                    let item = AVPlayerItem(url: fileURL)
                    self.itemToVerseIndex[item] = globalIdx
                    self.playerItems.append(item)

                    // If the player drained its queue while we were still
                    // fetching, capture that state BEFORE inserting — after
                    // insert, currentItem becomes non-nil and we lose the
                    // signal. We use this to call play() again so the
                    // player picks up from where it stalled.
                    let queueWentDry = firstVerseReady && player.currentItem == nil
                    player.insert(item, after: nil)

                    // Start playback as soon as the first verse is queued
                    if !firstVerseReady {
                        firstVerseReady = true
                        self.queuePlayer = player
                        player.rate = Float(self.playbackSpeed.rawValue)

                        self.configureAudioSession()
                        self.duckSoundscape()
                        player.play()

                        self.isPlaying = true
                        self.isPaused = false
                        self.isLoading = false
                        self.currentVerseIndex = startIndex

                        self.observePlayerAdvance()

                        // Start (or, on auto-advance, reuse) the single session
                        // Live Activity.
                        self.syncLiveActivity(isPlaying: true)
                    } else if queueWentDry && self.isPlaying {
                        // Queue ran dry mid-chapter while the user was
                        // still listening. Kick playback back on — this is
                        // the fix for "audio cuts after 2-4 verses."
                        player.play()
                        player.rate = Float(self.playbackSpeed.rawValue)
                    }

                    nextToQueue += 1
                }
            }
        }

        // If we never started playback (shouldn't happen, but safety)
        if !firstVerseReady {
            throw AudioBibleError.audioDecodingFailed
        }

        // Every verse in this chapter has now been fetched and queued.
        // The observer can safely treat an empty queue as "chapter done"
        // from this point forward.
        self.hasQueuedAllVerses = true
    }

    // MARK: - Fetch Single Verse Audio (with device cache)

    private nonisolated func fetchVerseAudio(text: String, voice: BibleVoice) async throws -> Data {
        let cacheKey = verseCacheKey(voice: voice, text: text)
        let cachedURL = Self.cacheDirectory.appendingPathComponent("\(cacheKey).mp3")

        // Device cache hit
        if let data = try? Data(contentsOf: cachedURL), !data.isEmpty {
            return data
        }

        // Call TTS API
        let data = try await callTTSAPI(text: text, voice: voice)

        guard !Task.isCancelled else { throw AudioBibleError.cancelled }

        // Save to device cache
        try? data.write(to: cachedURL)

        return data
    }

    private nonisolated func verseCacheKey(voice: BibleVoice, text: String) -> String {
        let input = "\(voice.apiVoice):\(text)"
        let digest = SHA256.hash(data: Data(input.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "\(voice.apiVoice)-\(hash.prefix(32))"
    }

    // MARK: - TTS API Call

    private nonisolated func callTTSAPI(text: String, voice: BibleVoice, retryCount: Int = 0) async throws -> Data {
        var request = URLRequest(url: Self.ttsEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": voice.apiVoice,
            "response_format": "mp3",
            "speed": 1.0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AudioBibleError.networkError(URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 200 {
                guard !data.isEmpty else { throw AudioBibleError.audioDecodingFailed }
                return data
            }

            // Retry rate-limit (429) and server errors (5xx) with exponential
            // backoff — these are transient, so retrying keeps us on the AI
            // voice instead of dropping to the device fallback.
            if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500),
               retryCount < Self.maxFetchRetries {
                try await Task.sleep(nanoseconds: Self.retryBackoff(attempt: retryCount))
                return try await callTTSAPI(text: text, voice: voice, retryCount: retryCount + 1)
            }

            let errorMsg = String(data: data, encoding: .utf8) ?? "API error \(httpResponse.statusCode)"
            throw AudioBibleError.apiError(errorMsg)
        } catch let urlError as URLError {
            // Transient network blip (timeout, connection lost) — back off and
            // retry rather than abandoning the chapter to the device voice.
            guard retryCount < Self.maxFetchRetries else { throw urlError }
            try await Task.sleep(nanoseconds: Self.retryBackoff(attempt: retryCount))
            return try await callTTSAPI(text: text, voice: voice, retryCount: retryCount + 1)
        }
    }

    /// Exponential backoff (0.5s, 1s, 2s, 4s …) for TTS fetch retries.
    private nonisolated static func retryBackoff(attempt: Int) -> UInt64 {
        let seconds = 0.5 * pow(2.0, Double(attempt))
        return UInt64(seconds * 1_000_000_000)
    }

    // MARK: - AVQueuePlayer Observation

    private func observePlayerAdvance() {
        // Keep the highlighted verse locked to the item that's actually
        // playing, four times a second. Relying only on the end-of-item
        // notification let the highlight drift behind the audio over a long
        // chapter; this corrects it continuously.
        if let token = timeObserverToken {
            queuePlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = queuePlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard let item = self.queuePlayer?.currentItem,
                      let idx = self.itemToVerseIndex[item] else { return }
                if self.currentVerseIndex != idx {
                    self.currentVerseIndex = idx
                }
            }
        }

        // Observe when AVQueuePlayer advances to the next item
        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let finishedItem = notification.object as? AVPlayerItem else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }

                // Check if this was the last item
                if let currentItem = self.queuePlayer?.currentItem,
                   let verseIdx = self.itemToVerseIndex[currentItem] {
                    self.currentVerseIndex = verseIdx
                    self.syncLiveActivity(isPlaying: true)
                } else if self.itemToVerseIndex[finishedItem] != nil {
                    // The last-queued item just ended. If every verse for
                    // this chapter has been queued, that's chapter done.
                    // Otherwise the queue has drained faster than the
                    // stream can fill it — don't complete, just wait;
                    // the streaming loop will insert the next verse and
                    // resume playback the moment it arrives.
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if self.queuePlayer?.currentItem == nil && self.hasQueuedAllVerses {
                        self.handlePlaybackCompletion()
                    }
                }
            }
        }
    }

    // MARK: - Seek to Verse

    func seekToVerse(index: Int) {
        guard index >= 0, index < currentVerses.count else { return }

        // A manual seek is an explicit "I'm here / keep going" — reset the
        // still-listening counter so the prompt doesn't fire prematurely.
        consecutiveAutoAdvances = 0

        if isFallbackMode {
            speechSynthesizer?.stopSpeaking(at: .immediate)
            currentVerseIndex = index
            requeueSpeechUtterances(from: index)
            isPlaying = true
            isPaused = false
        } else if let player = queuePlayer {
            // Find the player item for this verse index
            if itemToVerseIndex.values.contains(index) {
                // Remove all items before the target
                player.removeAllItems()
                // Re-insert from target onwards
                let sortedItems = playerItems
                    .filter { item in
                        guard let idx = itemToVerseIndex[item] else { return false }
                        return idx >= index
                    }
                    .sorted { (itemToVerseIndex[$0] ?? 0) < (itemToVerseIndex[$1] ?? 0) }

                for item in sortedItems {
                    item.seek(to: .zero, completionHandler: nil)
                    player.insert(item, after: nil)
                }

                currentVerseIndex = index
                // Always resume after a seek — the user tapped to hear from
                // here. (Previously only resumed if already paused, so a tap
                // mid-playback could silently stop the audio.)
                player.play()
                player.rate = Float(playbackSpeed.rawValue)
                isPlaying = true
                isPaused = false
            }
        }
    }

    // MARK: - Pause / Resume / Stop

    func pause() {
        if isFallbackMode {
            speechSynthesizer?.pauseSpeaking(at: .word)
        } else {
            queuePlayer?.pause()
        }

        isPlaying = false
        isPaused = true
        restoreSoundscape()

        syncLiveActivity(isPlaying: false)
    }

    func resume() {
        guard isPaused else { return }
        configureAudioSession()
        duckSoundscape()

        if isFallbackMode {
            speechSynthesizer?.continueSpeaking()
        } else {
            queuePlayer?.play()
            queuePlayer?.rate = Float(playbackSpeed.rawValue)
        }

        isPlaying = true
        isPaused = false

        syncLiveActivity(isPlaying: true)
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil

        // Cancel all prefetch tasks
        for task in prefetchTasks { task.cancel() }
        prefetchTasks.removeAll()
        prefetchingChapters.removeAll()

        // Stop AVQueuePlayer
        queuePlayer?.pause()
        if let token = timeObserverToken {
            queuePlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        if let obs = playerObserver {
            NotificationCenter.default.removeObserver(obs)
            playerObserver = nil
        }
        playerItems = []
        itemToVerseIndex = [:]

        // Clean up temp files
        for url in tempFileURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempFileURLs = []

        // Stop speech fallback
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
        speechDelegate = nil

        currentVerses = []
        currentBook = nil
        isFallbackMode = false

        isPlaying = false
        isPaused = false
        isLoading = false
        currentVerseIndex = 0
        errorMessage = nil

        autoStopTask?.cancel()
        autoStopTask = nil

        stillListeningTimeoutTask?.cancel()
        stillListeningTimeoutTask = nil
        showStillListeningPrompt = false
        hasQueuedAllVerses = false

        // Keep the activity alive through the internal stop() of an
        // auto-advance so the next chapter updates it instead of spawning a
        // fresh one. A real (user-initiated) stop ends it.
        if let activity = bibleActivity, !preserveActivityOnStop {
            LiveActivityService.endBibleSession(activity)
            bibleActivity = nil
        }

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

        if isFallbackMode {
            guard let synthesizer = speechSynthesizer, synthesizer.isSpeaking || isPaused else { return }
            let resumeIndex = currentVerseIndex
            speechSynthesizer?.stopSpeaking(at: .immediate)
            requeueSpeechUtterances(from: resumeIndex)
        } else if let player = queuePlayer {
            player.rate = Float(speed.rawValue)
        }
    }

    var hasActivePlayback: Bool {
        isPlaying || isPaused || isLoading
    }

    func setOnChapterComplete(_ handler: @escaping () -> Void) {
        onChapterComplete = handler
    }

    // MARK: - Prefetch (Background)

    /// Prefetches audio for an entire chapter's verses in the background.
    /// Deduplicates by chapter key so the same chapter is never prefetched twice.
    func prefetchAudio(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation
    ) {
        let voice = selectedVoice
        let chapterKey = "\(book.id)-\(chapter)-\(voice.apiVoice)"

        // Skip if already prefetching this chapter+voice
        guard !prefetchingChapters.contains(chapterKey) else { return }
        prefetchingChapters.insert(chapterKey)

        // Evict completed tasks to keep array bounded
        prefetchTasks.removeAll { $0.isCancelled }

        let task = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                for (i, verse) in verses.enumerated() {
                    group.addTask {
                        var text = verse.text
                        if i == 0 {
                            text = "\(book.name), chapter \(chapter). \(text)"
                        }
                        do {
                            _ = try await self.fetchVerseAudio(text: text, voice: voice)
                        } catch {
                            #if DEBUG
                            print("[AudioBible] Prefetch failed for verse \(i): \(error)")
                            #endif
                        }
                    }
                }
            }
            // Remove from in-progress set when done
            await MainActor.run { [weak self] in
                self?.prefetchingChapters.remove(chapterKey)
            }
        }
        prefetchTasks.append(task)
    }

    /// Prefetches audio for the current chapter's verses. Call this when the chapter loads,
    /// so audio is ready before the user taps play.
    func prefetchCurrentChapter(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int
    ) {
        prefetchAudio(verses: verses, book: book, chapter: chapter, translation: .kjv)
    }

    /// Cancels all in-flight prefetch tasks (e.g. when navigating away).
    func cancelPrefetches() {
        for task in prefetchTasks { task.cancel() }
        prefetchTasks.removeAll()
        prefetchingChapters.removeAll()
    }

    // MARK: - Speech Fallback

    private func playWithSpeechFallback(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        startingFromVerseIndex: Int
    ) {
        isFallbackMode = true

        let synthesizer = AVSpeechSynthesizer()
        let delegate = SpeechDelegate { [weak self] verseIndex in
            guard let self else { return }
            self.currentVerseIndex = verseIndex
            self.syncLiveActivity(isPlaying: true)
        } onComplete: { [weak self] in
            guard let self else { return }
            self.handlePlaybackCompletion()
        }

        synthesizer.delegate = delegate
        self.speechSynthesizer = synthesizer
        self.speechDelegate = delegate

        configureAudioSession()
        duckSoundscape()

        let voice = resolvePlaybackVoice()
        let rate = speechRate(for: playbackSpeed)

        // Prefer the localized book name from the active translation ref so
        // a Spanish listener hears "Génesis, capítulo 1." instead of
        // "Genesis, chapter 1." (pronounced with English phonetics). Falls
        // back to the English `book.name` when no translation was picked.
        let spokenBookName: String = {
            if let refID = LocalizationService.currentLanguageCode().flatMap({ LanguageDefaultBible.defaultRefID(for: $0) }),
               let localized = BibleRepository.shared.localizedBookName(refID: refID, bookID: book.id) {
                return localized
            }
            return book.name
        }()
        let intro = String(localized: "\(spokenBookName), chapter \(chapter).")

        for i in startingFromVerseIndex..<verses.count {
            let verse = verses[i]
            var text = verse.text
            if i == startingFromVerseIndex {
                text = "\(intro) \(verse.text)"
            }

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = rate
            utterance.postUtteranceDelay = 0.3

            delegate.mapUtterance(utterance, toVerseIndex: i)
            synthesizer.speak(utterance)
        }

        isPlaying = true
        isPaused = false
        isLoading = false

        // Start (or reuse, on auto-advance) the single session Live Activity.
        syncLiveActivity(isPlaying: true)
    }

    private func requeueSpeechUtterances(from index: Int) {
        guard !currentVerses.isEmpty, index < currentVerses.count else { return }

        let synthesizer = speechSynthesizer ?? AVSpeechSynthesizer()
        if speechSynthesizer == nil {
            let delegate = SpeechDelegate { [weak self] verseIndex in
                guard let self else { return }
                self.currentVerseIndex = verseIndex
                self.syncLiveActivity(isPlaying: true)
            } onComplete: { [weak self] in
                guard let self else { return }
                self.handlePlaybackCompletion()
            }
            synthesizer.delegate = delegate
            self.speechSynthesizer = synthesizer
            self.speechDelegate = delegate
        }

        let voice = resolvePlaybackVoice()
        let rate = speechRate(for: playbackSpeed)

        speechDelegate?.resetMappings()

        for i in index..<currentVerses.count {
            let utterance = AVSpeechUtterance(string: currentVerses[i].text)
            utterance.voice = voice
            utterance.rate = rate
            utterance.postUtteranceDelay = 0.3

            speechDelegate?.mapUtterance(utterance, toVerseIndex: i)
            synthesizer.speak(utterance)
        }

        currentVerseIndex = index
        isPlaying = true
        isPaused = false
    }

    /// Pick the `AVSpeechSynthesisVoice` appropriate for the current app
    /// language. When the user is reading in Spanish, this returns a Spanish
    /// system voice; for English (or for languages with no installed system
    /// voice, like Amharic) it falls back to the user's chosen `BibleVoice`
    /// persona so the familiar English-reader experience stays intact.
    private func resolvePlaybackVoice() -> AVSpeechSynthesisVoice? {
        // `effectiveLanguageCode` resolves "system" to the device's preferred
        // language — so a Spanish-phone listener still gets Mónica even if
        // they never touched the app's language picker.
        let code = LocalizationService.shared.effectiveLanguageCode
        if code != "en",
           let localeVoice = LocaleVoiceResolver.voice(forLanguageCode: code) {
            return localeVoice
        }
        return selectedVoice.resolvedVoice
    }

    private func speechRate(for speed: PlaybackSpeed) -> Float {
        switch speed {
        case .slow:   return 0.42
        case .normal: return AVSpeechUtteranceDefaultSpeechRate
        case .fast:   return 0.55
        case .faster: return 0.6
        }
    }

    // MARK: - Playback Completion

    private func handlePlaybackCompletion() {
        isPlaying = false
        isPaused = false

        // Count this completion toward the still-listening safeguard. If
        // we've auto-advanced more than `stillListeningThreshold` chapters
        // in a row, prompt the user to confirm instead of quietly rolling
        // into the next chapter — stops runaway playback (and TTS cost)
        // when someone falls asleep with headphones in.
        consecutiveAutoAdvances += 1
        if consecutiveAutoAdvances >= Self.stillListeningThreshold {
            // Pause and prompt. Keep the Live Activity alive (showing paused)
            // — confirming continues it, dismissing/stop() ends it. We do NOT
            // end+recreate per chapter, which is what made a dismissed
            // notification keep coming back.
            restoreSoundscape()
            syncLiveActivity(isPlaying: false)
            showStillListeningPrompt = true
            scheduleStillListeningTimeout()
        } else {
            // Auto-advance: leave the activity alive; the next chapter's
            // play() updates it in place.
            onChapterComplete?()
        }
    }

    // MARK: - Still-Listening Actions

    /// User confirmed they're still listening — reset the counter and
    /// trigger the normal chapter advance that we deferred.
    func confirmStillListening() {
        stillListeningTimeoutTask?.cancel()
        stillListeningTimeoutTask = nil
        consecutiveAutoAdvances = 0
        showStillListeningPrompt = false
        onChapterComplete?()
    }

    /// User chose to stop (or the timeout fired) — tear playback down.
    func dismissStillListening() {
        stillListeningTimeoutTask?.cancel()
        stillListeningTimeoutTask = nil
        consecutiveAutoAdvances = 0
        showStillListeningPrompt = false
        stop()
    }

    private func scheduleStillListeningTimeout() {
        stillListeningTimeoutTask?.cancel()
        stillListeningTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.stillListeningTimeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.showStillListeningPrompt {
                self.dismissStillListening()
            }
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Audio session setup failed
        }
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
        } catch {
            // Non-critical
        }
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

    // MARK: - Auto-Stop (Background Timer)

    private func setupBackgroundObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.startAutoStopTimer()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cancelAutoStopTimer()
            }
        }
    }

    private func startAutoStopTimer() {
        guard hasActivePlayback else { return }
        autoStopTask?.cancel()
        autoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.autoStopDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.isPlaying || self.isPaused {
                self.stop()
            }
        }
    }

    private func cancelAutoStopTimer() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    // MARK: - Voice Selection

    func setVoice(_ voice: BibleVoice) {
        selectedVoice = voice
    }
}

// MARK: - Speech Synthesis Delegate (Fallback)

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private var utteranceToVerse: [AVSpeechUtterance: Int] = [:]
    private var totalUtterances: Int = 0
    private var completedUtterances: Int = 0
    private let onVerseStarted: (Int) -> Void
    private let onComplete: () -> Void

    init(
        onVerseStarted: @escaping (Int) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.onVerseStarted = onVerseStarted
        self.onComplete = onComplete
        super.init()
    }

    func mapUtterance(_ utterance: AVSpeechUtterance, toVerseIndex index: Int) {
        utteranceToVerse[utterance] = index
        totalUtterances += 1
    }

    func resetMappings() {
        utteranceToVerse.removeAll()
        totalUtterances = 0
        completedUtterances = 0
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let verseIndex = utteranceToVerse[utterance] else { return }
        Task { @MainActor [onVerseStarted] in
            onVerseStarted(verseIndex)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completedUtterances += 1
        if completedUtterances >= totalUtterances {
            Task { @MainActor [onComplete] in
                onComplete()
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Handled by stop()
    }
}
