import Foundation

/// Maps UI language codes to a reasonable default `TranslationRef.id` from
/// a translation bundled in the app. When a user switches the app to Spanish and
/// hasn't chosen a Bible yet, we pick Reina-Valera 1909 for them; when they
/// flip to Japanese we pick what's available. Users can still override in the
/// translation picker.
///
/// Every ID here must be bundled (`Resources/Bible/bible-<ID>.json`) and
/// listed in `TranslationLicensePolicy.bundled`. Re-vetted 2026-11-13.
///
/// Coverage notes:
///   - Indonesian (`ind_tsi`): 48 books. Missing books fall back to WEB.
enum LanguageDefaultBible {

    /// English always uses the bundled WEB — we don't use a ref for
    /// English users because the bundled translations are offline-first and
    /// compile-time guaranteed.
    static let bundledEnglishID = "bundled_web"

    /// Tier 1 language → default bundled translation id. Keys are the `code`
    /// values from `SupportedLanguage.all`.
    static let defaults: [String: String] = [
        "en":      "bundled_web",   // Bundled
        "es":      "spa_r09",       // Reina Valera 1909 — classic, PD
        "pt-BR":   "por_blj",       // Bíblia Livre
        "pt-PT":   "por_blj",       // same — closest open-licensed option for PT-PT
        "fr":      "fra_lsg",       // Louis Segond 1910 — classic
        "de":      "deu_l12",       // Luther Bibel 1912 — classic
        "it":      "ita_riv",       // Riveduta
        // "pl": no non-Biblica Polish text allows commercial use + derivatives
        // (UBG is CC BY-ND), so Polish falls back to WEB.
        "ru":      "rus_syn",       // Synodal 1876 — the Russian Bible
        "zh-Hans": "cmn_cu1",       // 新标点和合本 simplified CUV
        "zh-Hant": "cmn_cuv",       // 新標點和合本 traditional CUV
        "ko":      "kor_old",       // Korean 1910
        "ja":      "jpn_kou",       // Kougo-yaku 1955 — public domain, complete
        "id":      "ind_tsi",       // Plain Indonesian — CC BY-SA, 48 books (AYT is CC BY-NC)
        "tl":      "tgl_ulb",       // Tagalog ULB
        "sw":      "swh_ulb",       // Swahili Unlocked Literal Bible — CC BY-SA
        // "am": no Amharic translation we found has a commercial-use
        // license (amh_amh publishes none), so Amharic falls back to WEB.
    ]

    /// Resolve a language code (possibly with a region tag like `pt-BR` or
    /// `zh-Hans`) to the right bundled id. Tries exact match first, then
    /// falls back to the base language ("pt" → first "pt-*" entry). Returns
    /// nil for unknown locales so callers can route to the legacy WEB path.
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
}
