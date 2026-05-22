import Foundation

/// Maps UI language codes to a reasonable default `TranslationRef.id` from
/// bible.helloao.org's catalog. When a user switches the app to Spanish and
/// hasn't chosen a Bible yet, we pick Reina-Valera 1909 for them; when they
/// flip to Japanese we pick what's available. Users can still override in the
/// translation picker.
///
/// IDs here must exactly match helloao's `available_translations.json`. Hand-
/// picked on 2026-04-23 by scanning the live catalog — see the inline comment
/// next to each entry for the chosen rationale.
///
/// Coverage notes:
///   - Japanese (`jpn_loc`): NT only (27 books). OT reads fall back to the
///     legacy enum until a complete JA option lands in the catalog.
///   - Amharic (`amh_amh`): NT only. Same fallback behavior.
enum LanguageDefaultBible {

    /// English always uses the bundled KJV — we don't point at helloao for
    /// English users because the bundled translations are offline-first and
    /// compile-time guaranteed.
    static let bundledEnglishID = "bundled_kjv"

    /// Tier 1 language → default helloao translation id. Keys are the `code`
    /// values from `SupportedLanguage.all`.
    static let defaults: [String: String] = [
        "en":      "bundled_kjv",   // Bundled
        "es":      "spa_r09",       // Reina Valera 1909 — classic, PD
        "pt-BR":   "por_blj",       // Bíblia Livre
        "pt-PT":   "por_blj",       // same — closest thing to PT-PT in helloao
        "fr":      "fra_lsg",       // Louis Segond 1910 — classic
        "de":      "deu_l12",       // Luther Bibel 1912 — classic
        "it":      "ita_riv",       // Riveduta
        "pl":      "pol_ubg",       // Updated Gdansk
        "ru":      "rus_syn",       // Synodal 1876 — the Russian Bible
        "zh-Hans": "cmn_cu1",       // 新标点和合本 simplified CUV
        "zh-Hant": "cmn_cuv",       // 新標點和合本 traditional CUV
        "ko":      "kor_old",       // Korean 1910
        "ja":      "jpn_loc",       // Japanese NT only
        "id":      "ind_ayt",       // Indonesian AYT
        "tl":      "tgl_ulb",       // Tagalog ULB
        "sw":      "swh_bib",       // Kiswahili Contemporary
        "am":      "amh_amh",       // Amharic NT only
    ]

    /// Resolve a language code (possibly with a region tag like `pt-BR` or
    /// `zh-Hans`) to the right helloao id. Tries exact match first, then
    /// falls back to the base language ("pt" → first "pt-*" entry). Returns
    /// nil for unknown locales so callers can route to the legacy KJV path.
    static func defaultRefID(for languageCode: String) -> String? {
        if let hit = defaults[languageCode] { return hit }
        let base = String(languageCode.prefix { $0 != "-" })
        if let hit = defaults[base] { return hit }
        // Match the first entry whose base equals the requested base.
        if let match = defaults.first(where: { $0.key.hasPrefix(base + "-") || $0.key == base }) {
            return match.value
        }
        return nil
    }

    /// True when the default translation for `languageCode` is NT-only.
    /// BibleReaderViewModel uses this to warn users and to fall back to the
    /// bundled English path when an OT chapter is requested.
    static func isNewTestamentOnly(refID: String) -> Bool {
        refID == "jpn_loc" || refID == "amh_amh"
    }
}
