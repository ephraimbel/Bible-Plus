import Foundation

/// Locates a JSON resource, preferring a per-locale variant when available.
///
/// Our seed-content pipeline produces per-language files at build time
/// (`feed-content.es.json`, `feed-content.pt-BR.json`, etc.) alongside the
/// English source (`feed-content.json`). This helper wires the loading
/// services so they pick the variant matching the user's chosen language —
/// with automatic fallback to the English source when no variant exists.
///
/// Fallback order for user on `pt-BR`:
///   1. `feed-content.pt-BR.json`  (exact region match)
///   2. `feed-content.pt.json`     (base-language fallback)
///   3. `feed-content.json`        (English source — always present)
enum LocalizedContentLoader {
    /// Main-bundle URL for the best available variant of `baseName`. Always
    /// returns a non-nil URL if the English source exists in the bundle.
    static func url(forResource baseName: String, extension ext: String = "json") -> URL? {
        let code = LocalizationService.effectiveLanguageCode()
        // Skip locale lookup for English — the source file is the canonical
        // English copy, so there's no separate `feed-content.en.json`.
        if code != "en" {
            // Exact match (e.g. "pt-BR", "zh-Hans")
            if let url = Bundle.main.url(forResource: "\(baseName).\(code)", withExtension: ext) {
                return url
            }
            // Base-language fallback (pt-BR → pt, zh-Hans → zh)
            if code.contains("-") {
                let base = String(code.prefix { $0 != "-" })
                if let url = Bundle.main.url(forResource: "\(baseName).\(base)", withExtension: ext) {
                    return url
                }
            }
        }
        // English source — always the final fallback.
        return Bundle.main.url(forResource: baseName, withExtension: ext)
    }
}
