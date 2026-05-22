import Foundation
import AVFoundation

/// Picks the best available `AVSpeechSynthesisVoice` for a given UI language
/// code. Used by `AudioBibleService` so that a user reading the Bible in
/// Spanish hears a Spanish voice (Mónica / Paulina / Jorge) instead of the
/// legacy English personas baked into `BibleVoice`.
///
/// Resolution order per language:
///   1. Premium / enhanced voices for the BCP-47 region (e.g. es-ES, es-MX)
///   2. Any compact system voice for the base language code (es-*)
///   3. `AVSpeechSynthesisVoice(language:)` default lookup
///   4. `nil` — caller should fall back to the user's chosen `BibleVoice`
///
/// Language codes not in `preferredBCP47` (e.g. Amharic — iOS has no Amharic
/// voice as of iOS 17) return nil so the fallback path kicks in.
enum LocaleVoiceResolver {

    /// Maps app-language codes (from `SupportedLanguage.all`) to the
    /// BCP-47 locale we ask AVSpeech for. Picks the most widely-available
    /// regional voice per language.
    private static let preferredBCP47: [String: [String]] = [
        "es":      ["es-ES", "es-MX", "es-US"],
        "pt-BR":   ["pt-BR", "pt-PT"],
        "pt-PT":   ["pt-PT", "pt-BR"],
        "fr":      ["fr-FR", "fr-CA"],
        "de":      ["de-DE"],
        "it":      ["it-IT"],
        "pl":      ["pl-PL"],
        "ru":      ["ru-RU"],
        "zh-Hans": ["zh-CN", "zh-SG"],
        "zh-Hant": ["zh-TW", "zh-HK"],
        "ko":      ["ko-KR"],
        "ja":      ["ja-JP"],
        "id":      ["id-ID"],
        "tl":      ["fil-PH", "tl-PH"],
        "sw":      ["sw-KE", "sw-TZ"],
        // Amharic intentionally omitted — no iOS system voice available.
    ]

    /// Return the best voice iOS can serve for this app-language code, or
    /// nil when nothing matches (Amharic today, future additions).
    static func voice(forLanguageCode code: String) -> AVSpeechSynthesisVoice? {
        let bcp47s = preferredBCP47[code] ?? preferredBCP47[String(code.prefix { $0 != "-" })] ?? []
        guard !bcp47s.isEmpty else { return nil }

        let all = AVSpeechSynthesisVoice.speechVoices()
        for locale in bcp47s {
            // Try exact-match voices in quality order: premium, enhanced, default.
            let candidates = all.filter { $0.language == locale }
            if !candidates.isEmpty {
                if let premium = candidates.first(where: { $0.quality == .premium }) { return premium }
                if let enhanced = candidates.first(where: { $0.quality == .enhanced }) { return enhanced }
                return candidates.first
            }
        }

        // Base-language match (e.g. any "es-*" for a requested "es-ES") —
        // covers devices where only compact voices are installed.
        let base = String(bcp47s.first?.prefix(2) ?? "")
        if !base.isEmpty {
            let baseMatches = all.filter { $0.language.hasPrefix(base) }
            if let premium = baseMatches.first(where: { $0.quality == .premium }) { return premium }
            if let enhanced = baseMatches.first(where: { $0.quality == .enhanced }) { return enhanced }
            if let anyMatch = baseMatches.first { return anyMatch }
        }

        // Last-resort: ask AVSpeech directly — returns whatever it considers
        // the system default for the first BCP-47 we had in mind.
        if let first = bcp47s.first {
            return AVSpeechSynthesisVoice(language: first)
        }
        return nil
    }
}
