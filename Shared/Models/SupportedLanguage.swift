import Foundation

/// A language the app ships translations for. The `code` is the BCP-47 / ISO
/// identifier that matches the `.lproj` directories Xcode generates from the
/// String Catalog. `nativeName` is what speakers of that language call it
/// (shown as the primary label in the picker); `englishName` is the fallback
/// label for users who can't read the native script. `flag` is a country-flag
/// emoji that works as a visual anchor — not a political statement, just a
/// way to make the long list scannable. `isRTL` flips layout direction.
struct SupportedLanguage: Identifiable, Hashable, Sendable {
    let code: String
    let nativeName: String
    let englishName: String
    let flag: String
    let isRTL: Bool

    var id: String { code }

    /// Synthetic entry meaning "follow the system language". When selected,
    /// `LocalizationService` clears the bundle override and lets iOS fall
    /// back to `Locale.current`.
    static let system = SupportedLanguage(
        code: "system",
        nativeName: "System",
        englishName: "System",
        flag: "🌐",
        isRTL: false
    )

    /// The catalog of languages we ship translations for. Order here is what
    /// the picker renders in. "System" always floats to the top.
    static let all: [SupportedLanguage] = [
        SupportedLanguage(code: "en",      nativeName: "English",              englishName: "English",              flag: "🇺🇸", isRTL: false),
        SupportedLanguage(code: "es",      nativeName: "Español",              englishName: "Spanish",              flag: "🇪🇸", isRTL: false),
        SupportedLanguage(code: "pt-BR",   nativeName: "Português (Brasil)",   englishName: "Portuguese (Brazil)",  flag: "🇧🇷", isRTL: false),
        SupportedLanguage(code: "pt-PT",   nativeName: "Português (Portugal)", englishName: "Portuguese (Portugal)",flag: "🇵🇹", isRTL: false),
        SupportedLanguage(code: "fr",      nativeName: "Français",             englishName: "French",               flag: "🇫🇷", isRTL: false),
        SupportedLanguage(code: "de",      nativeName: "Deutsch",              englishName: "German",               flag: "🇩🇪", isRTL: false),
        SupportedLanguage(code: "it",      nativeName: "Italiano",             englishName: "Italian",              flag: "🇮🇹", isRTL: false),
        SupportedLanguage(code: "nl",      nativeName: "Nederlands",           englishName: "Dutch",                flag: "🇳🇱", isRTL: false),
        SupportedLanguage(code: "sv",      nativeName: "Svenska",              englishName: "Swedish",              flag: "🇸🇪", isRTL: false),
        SupportedLanguage(code: "no",      nativeName: "Norsk",                englishName: "Norwegian",            flag: "🇳🇴", isRTL: false),
        SupportedLanguage(code: "da",      nativeName: "Dansk",                englishName: "Danish",               flag: "🇩🇰", isRTL: false),
        SupportedLanguage(code: "fi",      nativeName: "Suomi",                englishName: "Finnish",              flag: "🇫🇮", isRTL: false),
        SupportedLanguage(code: "pl",      nativeName: "Polski",               englishName: "Polish",               flag: "🇵🇱", isRTL: false),
        SupportedLanguage(code: "cs",      nativeName: "Čeština",              englishName: "Czech",                flag: "🇨🇿", isRTL: false),
        SupportedLanguage(code: "hu",      nativeName: "Magyar",               englishName: "Hungarian",            flag: "🇭🇺", isRTL: false),
        SupportedLanguage(code: "ro",      nativeName: "Română",               englishName: "Romanian",             flag: "🇷🇴", isRTL: false),
        SupportedLanguage(code: "el",      nativeName: "Ελληνικά",             englishName: "Greek",                flag: "🇬🇷", isRTL: false),
        SupportedLanguage(code: "tr",      nativeName: "Türkçe",               englishName: "Turkish",              flag: "🇹🇷", isRTL: false),
        SupportedLanguage(code: "ru",      nativeName: "Русский",              englishName: "Russian",              flag: "🇷🇺", isRTL: false),
        SupportedLanguage(code: "uk",      nativeName: "Українська",           englishName: "Ukrainian",            flag: "🇺🇦", isRTL: false),
        SupportedLanguage(code: "zh-Hans", nativeName: "简体中文",              englishName: "Chinese (Simplified)", flag: "🇨🇳", isRTL: false),
        SupportedLanguage(code: "zh-Hant", nativeName: "繁體中文",              englishName: "Chinese (Traditional)",flag: "🇹🇼", isRTL: false),
        SupportedLanguage(code: "ja",      nativeName: "日本語",                englishName: "Japanese",             flag: "🇯🇵", isRTL: false),
        SupportedLanguage(code: "ko",      nativeName: "한국어",                englishName: "Korean",               flag: "🇰🇷", isRTL: false),
        SupportedLanguage(code: "hi",      nativeName: "हिन्दी",                 englishName: "Hindi",                flag: "🇮🇳", isRTL: false),
        SupportedLanguage(code: "bn",      nativeName: "বাংলা",                  englishName: "Bengali",              flag: "🇧🇩", isRTL: false),
        SupportedLanguage(code: "ur",      nativeName: "اردو",                  englishName: "Urdu",                 flag: "🇵🇰", isRTL: true),
        SupportedLanguage(code: "ar",      nativeName: "العربية",               englishName: "Arabic",               flag: "🇸🇦", isRTL: true),
        SupportedLanguage(code: "he",      nativeName: "עברית",                englishName: "Hebrew",               flag: "🇮🇱", isRTL: true),
        SupportedLanguage(code: "fa",      nativeName: "فارسی",                englishName: "Persian",              flag: "🇮🇷", isRTL: true),
        SupportedLanguage(code: "id",      nativeName: "Bahasa Indonesia",     englishName: "Indonesian",           flag: "🇮🇩", isRTL: false),
        SupportedLanguage(code: "ms",      nativeName: "Bahasa Melayu",        englishName: "Malay",                flag: "🇲🇾", isRTL: false),
        SupportedLanguage(code: "th",      nativeName: "ไทย",                   englishName: "Thai",                 flag: "🇹🇭", isRTL: false),
        SupportedLanguage(code: "vi",      nativeName: "Tiếng Việt",           englishName: "Vietnamese",           flag: "🇻🇳", isRTL: false),
        SupportedLanguage(code: "tl",      nativeName: "Filipino",             englishName: "Filipino",             flag: "🇵🇭", isRTL: false),
        SupportedLanguage(code: "sw",      nativeName: "Kiswahili",            englishName: "Swahili",              flag: "🇰🇪", isRTL: false),
        SupportedLanguage(code: "am",      nativeName: "አማርኛ",                 englishName: "Amharic",              flag: "🇪🇹", isRTL: false),
        SupportedLanguage(code: "af",      nativeName: "Afrikaans",            englishName: "Afrikaans",            flag: "🇿🇦", isRTL: false),
        SupportedLanguage(code: "yo",      nativeName: "Yorùbá",               englishName: "Yoruba",               flag: "🇳🇬", isRTL: false),
        SupportedLanguage(code: "ha",      nativeName: "Hausa",                englishName: "Hausa",                flag: "🇳🇬", isRTL: false)
    ]

    static func language(for code: String) -> SupportedLanguage? {
        all.first { $0.code == code }
    }

    /// Substring-match against native name, English name, or code. Case- and
    /// diacritic-insensitive so "espanol" finds "Español".
    static func matches(query: String) -> [SupportedLanguage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let needle = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return all.filter { lang in
            let haystacks = [lang.nativeName, lang.englishName, lang.code]
            return haystacks.contains { h in
                h.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle)
            }
        }
    }
}
