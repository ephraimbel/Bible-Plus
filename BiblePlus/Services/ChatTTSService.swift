import Foundation
import AVFoundation
import Observation

/// Lightweight text-to-speech service for chat messages.
///
/// Distinct from `AudioBibleService` (which streams chapter-level verse
/// audio with prefetching, live activities, and queue playback) — this is
/// designed for one-shot reading of a single AI response. It uses
/// `AVSpeechSynthesizer` directly so there's no network call, no token cost,
/// and no audio cache to manage.
///
/// Lifecycle:
///   - `play(message:voice:)` cleans the message of card markup and starts speaking
///   - `stop()` immediately halts playback
///   - `isPlaying(messageId:)` lets bubbles know whether they are the current speaker
///
/// Audio session: configures `.playback` with `.duckOthers` on play and clears
/// it on stop, so a chat TTS read won't fight a soundscape if one is running.
@Observable
@MainActor
final class ChatTTSService: NSObject {
    // MARK: - State

    private(set) var currentMessageId: UUID? = nil

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private var didConfigureDelegate = false

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
        didConfigureDelegate = true
    }

    // MARK: - Public API

    /// True if the given message id is the one currently being read aloud.
    func isPlaying(messageId: UUID) -> Bool {
        currentMessageId == messageId
    }

    /// Reads the given message aloud. If another message is already playing,
    /// it is stopped first. If THIS message is already playing, the call is
    /// a toggle and stops playback.
    func play(messageId: UUID, content: String, voice: BibleVoice) {
        // Toggle behavior: tapping Listen on a playing bubble stops it.
        if currentMessageId == messageId {
            stop()
            return
        }

        // Switching speakers — halt the previous one.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let cleaned = Self.cleanForSpeech(content)
        guard !cleaned.isEmpty else { return }

        configureAudioSession()

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = voice.resolvedVoice
        // Slower + lower pitch so the narrator sounds profound and measured
        // rather than conversational. These values were tuned against the
        // Daniel (en-GB) compact voice — the guaranteed fallback — which
        // benefits most from a deeper pitch.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 0.92
        utterance.postUtteranceDelay = 0.2

        currentMessageId = messageId
        synthesizer.speak(utterance)
    }

    /// Stops any in-flight playback.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentMessageId = nil
        deactivateAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Non-critical — speech will still play through default routing
            #if DEBUG
            print("[ChatTTSService] Audio session config failed: \(error)")
            #endif
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-critical
        }
    }

    // MARK: - Speech Cleanup

    /// Strips card markup, markdown decoration, and follow-up markers from a
    /// chat message so the text reads naturally aloud. The goal is for the
    /// listener to never hear "open square bracket scripture image equals" —
    /// only the substance.
    static func cleanForSpeech(_ raw: String) -> String {
        var text = raw

        // 1. Strip the trailing |||suggestion||| follow-ups marker
        if let pipeRange = text.range(of: "|||") {
            text = String(text[..<pipeRange.lowerBound])
        }

        // 2. Unwrap [SCRIPTURE img="..."]"quote" — Reference[/SCRIPTURE]
        //    into "Scripture: quote. From Reference."
        text = unwrapTagBlocks(text, tag: "SCRIPTURE") { body in
            let parsed = parseVerseBodyForSpeech(body)
            if !parsed.reference.isEmpty {
                return "Scripture: \(parsed.quote). From \(parsed.reference)."
            }
            return parsed.quote
        }

        // 3. Same for the simpler [VERSE] tag
        text = unwrapTagBlocks(text, tag: "VERSE") { body in
            let parsed = parseVerseBodyForSpeech(body)
            if !parsed.reference.isEmpty {
                return "\(parsed.quote). From \(parsed.reference)."
            }
            return parsed.quote
        }

        // 4. [STORY title="..."]summary[/STORY] → "Story. Title. Summary."
        text = unwrapTagBlocks(text, tag: "STORY") { body in
            return body
        }

        // 5. [PRAYER]prayer text[/PRAYER] → "A prayer. prayer text"
        text = unwrapTagBlocks(text, tag: "PRAYER") { body in
            return "A prayer. \(body)"
        }

        // 6. [REFLECT]question[/REFLECT] → "Reflect. question"
        text = unwrapTagBlocks(text, tag: "REFLECT") { body in
            return "Something to sit with. \(body)"
        }

        // 7. [INSIGHT]text[/INSIGHT] → "Key insight. text"
        text = unwrapTagBlocks(text, tag: "INSIGHT") { body in
            return "Key insight. \(body)"
        }

        // 8. [IMAGE key="..."]caption[/IMAGE] → just the caption
        text = unwrapTagBlocks(text, tag: "IMAGE") { body in
            return body
        }

        // 9. [ACTION ...]description[/ACTION] → just the description
        text = unwrapTagBlocks(text, tag: "ACTION") { body in
            return body
        }

        // 10. [TIMELINE]events[/TIMELINE] — flatten to a comma list
        text = unwrapTagBlocks(text, tag: "TIMELINE") { body in
            let events = body
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { line -> String in
                    // "Event | Reference | Period" → "Event"
                    line.components(separatedBy: "|")
                        .first?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? line
                }
            return events.joined(separator: ". ")
        }

        // 11. [CROSSREFS]...[/CROSSREFS] — read as "Cross references. ..."
        text = unwrapTagBlocks(text, tag: "CROSSREFS") { body in
            let refs = body
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { line -> String in
                    // "Reference || Quote" → "Reference: Quote"
                    let parts = line.components(separatedBy: line.contains("||") ? "||" : "|")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    if parts.count >= 2 {
                        return "\(parts[0]): \(parts[1])"
                    }
                    return parts.first ?? ""
                }
                .filter { !$0.isEmpty }
            return "Cross references. \(refs.joined(separator: ". "))"
        }

        // 12. Strip ## headings — they don't read naturally; replace with a pause
        if let regex = try? NSRegularExpression(
            pattern: #"^#{1,3}\s+(.+)$"#,
            options: [.anchorsMatchLines]
        ) {
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            text = regex.stringByReplacingMatches(
                in: text,
                range: fullRange,
                withTemplate: "$1."
            )
        }

        // 13. Strip markdown bold (**) and italic (*)
        text = text.replacingOccurrences(of: #"\*{1,2}([^*]+)\*{1,2}"#, with: "$1", options: .regularExpression)

        // 14. Strip any stray remaining tags we didn't unwrap
        text = text.replacingOccurrences(
            of: #"\[/?[A-Z]+(?:\s+[^\]]*)?\]"#,
            with: " ",
            options: .regularExpression
        )

        // 15. Collapse whitespace
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    /// Replaces `[TAG ...]body[/TAG]` blocks with `transform(body)`. Tag may
    /// have arbitrary attributes. Body is captured non-greedily and may span
    /// multiple lines.
    private static func unwrapTagBlocks(
        _ text: String,
        tag: String,
        transform: (String) -> String
    ) -> String {
        let pattern = #"\["# + tag + #"(?:\s+[^\]]*)?\]([\s\S]*?)\[/"# + tag + #"\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let nsText = text as NSString
        var result = ""
        var cursor = 0
        let fullRange = NSRange(location: 0, length: nsText.length)

        regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match = match else { return }
            // Append text before the match
            if match.range.location > cursor {
                let before = nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result += before
            }
            // Append the transformed body, padded with spaces so it doesn't
            // fuse with surrounding text
            let bodyRange = match.range(at: 1)
            let body = nsText.substring(with: bodyRange).trimmingCharacters(in: .whitespacesAndNewlines)
            result += " " + transform(body) + " "
            cursor = match.range.location + match.range.length
        }
        // Append remaining text after the last match
        if cursor < nsText.length {
            result += nsText.substring(with: NSRange(location: cursor, length: nsText.length - cursor))
        }
        return result
    }

    /// Splits `"quote" — Reference` (with various dash + quote variants) into
    /// quote and reference. Falls back to the whole body as the quote if it
    /// can't parse.
    private static func parseVerseBodyForSpeech(_ body: String) -> (quote: String, reference: String) {
        let patterns = [
            #"["“"]([^"”"]+)["”"]\s*[-–—]\s*(.+)$"#,
            #"^(.+?)\s*[-–—]\s*(\S.+)$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
                  let match = regex.firstMatch(in: body, range: NSRange(location: 0, length: (body as NSString).length)),
                  let quoteRange = Range(match.range(at: 1), in: body),
                  let refRange = Range(match.range(at: 2), in: body)
            else { continue }
            let quote = String(body[quoteRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let reference = String(body[refRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !quote.isEmpty {
                return (quote, reference)
            }
        }
        return (body, "")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension ChatTTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentMessageId = nil
            self.deactivateAudioSession()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentMessageId = nil
            self.deactivateAudioSession()
        }
    }
}
