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

// MARK: - Verse Timing

struct VerseTiming {
    let verseIndex: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
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

    // MARK: - Audio Player

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var verseTimings: [VerseTiming] = []

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

    // MARK: - Live Activity

    private var bibleActivity: Activity<BibleSessionAttributes>?

    // MARK: - Interruption Handling

    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Auto-Stop (Background Timer)

    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var autoStopTask: Task<Void, Never>?
    private static let autoStopDelay: TimeInterval = 120 // 2 minutes

    // MARK: - Network Task

    private var fetchTask: Task<Void, Never>?

    // MARK: - Cache Directory

    private static var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioBibleCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - TTS Endpoint

    private static let ttsEndpoint = URL(string: "\(Secrets.supabaseURL)/functions/v1/tts")!

    // MARK: - Init

    init() {
        setupInterruptionHandling()
        setupBackgroundObservers()
    }

    func setSoundscapeService(_ service: SoundscapeService) {
        self.soundscapeService = service
    }

    // MARK: - Play Chapter (OpenAI TTS with Fallback)

    func play(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        startingFromVerseIndex: Int = 0
    ) {
        stop()

        guard !verses.isEmpty else { return }

        self.currentVerses = verses
        self.currentBook = book
        self.currentChapter = chapter
        self.currentTranslation = translation
        self.currentBookName = book.name
        self.currentTranslationName = translation.displayName
        self.currentTotalVerses = verses.count
        self.currentVerseIndex = startingFromVerseIndex
        self.isLoading = true
        self.isFallbackMode = false

        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioData = try await self.fetchOrGenerateAudio(
                    verses: verses,
                    book: book,
                    chapter: chapter,
                    translation: translation,
                    voice: self.selectedVoice
                )

                guard !Task.isCancelled else { return }

                try await self.startAVAudioPlayback(
                    data: audioData,
                    verses: verses,
                    book: book,
                    chapter: chapter,
                    translation: translation,
                    startingFromVerseIndex: startingFromVerseIndex
                )
            } catch is CancellationError {
                // Cancelled — do nothing
            } catch AudioBibleError.cancelled {
                // Cancelled — do nothing
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

    // MARK: - Fetch or Generate Audio

    private func fetchOrGenerateAudio(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        voice: BibleVoice
    ) async throws -> Data {
        let inputText = buildChapterText(verses: verses, book: book, chapter: chapter)
        let cacheKey = buildCacheKey(voice: voice, text: inputText)

        // Check device cache first
        let cachedURL = Self.cacheDirectory.appendingPathComponent("\(cacheKey).mp3")
        if let data = try? Data(contentsOf: cachedURL), !data.isEmpty {
            return data
        }

        // Call Supabase TTS edge function
        let data = try await callTTSAPI(text: inputText, voice: voice)

        guard !Task.isCancelled else {
            throw AudioBibleError.cancelled
        }

        // Save to device cache
        try? data.write(to: cachedURL)

        return data
    }

    private func buildChapterText(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int
    ) -> String {
        var parts: [String] = []
        parts.append("\(book.name), chapter \(chapter).")
        for verse in verses {
            parts.append(verse.text)
        }
        return parts.joined(separator: " ")
    }

    private func buildCacheKey(voice: BibleVoice, text: String) -> String {
        let input = "\(voice.apiVoice):\(text)"
        let digest = SHA256.hash(data: Data(input.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "\(voice.apiVoice)-\(hash.prefix(32))"
    }

    // MARK: - TTS API Call (with retry)

    private func callTTSAPI(text: String, voice: BibleVoice, retryCount: Int = 0) async throws -> Data {
        // Split long texts into chunks if over 4000 chars (OpenAI TTS limit is ~4096)
        if text.count > 4000 {
            return try await callTTSAPIChunked(text: text, voice: voice)
        }

        var request = URLRequest(url: Self.ttsEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": voice.apiVoice,
            "response_format": "mp3",
            "speed": 1.0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudioBibleError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 200 {
            guard !data.isEmpty else {
                throw AudioBibleError.audioDecodingFailed
            }
            return data
        }

        // Retry once on server error
        if httpResponse.statusCode >= 500 && retryCount < 1 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return try await callTTSAPI(text: text, voice: voice, retryCount: retryCount + 1)
        }

        let errorMsg = String(data: data, encoding: .utf8) ?? "API error \(httpResponse.statusCode)"
        throw AudioBibleError.apiError(errorMsg)
    }

    /// Splits long text into chunks and concatenates the audio.
    private func callTTSAPIChunked(text: String, voice: BibleVoice) async throws -> Data {
        let sentences = text.components(separatedBy: ". ")
        var chunks: [String] = []
        var current = ""

        for sentence in sentences {
            let candidate = current.isEmpty ? sentence : current + ". " + sentence
            if candidate.count > 3800 && !current.isEmpty {
                chunks.append(current + ".")
                current = sentence
            } else {
                current = candidate
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }

        var combinedData = Data()
        for chunk in chunks {
            guard !Task.isCancelled else {
                throw AudioBibleError.cancelled
            }
            let chunkData = try await callTTSAPI(text: chunk, voice: voice)
            combinedData.append(chunkData)
        }
        return combinedData
    }

    // MARK: - AVAudioPlayer Playback

    private func startAVAudioPlayback(
        data: Data,
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        startingFromVerseIndex: Int
    ) async throws {
        guard !Task.isCancelled else { throw AudioBibleError.cancelled }

        let player = try AVAudioPlayer(data: data)
        player.enableRate = true
        player.rate = Float(playbackSpeed.rawValue)
        player.prepareToPlay()

        // Estimate verse timings based on character count
        self.verseTimings = estimateVerseTimings(
            verses: verses,
            totalDuration: player.duration,
            hasChapterIntro: true,
            bookName: book.name,
            chapter: chapter
        )

        self.audioPlayer = player

        configureAudioSession()
        duckSoundscape()

        // Seek to starting verse if needed
        if startingFromVerseIndex > 0, startingFromVerseIndex < verseTimings.count {
            player.currentTime = verseTimings[startingFromVerseIndex].startTime
            currentVerseIndex = startingFromVerseIndex
        }

        player.play()

        isPlaying = true
        isPaused = false
        isLoading = false

        // Start progress timer
        startProgressTimer()

        // Start Live Activity
        bibleActivity = LiveActivityService.startBibleSession(
            bookName: book.name,
            chapter: chapter,
            translationName: translation.displayName,
            totalVerses: verses.count,
            currentVerse: startingFromVerseIndex + 1
        )
    }

    /// Estimates verse timing positions based on character proportions.
    private func estimateVerseTimings(
        verses: [(number: Int, text: String)],
        totalDuration: TimeInterval,
        hasChapterIntro: Bool,
        bookName: String,
        chapter: Int
    ) -> [VerseTiming] {
        // Account for the chapter intro text in timing
        let introText = hasChapterIntro ? "\(bookName), chapter \(chapter). " : ""
        let totalChars = Double(introText.count + verses.reduce(0) { $0 + $1.text.count })
        guard totalChars > 0 else { return [] }

        let introFraction = Double(introText.count) / totalChars
        var currentTime = totalDuration * introFraction

        var timings: [VerseTiming] = []
        for (i, verse) in verses.enumerated() {
            let verseFraction = Double(verse.text.count) / totalChars
            let verseDuration = totalDuration * verseFraction
            let startTime = currentTime
            let endTime = currentTime + verseDuration
            timings.append(VerseTiming(verseIndex: i, startTime: startTime, endTime: endTime))
            currentTime = endTime
        }
        return timings
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgressFromPlayer()
            }
        }
    }

    private func updateProgressFromPlayer() {
        guard let player = audioPlayer, isPlaying else { return }

        // Check for playback completion
        if !player.isPlaying && !isPaused {
            handlePlaybackCompletion()
            return
        }

        let currentTime = player.currentTime
        // Find current verse based on timing
        for timing in verseTimings.reversed() {
            if currentTime >= timing.startTime {
                if currentVerseIndex != timing.verseIndex {
                    currentVerseIndex = timing.verseIndex
                    if let activity = bibleActivity {
                        LiveActivityService.updateBibleSession(
                            activity,
                            currentVerse: currentVerseIndex + 1,
                            isPlaying: true
                        )
                    }
                }
                break
            }
        }
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
            if let activity = self.bibleActivity {
                LiveActivityService.updateBibleSession(
                    activity,
                    currentVerse: verseIndex + 1,
                    isPlaying: true
                )
            }
        } onComplete: { [weak self] in
            guard let self else { return }
            self.handlePlaybackCompletion()
        }

        synthesizer.delegate = delegate
        self.speechSynthesizer = synthesizer
        self.speechDelegate = delegate

        configureAudioSession()
        duckSoundscape()

        let voice = selectedVoice.resolvedVoice
        let rate = speechRate(for: playbackSpeed)

        for i in startingFromVerseIndex..<verses.count {
            let verse = verses[i]
            var text = verse.text
            if i == startingFromVerseIndex {
                text = "\(book.name), chapter \(chapter). \(text)"
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

        bibleActivity = LiveActivityService.startBibleSession(
            bookName: book.name,
            chapter: chapter,
            translationName: translation.displayName,
            totalVerses: verses.count,
            currentVerse: startingFromVerseIndex + 1
        )
    }

    // MARK: - Seek to Verse

    func seekToVerse(index: Int) {
        guard index >= 0, index < currentVerses.count else { return }

        if isFallbackMode {
            // Speech fallback: stop and re-queue from index
            speechSynthesizer?.stopSpeaking(at: .immediate)
            currentVerseIndex = index
            requeueSpeechUtterances(from: index)
            if isPaused {
                isPlaying = true
                isPaused = false
            }
        } else if let player = audioPlayer, index < verseTimings.count {
            player.currentTime = verseTimings[index].startTime
            currentVerseIndex = index
            if isPaused {
                player.play()
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
            audioPlayer?.pause()
            progressTimer?.invalidate()
        }

        isPlaying = false
        isPaused = true
        restoreSoundscape()

        if let activity = bibleActivity {
            LiveActivityService.updateBibleSession(
                activity,
                currentVerse: currentVerseIndex + 1,
                isPlaying: false
            )
        }
    }

    func resume() {
        guard isPaused else { return }
        configureAudioSession()
        duckSoundscape()

        if isFallbackMode {
            speechSynthesizer?.continueSpeaking()
        } else {
            audioPlayer?.play()
            startProgressTimer()
        }

        isPlaying = true
        isPaused = false

        if let activity = bibleActivity {
            LiveActivityService.updateBibleSession(
                activity,
                currentVerse: currentVerseIndex + 1,
                isPlaying: true
            )
        }
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil

        // Stop AVAudioPlayer
        audioPlayer?.stop()
        audioPlayer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        verseTimings = []

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

        if let activity = bibleActivity {
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
            // Speech: must restart from current verse
            guard let synthesizer = speechSynthesizer, synthesizer.isSpeaking || isPaused else { return }
            let resumeIndex = currentVerseIndex
            speechSynthesizer?.stopSpeaking(at: .immediate)
            requeueSpeechUtterances(from: resumeIndex)
        } else if let player = audioPlayer {
            player.rate = Float(speed.rawValue)
        }
    }

    var hasActivePlayback: Bool {
        isPlaying || isPaused || isLoading
    }

    func setOnChapterComplete(_ handler: @escaping () -> Void) {
        onChapterComplete = handler
    }

    // MARK: - Prefetch Next Chapter

    func prefetchAudio(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation
    ) {
        Task.detached { [weak self] in
            guard let self else { return }
            let voice = await self.selectedVoice
            _ = try? await self.fetchOrGenerateAudio(
                verses: verses,
                book: book,
                chapter: chapter,
                translation: translation,
                voice: voice
            )
        }
    }

    // MARK: - Speech Fallback Helpers

    private func requeueSpeechUtterances(from index: Int) {
        guard !currentVerses.isEmpty, index < currentVerses.count else { return }

        let synthesizer = speechSynthesizer ?? AVSpeechSynthesizer()
        if speechSynthesizer == nil {
            let delegate = SpeechDelegate { [weak self] verseIndex in
                guard let self else { return }
                self.currentVerseIndex = verseIndex
                if let activity = self.bibleActivity {
                    LiveActivityService.updateBibleSession(
                        activity,
                        currentVerse: verseIndex + 1,
                        isPlaying: true
                    )
                }
            } onComplete: { [weak self] in
                guard let self else { return }
                self.handlePlaybackCompletion()
            }
            synthesizer.delegate = delegate
            self.speechSynthesizer = synthesizer
            self.speechDelegate = delegate
        }

        let voice = selectedVoice.resolvedVoice
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
        progressTimer?.invalidate()
        progressTimer = nil
        isPlaying = false
        isPaused = false

        if let activity = bibleActivity {
            LiveActivityService.endBibleSession(activity)
            bibleActivity = nil
        }

        restoreSoundscape()
        onChapterComplete?()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Audio session setup failed — playback may not work
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
            // Session category restore failed — non-critical
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
            // Still backgrounded after 2 minutes — stop playback
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
        // Handled by stop() — no action needed
    }
}
