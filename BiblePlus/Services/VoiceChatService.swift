import Foundation
import AVFoundation
import Speech
import Observation

// MARK: - Voice Chat Service
//
// Hands-free conversation loop:
//   idle → listening (mic + on-device STT)
//   → processing (text being sent + AI streaming)
//   → speaking (AI response read aloud sentence-by-sentence)
//   → idle (or back to listening if auto-listen is on)
//
// Designed to be the single owner of the audio session while voice chat is
// open. The view that hosts it is responsible for stopping the soundscape
// before entering and resuming after dismissing — this service won't fight
// SoundscapeService for the session, it just owns it cleanly.
//
// The transcript callback fires on every partial result so the UI can render
// live "what we hear you saying" text as the user speaks. The final string is
// returned by `stopListening()`.

@Observable
@MainActor
final class VoiceChatService: NSObject {

    // MARK: - State

    enum VoiceChatState: Equatable {
        case idle
        case listening
        case processing
        case speaking
    }

    enum PermissionStatus: Equatable {
        case unknown
        case granted
        case denied
        case restricted
    }

    private(set) var state: VoiceChatState = .idle
    private(set) var liveTranscript: String = ""
    private(set) var micPermission: PermissionStatus = .unknown
    private(set) var speechPermission: PermissionStatus = .unknown
    private(set) var lastError: String? = nil

    // MARK: - Speech (STT)

    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Synthesis (TTS)

    private let synthesizer = AVSpeechSynthesizer()
    private var didConfigureDelegate = false

    /// Sentence buffer for streaming TTS — characters arrive token-by-token
    /// from the AI; we accumulate them, find sentence boundaries, and enqueue
    /// completed sentences as they form so the user starts hearing the answer
    /// almost immediately instead of waiting for the full response.
    private var sentenceBuffer: String = ""

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
        didConfigureDelegate = true
        refreshPermissionStatus()
    }

    // MARK: - Permissions

    func refreshPermissionStatus() {
        // Microphone
        switch AVAudioApplication.shared.recordPermission {
        case .granted: micPermission = .granted
        case .denied: micPermission = .denied
        case .undetermined: micPermission = .unknown
        @unknown default: micPermission = .unknown
        }

        // Speech recognition
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speechPermission = .granted
        case .denied: speechPermission = .denied
        case .restricted: speechPermission = .restricted
        case .notDetermined: speechPermission = .unknown
        @unknown default: speechPermission = .unknown
        }
    }

    /// Requests both mic and speech permissions in sequence. Returns true only
    /// if BOTH are granted by the time the call resolves.
    @discardableResult
    func requestPermissions() async -> Bool {
        // Mic first — speech rec can't function without it.
        let micGranted: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        micPermission = micGranted ? .granted : .denied

        // Speech recognition
        let speechGranted: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        speechPermission = speechGranted ? .granted : .denied

        return micGranted && speechGranted
    }

    var hasAllPermissions: Bool {
        micPermission == .granted && speechPermission == .granted
    }

    // MARK: - Listening (STT)

    /// Begins capturing audio from the mic and feeding it into Speech
    /// recognition. The `liveTranscript` property is updated continuously as
    /// partial results arrive. Throws if the audio engine or recognizer
    /// can't be started.
    func startListening() throws {
        guard hasAllPermissions else {
            throw VoiceChatError.permissionDenied
        }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceChatError.recognizerUnavailable
        }

        // Stop anything currently running.
        stopListeningInternal(updateState: false)
        stopSpeakingInternal()

        // Configure audio session for recording.
        try configureAudioSession(forRecording: true)

        // Build a fresh request — recognition tasks are single-use.
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition for privacy + offline support. Falls
        // back gracefully if the model isn't installed.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        // Tap the mic input.
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // Defensive: detach any existing tap from a prior session.
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        liveTranscript = ""
        lastError = nil
        state = .listening

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.liveTranscript = text
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self.cleanupRecognition()
                }
            }
        }
    }

    /// Stops capturing audio and returns the final transcript captured so far.
    /// Safe to call from any state — no-ops if not listening.
    @discardableResult
    func stopListening() -> String {
        let final = liveTranscript
        stopListeningInternal(updateState: true)
        return final
    }

    private func stopListeningInternal(updateState: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cleanupRecognition()

        if updateState && state == .listening {
            state = .idle
        }
    }

    private func cleanupRecognition() {
        recognitionRequest = nil
        recognitionTask = nil
    }

    // MARK: - Speaking (TTS)

    /// Marks voice chat as "processing" — used between user finishing speaking
    /// and the AI's first sentence being ready to read.
    func enterProcessing() {
        if state != .processing {
            state = .processing
        }
        sentenceBuffer = ""
    }

    /// Feeds incoming AI tokens into the sentence buffer. Whenever a complete
    /// sentence forms (ends in . ! ? newline) it gets enqueued for speech
    /// immediately — that's how the user hears the response stream rather
    /// than waiting for the whole thing to finish.
    func feedStreamingText(_ delta: String) {
        guard !delta.isEmpty else { return }
        sentenceBuffer += delta
        flushCompleteSentences()
    }

    /// Called when the AI is finished streaming. Flushes anything left in the
    /// sentence buffer (the trailing fragment that didn't end in punctuation)
    /// so nothing gets lost.
    func finishStreaming() {
        let remainder = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        sentenceBuffer = ""
        if !remainder.isEmpty {
            enqueueUtterance(remainder)
        }
    }

    /// Speaks an entire string as one utterance. Useful for a one-shot read
    /// after the entire response is in hand (non-streaming path).
    func speak(_ text: String) {
        let cleaned = ChatTTSService.cleanForSpeech(text)
        guard !cleaned.isEmpty else { return }
        enqueueUtterance(cleaned)
    }

    private func flushCompleteSentences() {
        // Walk the buffer for sentence-ending punctuation. Only flush at
        // boundaries that have at least one space-or-end after them so we
        // don't break mid-abbreviation. We also gate on a min length so we
        // don't speak fragments like "Yes." or "Sure." in isolation.
        let minSpeakable = 12
        var emitted = ""

        while true {
            guard let boundary = nextSentenceBoundary(in: sentenceBuffer) else { break }

            let sentence = String(sentenceBuffer[..<boundary])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Drop everything up through the boundary from the buffer.
            sentenceBuffer = String(sentenceBuffer[boundary...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                + " "

            if sentence.count < minSpeakable {
                // Too short to read on its own; reattach to the buffer so it
                // can join the next sentence.
                sentenceBuffer = sentence + " " + sentenceBuffer
                break
            }

            emitted += " " + sentence
        }

        let trimmedEmit = emitted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmit.isEmpty {
            enqueueUtterance(trimmedEmit)
        }
    }

    /// Finds the next sentence-ending punctuation followed by whitespace or
    /// end-of-string. Returns the index AFTER the punctuation.
    private func nextSentenceBoundary(in text: String) -> String.Index? {
        let endings: Set<Character> = [".", "!", "?", "\n"]
        var i = text.startIndex
        while i < text.endIndex {
            if endings.contains(text[i]) {
                let after = text.index(after: i)
                if after == text.endIndex || text[after].isWhitespace {
                    return after
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private func enqueueUtterance(_ text: String) {
        let cleaned = ChatTTSService.cleanForSpeech(text)
        guard !cleaned.isEmpty else { return }

        // Make sure the audio session is configured for playback now that
        // we're about to speak. (We may still be in playAndRecord mode from
        // the listening phase — the synth handles either category fine.)
        try? configureAudioSession(forRecording: false)

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = currentSynthesisVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.15

        if state != .speaking {
            state = .speaking
        }
        synthesizer.speak(utterance)
    }

    /// Returns the user's preferred TTS voice. Falls back to default English.
    private func currentSynthesisVoice() -> AVSpeechSynthesisVoice? {
        // Default to "onyx" mapping if we can't fetch the user profile here —
        // the view layer is responsible for picking a voice if it wants to
        // override.
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            return voice
        }
        return nil
    }

    /// Hard-stops any in-flight speech.
    func stopSpeaking() {
        stopSpeakingInternal()
    }

    private func stopSpeakingInternal() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        sentenceBuffer = ""
        if state == .speaking {
            state = .idle
        }
    }

    // MARK: - Lifecycle

    /// Tear down everything and release the audio session. Call when the
    /// voice chat view is dismissed.
    func teardown() {
        stopListeningInternal(updateState: false)
        stopSpeakingInternal()
        deactivateAudioSession()
        liveTranscript = ""
        sentenceBuffer = ""
        state = .idle
    }

    // MARK: - Audio Session

    private func configureAudioSession(forRecording: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        if forRecording {
            // .playAndRecord lets us mic in AND speak out without juggling
            // categories between turns. .duckOthers softens any ambient music.
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
            )
        } else {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try session.setActive(true, options: [])
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-critical — happens routinely if no session was active
        }
    }
}

// MARK: - Errors

enum VoiceChatError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case audioEngineFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or speech recognition permission was not granted."
        case .recognizerUnavailable:
            return "Speech recognition isn't available right now."
        case .audioEngineFailed:
            return "Could not start the microphone."
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceChatService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Only fall back to idle if there are no more queued utterances.
            // AVSpeechSynthesizer reports didFinish for each utterance even
            // when more are queued, but `isSpeaking` stays true between them.
            if !synthesizer.isSpeaking && self.state == .speaking {
                self.state = .idle
            }
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.state == .speaking {
                self.state = .idle
            }
        }
    }
}
