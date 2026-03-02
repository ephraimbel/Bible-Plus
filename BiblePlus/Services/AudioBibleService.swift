import ActivityKit
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
    var errorMessage: String? = nil
    var playbackSpeed: PlaybackSpeed = .normal

    // MARK: - Speech Synthesis

    private var speechSynthesizer: AVSpeechSynthesizer?
    private var speechDelegate: SpeechDelegate?
    private var speechVerses: [(number: Int, text: String)] = []

    // MARK: - Audio Session Coordination

    private weak var soundscapeService: SoundscapeService?
    private var savedSoundscapeVolume: Float = 0.3

    // MARK: - Chapter Complete Callback

    private var onChapterComplete: (() -> Void)?

    // MARK: - Voice

    var selectedVoice: BibleVoice = .onyx

    // MARK: - Live Activity

    private var bibleActivity: Activity<BibleSessionAttributes>?
    private var currentBookName: String = ""
    private var currentChapter: Int = 0
    private var currentTranslationName: String = ""
    private var currentTotalVerses: Int = 0

    // MARK: - Interruption Handling

    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        setupInterruptionHandling()
    }

    func setSoundscapeService(_ service: SoundscapeService) {
        self.soundscapeService = service
    }

    // MARK: - Play Chapter

    func play(
        verses: [(number: Int, text: String)],
        book: BibleBook,
        chapter: Int,
        translation: BibleTranslation,
        startingFromVerseIndex: Int = 0
    ) {
        stop()

        guard !verses.isEmpty else { return }

        self.speechVerses = verses
        currentVerseIndex = startingFromVerseIndex

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

        // Queue utterances starting from the requested verse
        let voice = selectedVoice.resolvedVoice
        let rate = speechRate(for: playbackSpeed)

        for i in startingFromVerseIndex..<verses.count {
            let verse = verses[i]
            var text = verse.text
            // Prepend chapter intro to the first utterance
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

        // Store metadata for Live Activity
        self.currentBookName = book.name
        self.currentChapter = chapter
        self.currentTranslationName = translation.displayName
        self.currentTotalVerses = verses.count

        self.bibleActivity = LiveActivityService.startBibleSession(
            bookName: book.name,
            chapter: chapter,
            translationName: translation.displayName,
            totalVerses: verses.count,
            currentVerse: startingFromVerseIndex + 1
        )
    }

    // MARK: - Seek to Verse

    func seekToVerse(index: Int) {
        guard index >= 0, index < speechVerses.count else { return }
        speechSynthesizer?.stopSpeaking(at: .immediate)
        currentVerseIndex = index
        requeueSpeechUtterances(from: index)
        if isPaused {
            isPlaying = true
            isPaused = false
        }
    }

    // MARK: - Pause / Resume / Stop

    func pause() {
        speechSynthesizer?.pauseSpeaking(at: .word)
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

        speechSynthesizer?.continueSpeaking()

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
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
        speechDelegate = nil
        speechVerses = []

        isPlaying = false
        isPaused = false
        isLoading = false
        currentVerseIndex = 0
        errorMessage = nil

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
        // AVSpeechSynthesizer doesn't support rate changes mid-stream — restart
        guard let synthesizer = speechSynthesizer, synthesizer.isSpeaking || isPaused else { return }
        let resumeIndex = currentVerseIndex
        speechSynthesizer?.stopSpeaking(at: .immediate)
        requeueSpeechUtterances(from: resumeIndex)
    }

    var hasActivePlayback: Bool {
        isPlaying || isPaused || isLoading
    }

    func setOnChapterComplete(_ handler: @escaping () -> Void) {
        onChapterComplete = handler
    }

    // MARK: - Speech Synthesis Helpers

    /// Re-queues speech utterances from a given verse index (used for seek and speed change).
    private func requeueSpeechUtterances(from index: Int) {
        guard !speechVerses.isEmpty, index < speechVerses.count else { return }

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

        for i in index..<speechVerses.count {
            let utterance = AVSpeechUtterance(string: speechVerses[i].text)
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

    /// Maps PlaybackSpeed to AVSpeechUtterance rate (0.0–1.0 scale, default 0.5).
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

    // MARK: - Voice Selection

    func setVoice(_ voice: BibleVoice) {
        selectedVoice = voice
    }
}

// MARK: - Speech Synthesis Delegate

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
