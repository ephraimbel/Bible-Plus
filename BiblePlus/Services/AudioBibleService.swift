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
    /// Independent wall-clock watchdog. Unlike the player's periodic time
    /// observer (which stops firing the instant the player clock freezes), this
    /// ticks on its own schedule so it can detect AND recover from a stalled or
    /// drained queue — including the dead-at-chapter-end case where the last
    /// item finishes but the end-of-item notification never lands.
    private var watchdogTask: Task<Void, Never>?
    /// Last known playback position of the current item, with the time we
    /// observed it. Lets the watchdog detect a "playing but frozen" stall (the
    /// player reports `.playing` yet the clock hasn't moved) on the final item.
    private var lastObservedTime: CMTime = .zero
    private var lastObservedTimeAt: Date?
    /// When the current item has been sitting NOT playing (loaded-but-paused or
    /// wedged in a `.waiting` state) since. Lets the watchdog stop nudging a
    /// dead item and skip past it, instead of looping `play()` on it forever —
    /// the silent-stall that cut a chapter after a couple of verses.
    private var stuckNotPlayingSince: Date?
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

    /// Highest verse index that has been inserted into the queue so far. The
    /// watchdog uses this, together with `hasQueuedAllVerses`, to know whether
    /// a drained queue means "chapter finished" or "still buffering the next
    /// verse." Reset on every fresh `play()`.
    private var highestQueuedIndex: Int = -1

    /// Guards against `handlePlaybackCompletion()` firing twice for the same
    /// chapter — both the end-of-item notification AND the periodic watchdog
    /// can observe "queue empty + all verses queued," and without this flag a
    /// double-fire would double-count the auto-advance counter and could even
    /// skip a chapter. Cleared on every fresh `play()`.
    private var didCompleteChapter: Bool = false

    /// Wall-clock time the queue last went empty while we still believed we
    /// were playing. Used by the watchdog to surface a brief buffering state
    /// (and, if it persists abnormally long with all verses already queued, to
    /// force chapter completion so playback never dies silently at the end).
    private var queueDrainedAt: Date?

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

    // MARK: - Debug Log (TEMP — device diagnostics)
    //
    // Appends audio-engine events to Documents/audio-debug.log so we can pull
    // the file off a physical device with `xcrun devicectl device copy from`
    // and see exactly why playback stalls on real hardware. Remove once fixed.
    #if DEBUG
    private nonisolated static let debugLogURL: URL =
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("audio-debug.log")
    #endif

    // NOTE: gated to DEBUG only. The watchdog calls `alog` every 0.4s during
    // playback; doing synchronous main-thread file I/O into an ever-growing
    // file in the user-visible, iCloud-backed Documents directory on every tick
    // is real battery/disk/jank harm in a long listening session. In release
    // these are no-ops, so production playback does zero diagnostic I/O; the
    // logs remain available on debug builds for device diagnostics.
    nonisolated static func alog(_ msg: String) {
        #if DEBUG
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "\(ts) \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: debugLogURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: debugLogURL)
        }
        #endif
    }

    nonisolated static func alogReset() {
        #if DEBUG
        try? "".data(using: .utf8)?.write(to: debugLogURL)
        #endif
    }

    // MARK: - Concurrency

    /// Max parallel TTS requests for verse generation. Tuned up from 4 → 6 so an
    /// uncached chapter fills fast enough to stay ahead of playback (the "takes
    /// forever / keeps buffering" symptom), while staying modest enough that a
    /// long session doesn't burst the TTS API into rate-limiting. Transient 429s
    /// are still retried with backoff, so a brief burst won't drop the AI voice.
    private static let maxConcurrentFetches = 6

    /// How many times to retry a single verse's TTS fetch before giving up.
    /// Rate-limit (429), server (5xx), and transient network errors are all
    /// retried with exponential backoff so we stay on the premium AI voice
    /// instead of falling back to the device synthesizer.
    private static let maxFetchRetries = 4

    /// Minimum byte count for a response to be accepted as real verse audio.
    /// A valid TTS MP3 — even for the shortest verse — is several KB; a
    /// truncated stream or a stray error payload returned with a 200 is far
    /// smaller. Anything under this floor would decode into a dead AVPlayerItem
    /// that silently wedges the queue, so we treat it as a transient failure and
    /// retry/re-fetch instead of caching and queuing it. Deliberately
    /// conservative (1 KB) so a legitimately short verse is never rejected.
    private static let minValidAudioBytes = 1024

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
            // Fresh user-initiated play → reset the drain-recovery progress guard.
            lastDrainRecoveryIndex = -1
            drainRecoveryAttempts = 0
            Self.alogReset()
        }
        Self.alog("PLAY \(book.name) \(chapter) from=\(startingFromVerseIndex) auto=\(isAutoAdvance) n=\(verses.count)")

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
        self.highestQueuedIndex = -1
        self.didCompleteChapter = false
        self.queueDrainedAt = nil

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
                Self.alog("stream CANCELLED")
            } catch AudioBibleError.cancelled {
                Self.alog("stream cancelled(err)")
            } catch {
                guard !Task.isCancelled else { return }
                Self.alog("stream THREW -> device-voice fallback: \(error)")
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
            // Announce the chapter ONLY at the true top of the chapter (verse 0).
            // A mid-chapter start — resuming from a tapped verse, or a drain
            // recovery re-streaming from where playback stopped — must NOT
            // re-announce "Book, chapter N" (that was the "repeats the chapter
            // mid-page" bug).
            if globalIndex == 0 {
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
        // Keep automatic stall-avoidance ON (the default). A freshly written
        // temp-file item needs a brief moment to parse its MP3 header and reach
        // `.readyToPlay`; with waits OFF the player reported `.playing` while the
        // clock sat pinned at 0, and the watchdog then misread that as a "frozen"
        // verse and SKIPPED it — the cause of audio skipping verses. With waits
        // ON, the player simply waits the few milliseconds for each item to be
        // ready and plays every verse in order; the watchdog (nudge + buffering)
        // covers genuine drains, and only truly `.failed` items are skipped.
        player.automaticallyWaitsToMinimizeStalling = true

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
                    self.highestQueuedIndex = max(self.highestQueuedIndex, globalIdx)

                    // Assign the player early (on the first item) so pause/stop/
                    // seek behave even while we're still buffering the head-start,
                    // before playback has begun.
                    if self.queuePlayer == nil {
                        self.queuePlayer = player
                        self.configureAudioSession()
                    }

                    // If the player drained its queue while we were still
                    // fetching, capture that state BEFORE inserting — after
                    // insert, currentItem becomes non-nil and we lose the
                    // signal. We use this to call play() again so the
                    // player picks up from where it stalled.
                    let queueWentDry = firstVerseReady && player.currentItem == nil
                    player.insert(item, after: nil)

                    // Buffer a small head-start before beginning playback. The
                    // 6 parallel fetches land the first verses in one wave, so
                    // waiting for ~4 (instead of starting on verse 0) costs
                    // almost no extra time but gives a cushion that keeps
                    // generation comfortably ahead of the reader — so audio
                    // doesn't stop to generate mid-chapter. A short or fully
                    // cached chapter satisfies this instantly.
                    let queuedNow = nextToQueue + 1
                    let startLead = min(count, 4)
                    if !firstVerseReady {
                        guard queuedNow >= startLead || queuedNow == count else {
                            // Keep buffering (isLoading stays true); don't start yet.
                            Self.alog("buffering head-start \(queuedNow)/\(startLead)")
                            nextToQueue += 1
                            continue
                        }
                        firstVerseReady = true
                        player.rate = Float(self.playbackSpeed.rawValue)

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
                    } else if self.isPlaying {
                        // The queue may have drained mid-chapter while we were
                        // still fetching this verse (generation can't always
                        // keep pace with playback on an uncached chapter over a
                        // slow network). Kick playback back on the instant the
                        // next verse lands. We no longer rely SOLELY on the
                        // pre-insert `queueWentDry` snapshot: `currentItem` can
                        // read stale (the just-finished item) for a beat after
                        // the queue empties, so that check sometimes missed the
                        // drain and audio stalled forever. Nudging whenever the
                        // player isn't actually playing is idempotent and the
                        // periodic watchdog is the backstop.
                        if queueWentDry || player.timeControlStatus != .playing {
                            self.queueDrainedAt = nil
                            self.isLoading = false
                            player.play()
                            player.rate = Float(self.playbackSpeed.rawValue)
                        }
                    }

                    Self.alog("queued idx=\(globalIdx) wentDry=\(queueWentDry) tcs=\(player.timeControlStatus.rawValue) qn=\(player.items().count)")
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
        Self.alog("ALL QUEUED total=\(self.highestQueuedIndex + 1)")
    }

    // MARK: - Fetch Single Verse Audio (with device cache)

    private nonisolated func fetchVerseAudio(text: String, voice: BibleVoice) async throws -> Data {
        let cacheKey = verseCacheKey(voice: voice, text: text)
        let cachedURL = Self.cacheDirectory.appendingPathComponent("\(cacheKey).mp3")

        // Device cache hit. Apply the same size floor as the network path so a
        // previously-cached truncated/garbage file is discarded and re-fetched
        // rather than served back as a dead AVPlayerItem.
        if let data = try? Data(contentsOf: cachedURL), data.count >= Self.minValidAudioBytes {
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
                // A too-small 200 body is a truncated/garbage response, not real
                // audio. Retry it (transient, like a 5xx) so we re-fetch valid
                // audio and stay on the AI voice; only give up after exhausting
                // retries, at which point the caller's skip/fallback handles it.
                guard data.count >= Self.minValidAudioBytes else {
                    if retryCount < Self.maxFetchRetries {
                        try await Task.sleep(nanoseconds: Self.retryBackoff(attempt: retryCount))
                        return try await callTTSAPI(text: text, voice: voice, retryCount: retryCount + 1)
                    }
                    throw AudioBibleError.audioDecodingFailed
                }
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
        //
        // NOTE: the periodic time observer only fires while the player's clock
        // is advancing — so it CANNOT be the watchdog. When the queue drains or
        // the last item stalls, the clock freezes and this observer goes silent
        // (this is what left audio dead at the end of an Acts chapter). The
        // recovery watchdog therefore runs on an INDEPENDENT wall-clock timer
        // (`startPlaybackWatchdog`) that ticks regardless of player state.
        if let token = timeObserverToken {
            queuePlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = queuePlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard let player = self.queuePlayer else { return }
                // Keep the highlight locked to the item actually playing.
                if let item = player.currentItem, let idx = self.itemToVerseIndex[item],
                   self.currentVerseIndex != idx {
                    self.currentVerseIndex = idx
                }
            }
        }

        startPlaybackWatchdog()

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
                    if self.queuePlayer?.currentItem == nil,
                       self.hasQueuedAllVerses,
                       !self.didCompleteChapter {
                        // Only complete if we genuinely reached the last verse.
                        // An empty queue before then means AVQueuePlayer dropped
                        // the rest — let the watchdog rebuild it (recoverDrain)
                        // instead of skipping ahead.
                        if self.currentVerseIndex >= self.currentVerses.count - 1 {
                            self.handlePlaybackCompletion()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Playback Watchdog (independent wall-clock timer)

    /// Starts the self-driven watchdog loop. It runs every 0.4s for the life of
    /// the playback session, independent of the player's clock, and is the
    /// single guarantee that audio never silently dies in a long uncached
    /// chapter. It recovers from three failure modes seen on device in Acts:
    ///
    ///   (A) Loaded-but-paused: an item is queued but the player sits at
    ///       `.paused`/`.waiting`. Nudge `play()`.
    ///   (B) Drained queue mid-chapter: the next verse hasn't generated yet.
    ///       Surface a buffering state and resume the instant a verse arrives
    ///       (a freshly inserted item is caught here even if the streaming
    ///       loop's insert-time re-play missed the drain).
    ///   (C) Stalled/finished last item: the final verse ends but the
    ///       end-of-item notification never fires (or the player freezes at
    ///       `.playing` with a stuck clock). Detected by either an empty queue
    ///       with all verses queued, OR a non-advancing position at end of the
    ///       last item — then drive chapter completion → auto-advance.
    private func startPlaybackWatchdog() {
        watchdogTask?.cancel()
        lastObservedTime = .zero
        lastObservedTimeAt = nil
        stuckNotPlayingSince = nil
        watchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let self else { return }
                self.playbackWatchdogTick()
            }
        }
    }

    private func stopPlaybackWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
        lastObservedTime = .zero
        lastObservedTimeAt = nil
        stuckNotPlayingSince = nil
    }

    private func playbackWatchdogTick() {
        guard let player = queuePlayer else { return }
        guard isPlaying, !isPaused, !isFallbackMode else { return }

        let itemIdx = player.currentItem.flatMap { itemToVerseIndex[$0] }.map(String.init) ?? "nil"
        Self.alog("tick v=\(currentVerseIndex) item=\(itemIdx) tcs=\(player.timeControlStatus.rawValue) qn=\(player.items().count) wait=\(player.reasonForWaitingToPlay?.rawValue ?? "-") t=\(String(format: "%.1f", CMTimeGetSeconds(player.currentTime()))) hiQ=\(highestQueuedIndex) allQ=\(hasQueuedAllVerses) load=\(isLoading) itemErr=\(player.currentItem?.error.map { "\($0)" } ?? "-")")

        let item = player.currentItem
        let playing = player.timeControlStatus == .playing
        let now = player.currentTime()

        // --- Maintain the stall anchors (stateful) BEFORE deciding, so the pure
        // decision below sees correct durations. ---

        // Not-playing stall clock: starts the moment a current item stops
        // making progress; cleared whenever there's no item or we're playing.
        if item != nil && !playing {
            if stuckNotPlayingSince == nil { stuckNotPlayingSince = Date() }
        } else {
            stuckNotPlayingSince = nil
        }

        // Frozen-clock detection: "playing" but the position hasn't moved since
        // the last sample. While the clock keeps advancing we re-anchor it;
        // once frozen we deliberately hold the anchor so `frozenFor` grows.
        let clockFrozen = item != nil && playing
            && lastObservedTimeAt != nil && CMTimeCompare(now, lastObservedTime) == 0
        if item != nil && playing && !clockFrozen {
            lastObservedTime = now
            lastObservedTimeAt = Date()
        }

        // --- Build the pure decision input ---
        let isLastQueuedItem = (item.flatMap { itemToVerseIndex[$0] } ?? -1) >= highestQueuedIndex && hasQueuedAllVerses
        let atEnd: Bool = {
            guard let item else { return false }
            let duration = item.duration
            return duration.isNumeric == false
                || CMTimeGetSeconds(duration) <= 0
                || CMTimeGetSeconds(now) >= CMTimeGetSeconds(duration) - 0.6
        }()
        let input = WatchdogInput(
            hasCurrentItem: item != nil,
            isPlaying: playing,
            itemFailed: item?.status == .failed,
            clockFrozen: clockFrozen,
            frozenFor: clockFrozen ? Date().timeIntervalSince(lastObservedTimeAt ?? Date()) : 0,
            notPlayingFor: (item != nil && !playing) ? Date().timeIntervalSince(stuckNotPlayingSince ?? Date()) : 0,
            isLastQueuedItem: isLastQueuedItem,
            atEnd: atEnd,
            hasQueuedAllVerses: hasQueuedAllVerses,
            didCompleteChapter: didCompleteChapter,
            reachedLastVerse: currentVerseIndex >= currentTotalVerses - 1
        )

        // --- Dispatch the resulting action ---
        switch Self.watchdogAction(input) {
        case .idle:
            // Healthy playback, frozen-but-not-yet-past-threshold, or an
            // already-completed empty queue. Just keep bookkeeping tidy.
            if item != nil {
                queueDrainedAt = nil
                if isLoading { isLoading = false }
            } else {
                lastObservedTimeAt = nil
            }

        case .nudge:
            // (A) Loaded but not playing, still within the grace window — kick
            // it back to life. Idempotent; also the instant-recovery for a
            // freshly inserted buffered verse.
            queueDrainedAt = nil
            if isLoading { isLoading = false }
            player.play()
            player.rate = Float(playbackSpeed.rawValue)
            lastObservedTimeAt = nil

        case .skipStalled:
            // A `.failed` item, a chronically un-played item, or a frozen middle
            // verse — skip it so one bad verse can't wedge the chapter in silence.
            queueDrainedAt = nil
            if isLoading { isLoading = false }
            advancePastStalledItem()

        case .completeChapter:
            // The final verse ended but the end-of-item notification never
            // landed (frozen last item, or an empty queue with all verses
            // played). Drive completion → auto-advance.
            if item != nil {
                queueDrainedAt = nil
                if isLoading { isLoading = false }
            } else {
                lastObservedTimeAt = nil
            }
            handlePlaybackCompletion()

        case .startBuffering:
            // (B) Queue drained mid-chapter while later verses still generate.
            // Surface loading; resume happens the instant the next verse is
            // inserted (here and in the streaming loop).
            lastObservedTimeAt = nil
            if queueDrainedAt == nil {
                queueDrainedAt = Date()
                isLoading = true
            }

        case .recoverDrain:
            // (D) AVQueuePlayer dropped the rest of its queue before we reached
            // the last verse. Rebuild playback from where it died instead of
            // skipping the remaining verses.
            lastObservedTimeAt = nil
            recoverFromDrain()
        }
    }

    // MARK: - Drain Recovery
    //
    // AVQueuePlayer can silently flush its entire queue mid-chapter (observed on
    // device: a 20-item queue collapsing to 0 between two verses). When that
    // happens we re-stream the remaining verses from where playback stopped,
    // rather than letting the empty queue masquerade as "chapter complete" and
    // skip ahead. A small progress guard prevents a tight loop if recovery keeps
    // failing at the same verse — after a few attempts it drops to the device
    // voice for the rest of the chapter so the listener always hears every verse.
    private var lastDrainRecoveryIndex: Int = -1
    private var drainRecoveryAttempts: Int = 0
    private static let maxDrainRecoveryAttempts = 3

    private func recoverFromDrain() {
        guard let book = currentBook else { return }
        let resumeFrom = currentVerseIndex + 1
        guard resumeFrom < currentVerses.count else {
            // Nothing left — this really was the end.
            handlePlaybackCompletion()
            return
        }

        if resumeFrom == lastDrainRecoveryIndex {
            drainRecoveryAttempts += 1
        } else {
            lastDrainRecoveryIndex = resumeFrom
            drainRecoveryAttempts = 1
        }

        let verses = currentVerses
        let chapter = currentChapter
        let translation = currentTranslation

        if drainRecoveryAttempts > Self.maxDrainRecoveryAttempts {
            // Repeated collapse at the same verse — finish the chapter on the
            // reliable device voice so playback never stalls or skips.
            Self.alog("WATCHDOG drain recovery exhausted at \(resumeFrom) -> device voice")
            stop()
            currentVerses = verses
            currentBook = book
            currentChapter = chapter
            currentTranslation = translation
            currentTotalVerses = verses.count
            playWithSpeechFallback(
                verses: verses, book: book, chapter: chapter,
                translation: translation, startingFromVerseIndex: resumeFrom
            )
            return
        }

        Self.alog("WATCHDOG recover drain -> re-stream from \(resumeFrom) (attempt \(drainRecoveryAttempts))")
        // `play()` stop()s the dead player and re-streams from `resumeFrom`.
        // isAutoAdvance:true keeps the still-listening counter + Live Activity
        // and (deliberately) does NOT reset the drain-recovery progress guard.
        play(
            verses: verses, book: book, chapter: chapter,
            translation: translation, startingFromVerseIndex: resumeFrom,
            isAutoAdvance: true
        )
    }

    // MARK: - Watchdog Decision (pure, unit-testable)

    /// Seconds the player position may stay frozen while reporting `.playing`
    /// before the watchdog treats the current item as wedged.
    static let watchdogStallSeconds: TimeInterval = 2.5

    /// Seconds a current item may sit not-playing (a stuck `.waiting` state)
    /// before the watchdog gives up nudging it and skips past it.
    static let watchdogNotPlayingGraceSeconds: TimeInterval = 5

    /// Everything the watchdog needs to decide, captured as plain values so the
    /// decision is pure and testable without driving a real `AVQueuePlayer`.
    struct WatchdogInput: Equatable {
        var hasCurrentItem: Bool
        /// `timeControlStatus == .playing`.
        var isPlaying: Bool
        /// `currentItem.status == .failed` — will never play, no point nudging.
        var itemFailed: Bool
        /// Reporting `.playing` but the position hasn't advanced since the last sample.
        var clockFrozen: Bool
        /// How long the clock has been frozen (0 when not frozen).
        var frozenFor: TimeInterval
        /// How long a current item has sat not-playing (0 when playing / no item).
        var notPlayingFor: TimeInterval
        /// The current item is the last verse that will ever be queued.
        var isLastQueuedItem: Bool
        /// Playback position is at (or within 0.6s of) the item's end.
        var atEnd: Bool
        /// Every verse for the chapter has been fetched and queued.
        var hasQueuedAllVerses: Bool
        /// Chapter completion already fired (latch).
        var didCompleteChapter: Bool
        /// Playback has actually reached the final verse of the chapter. An
        /// empty queue only means "chapter done" when this is true; otherwise
        /// `AVQueuePlayer` dropped the rest of the queue mid-chapter and we must
        /// rebuild it rather than skip to the next chapter.
        var reachedLastVerse: Bool
    }

    /// What the watchdog should do this tick. Pure function of `WatchdogInput`.
    enum WatchdogAction: Equatable {
        case idle              // healthy / nothing actionable
        case nudge             // not playing but recoverable → play()
        case skipStalled       // wedged item → advance past it
        case completeChapter   // chapter finished (end-of-item was missed)
        case startBuffering    // queue drained mid-chapter → show loading
        case recoverDrain      // queue lost mid-chapter → rebuild from where we were
    }

    /// The single source of truth for the watchdog's recovery decisions. Kept
    /// free of AVFoundation so it can be exhaustively unit-tested — including
    /// the regression that a corrupt/stalled verse is *skipped* rather than
    /// looped on forever in silence.
    nonisolated static func watchdogAction(_ s: WatchdogInput) -> WatchdogAction {
        guard s.hasCurrentItem else {
            // Empty queue.
            if s.didCompleteChapter { return .idle }  // already finished — do nothing
            if s.hasQueuedAllVerses {
                // We genuinely played through to the last verse → chapter done.
                if s.reachedLastVerse { return .completeChapter }
                // Every verse was queued, the queue is empty, yet we never
                // reached the final verse — AVQueuePlayer dropped the rest of
                // the queue mid-chapter. Rebuild it rather than falsely
                // completing and skipping to the next chapter (the skip bug).
                return .recoverDrain
            }
            // Still streaming the remaining verses.
            return .startBuffering
        }

        // The ONLY item we ever skip is one that has genuinely `.failed` — it
        // can never play, so leaving it current would wedge the chapter in
        // silence. Every other not-yet-playing item is given the chance to
        // buffer and play. Skipping merely-slow or briefly-stalled verses is
        // what dropped audio the listener never heard ("skips verses").
        if s.itemFailed { return .skipStalled }

        if !s.isPlaying {
            // (A) Loaded/buffering but not yet playing — nudge it (idempotent).
            // With stall-avoidance on, a slow verse becomes ready and plays; we
            // never skip it just for being slow to start.
            return .nudge
        }

        // (C) Playing but the clock is frozen. The only safe interpretation is
        // the very end of the FINAL verse, where AVQueuePlayer can finish the
        // file without firing the end-of-item notification — complete the
        // chapter so auto-advance proceeds. A frozen clock anywhere else is
        // transient buffering between items; leave it to recover rather than
        // skipping a verse the listener hasn't heard.
        if s.clockFrozen, s.frozenFor >= watchdogStallSeconds,
           s.isLastQueuedItem, s.atEnd, !s.didCompleteChapter {
            return .completeChapter
        }
        return .idle
    }

    /// Skips the current player item when it is wedged — `.failed`, or
    /// "playing" with a frozen clock — so a single bad/slow verse can't kill
    /// the whole chapter in silence. Advancing to the next queued item keeps
    /// playback moving; if it empties the queue, the watchdog's drain branch
    /// resumes the instant the next streamed verse arrives, or completes the
    /// chapter if every verse already played.
    private func advancePastStalledItem() {
        guard let player = queuePlayer else { return }
        Self.alog("WATCHDOG skip stalled v=\(currentVerseIndex) status=\(player.currentItem?.status.rawValue ?? -1) err=\(player.currentItem?.error.map { "\($0)" } ?? "-")")
        player.advanceToNextItem()
        lastObservedTime = .zero
        lastObservedTimeAt = nil
        stuckNotPlayingSince = nil
        if player.currentItem != nil {
            player.play()
            player.rate = Float(playbackSpeed.rawValue)
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
                // Reset the stall detector — the position legitimately jumped.
                lastObservedTimeAt = nil
                stuckNotPlayingSince = nil
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
        // Reset the stall detector so the post-resume position isn't read as frozen.
        lastObservedTimeAt = nil
        stuckNotPlayingSince = nil

        syncLiveActivity(isPlaying: true)
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil

        // Cancel all prefetch tasks
        for task in prefetchTasks { task.cancel() }
        prefetchTasks.removeAll()
        prefetchingChapters.removeAll()

        // Stop the independent playback watchdog.
        stopPlaybackWatchdog()

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
            // Re-rate only while actually speaking. When paused we must NOT
            // requeue — `requeueSpeechUtterances` restarts speech, which would
            // secretly resume playback the user had paused. The new speed is
            // held in `playbackSpeed` and takes effect on the next resume/verse.
            guard let synthesizer = speechSynthesizer, synthesizer.isSpeaking, !isPaused else { return }
            let resumeIndex = currentVerseIndex
            speechSynthesizer?.stopSpeaking(at: .immediate)
            requeueSpeechUtterances(from: resumeIndex)
        } else if let player = queuePlayer, isPlaying {
            // Setting a non-zero `rate` on an AVPlayer resumes it. Only apply the
            // new speed live while we're genuinely playing; when paused the speed
            // is stored in `playbackSpeed` and re-applied by resume(), so tapping
            // the speed control mid-pause no longer silently restarts the audio.
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
            // Announce the chapter only at the true top (verse 0), never on a
            // mid-chapter resume / recovery.
            if i == 0 {
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
        // Latch so neither the periodic watchdog nor the end-of-item
        // notification can fire completion a second time for this chapter.
        guard !didCompleteChapter else { return }
        Self.alog("CHAPTER COMPLETE \(currentBookName) \(currentChapter); nextAuto=\(consecutiveAutoAdvances + 1)")
        didCompleteChapter = true
        // The chapter genuinely finished → the next chapter is a clean start.
        lastDrainRecoveryIndex = -1
        drainRecoveryAttempts = 0
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
                    Self.alog("INTERRUPTION began (isPlaying=\(self.isPlaying))")
                    if self.isPlaying { self.pause() }
                case .ended:
                    let opts = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt).map { AVAudioSession.InterruptionOptions(rawValue: $0) }
                    Self.alog("INTERRUPTION ended shouldResume=\(opts?.contains(.shouldResume) ?? false) isPaused=\(self.isPaused)")
                    if let options = opts, options.contains(.shouldResume) && self.isPaused {
                        self.resume()
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Auto-Stop (Background Timer)

    // The audio Bible has the `audio` background mode and is meant to play with
    // the screen off, like a podcast. We deliberately do NOT auto-stop on
    // backgrounding any more — that 2-minute timer was cutting playback off
    // ("stops after about a page and a half"). Runaway playback (someone asleep)
    // is already handled by the "Still listening?" prompt after a few chapters.
    private func setupBackgroundObservers() {}

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
