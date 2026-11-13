import Foundation

/// A runtime-resolved reference to a Bible translation, sourced from
/// bible.helloao.org's `available_translations.json`. Covers the full long
/// tail of 1000+ translations across 500+ languages — the legacy
/// `BibleTranslation` enum stays for bundled KJV/WEB and John 3:16 previews,
/// but every user-selectable translation in Settings flows through here.
///
/// Book IDs in helloao match the app's existing USFM abbreviations
/// (GEN, EXO, …, MAT, …, REV), so no book-number remapping is needed when
/// fetching a chapter.
struct TranslationRef: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let shortName: String
    let englishName: String
    /// Native-script name of the translation, e.g. "መጽሐፍ ቅዱስ" or "Reina-Valera 1960".
    let nativeName: String
    /// ISO 639 code from helloao — usually 3-letter ("eng", "amh", "spa", "arb").
    let languageCode: String
    let languageNameNative: String
    let languageNameEnglish: String
    let textDirection: TextDirection
    let numberOfBooks: Int
    let totalNumberOfChapters: Int
    let totalNumberOfVerses: Int
    let completeApiPath: String
    let booksApiPath: String
    let licenseUrl: String?
    let website: String?
    /// Structured license terms from helloao's manifest. `nil` for refs we
    /// construct by hand (bundled + vetted public-domain featured refs).
    var license: License? = nil

    /// Machine-readable license terms published per-translation in
    /// helloao's `available_translations.json`.
    struct License: Codable, Hashable, Sendable {
        let attribution: String?     // "required" | "not-required"
        let commercialUse: String?   // "allowed" | "not-allowed"
        let derivatives: String?     // "allowed" | "not-allowed"
        let publicDomain: Bool?
        var copyleft: Bool? = nil

        /// Bible+ is a paid subscription app, so any translation we show
        /// must allow commercial use. We also require derivatives to be
        /// allowed because the AI companion quotes, excerpts, paraphrases
        /// and explains the text, and features like Memorize alter it.
        var permitsCommercialAppUse: Bool {
            commercialUse == "allowed" && derivatives == "allowed"
        }

        var requiresAttribution: Bool {
            publicDomain != true && attribution != "not-required"
        }
    }

    /// True when this translation may legally be used in Bible+.
    /// Bundled refs and refs in `TranslationLicensePolicy.knownLicenses` use vetted terms; catalog refs must
    /// carry a license that permits commercial use and derivatives. Refs with
    /// no license info are rejected — unknown terms are treated as restricted.
    var isLicensedForCommercialUse: Bool {
        TranslationLicensePolicy.isAllowed(refID: id)
    }

    enum TextDirection: String, Codable, Sendable {
        case ltr
        case rtl
    }

    enum Coverage: Sendable {
        case complete          // OT + NT (66 books) or larger (with deuterocanon)
        case oldTestamentOnly  // 39 books
        case newTestamentOnly  // 27 books
        case partial           // anything else — single book, portions

        var label: String {
            switch self {
            case .complete: String(localized: "Complete Bible")
            case .oldTestamentOnly: String(localized: "Old Testament only")
            case .newTestamentOnly: String(localized: "New Testament only")
            case .partial: String(localized: "Partial")
            }
        }
    }

    var coverage: Coverage {
        switch numberOfBooks {
        case 66...: .complete
        case 39: .oldTestamentOnly
        case 27: .newTestamentOnly
        default: .partial
        }
    }

    var isRightToLeft: Bool { textDirection == .rtl }
}

// MARK: - Decoding from helloao's available_translations.json

extension TranslationRef {
    /// Shape of each entry in `/api/available_translations.json`.
    struct HelloAOEntry: Decodable {
        let id: String
        let name: String
        let website: String?
        let licenseUrl: String?
        let shortName: String?
        let englishName: String
        let language: String
        let textDirection: String
        let availableFormats: [String]
        let listOfBooksApiLink: String
        let completeTranslationApiLink: String?
        let numberOfBooks: Int
        let totalNumberOfChapters: Int
        let totalNumberOfVerses: Int
        let languageName: String?
        let languageEnglishName: String?
        let license: License?
    }

    init(from entry: HelloAOEntry) {
        self.id = entry.id
        self.shortName = entry.shortName ?? entry.id
        self.englishName = entry.englishName
        self.nativeName = entry.name
        self.languageCode = entry.language
        self.languageNameNative = entry.languageName ?? entry.language
        self.languageNameEnglish = entry.languageEnglishName ?? entry.language
        self.textDirection = entry.textDirection.lowercased() == "rtl" ? .rtl : .ltr
        self.numberOfBooks = entry.numberOfBooks
        self.totalNumberOfChapters = entry.totalNumberOfChapters
        self.totalNumberOfVerses = entry.totalNumberOfVerses
        self.completeApiPath = entry.completeTranslationApiLink ?? entry.listOfBooksApiLink
        self.booksApiPath = entry.listOfBooksApiLink
        self.licenseUrl = entry.licenseUrl
        self.website = entry.website
        self.license = entry.license
    }
}

// MARK: - Bundled sentinel

extension TranslationRef {
    /// Sentinel prefix identifying refs that resolve to app-bundled JSON
    /// rather than a helloao download. Used by `BibleRepository` to pick the
    /// fast path (no network, no disk download).
    static let bundledPrefix = "bundled_"

    /// Decode-compatibility identifier only; excluded from the allowlist.
    static let bundledKJV = TranslationRef(
        id: bundledPrefix + "kjv",
        shortName: "KJV",
        englishName: "King James Version",
        nativeName: "King James Version",
        languageCode: "eng",
        languageNameNative: "English",
        languageNameEnglish: "English",
        textDirection: .ltr,
        numberOfBooks: 66,
        totalNumberOfChapters: 1189,
        totalNumberOfVerses: 31102,
        completeApiPath: "",
        booksApiPath: "",
        licenseUrl: nil,
        website: nil
    )

    static let bundledWEB = TranslationRef(
        id: bundledPrefix + "web",
        shortName: "WEB",
        englishName: "World English Bible",
        nativeName: "World English Bible",
        languageCode: "eng",
        languageNameNative: "English",
        languageNameEnglish: "English",
        textDirection: .ltr,
        numberOfBooks: 66,
        totalNumberOfChapters: 1189,
        totalNumberOfVerses: 31102,
        completeApiPath: "",
        booksApiPath: "",
        licenseUrl: nil,
        website: nil
    )

    var isBundled: Bool { id == Self.bundledWEB.id }

    /// Hand-vetted, public-domain English translations offered in the reader's
    /// translation picker alongside the bundled KJV/WEB. These replace the
    /// copyrighted NIV/ESV/NLT/NASB/MSG/NKJV that were removed. Every entry
    /// was verified as public domain in helloao's manifest on 2026-11-13.
    static let featuredEnglish: [TranslationRef] = [
        .publicDomainEnglish(id: "BSB", short: "BSB", name: "Berean Standard Bible"),
        .publicDomainEnglish(id: "eng_asv", short: "ASV", name: "American Standard Version (1901)"),
        .publicDomainEnglish(id: "eng_ylt", short: "YLT", name: "Young's Literal Translation"),
        .publicDomainEnglish(id: "eng_dra", short: "DRA", name: "Douay-Rheims 1899"),
    ]

    private static func publicDomainEnglish(id: String, short: String, name: String) -> TranslationRef {
        TranslationRef(
            id: id,
            shortName: short,
            englishName: name,
            nativeName: name,
            languageCode: "eng",
            languageNameNative: "English",
            languageNameEnglish: "English",
            textDirection: .ltr,
            numberOfBooks: 66,
            totalNumberOfChapters: 1189,
            totalNumberOfVerses: 31102,
            completeApiPath: "",
            booksApiPath: "",
            licenseUrl: nil,
            website: nil
        )
    }

    /// Bridge to the legacy enum for bundled refs. Returns nil for any
    /// helloao-sourced translation.
    var legacyBundled: BibleTranslation? {
        switch id {
        case Self.bundledKJV.id: .web
        case Self.bundledWEB.id: .web
        default: nil
        }
    }
}

// MARK: - Grouping helpers

extension Array where Element == TranslationRef {
    /// Groups translations by `languageEnglishName`, sorted alphabetically,
    /// with English pinned first. Within each language, translations are
    /// sorted by coverage (complete → NT → OT → partial) then short name.
    func groupedByLanguage() -> [(language: String, translations: [TranslationRef])] {
        let groups = Dictionary(grouping: self, by: \.languageNameEnglish)
        let sortedKeys = groups.keys.sorted { lhs, rhs in
            if lhs == "English" { return true }
            if rhs == "English" { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return sortedKeys.map { key in
            let sorted = (groups[key] ?? []).sorted { a, b in
                if a.coverage != b.coverage {
                    return a.coverage.sortOrder < b.coverage.sortOrder
                }
                return a.shortName.localizedCaseInsensitiveCompare(b.shortName) == .orderedAscending
            }
            return (language: key, translations: sorted)
        }
    }
}

private extension TranslationRef.Coverage {
    var sortOrder: Int {
        switch self {
        case .complete: 0
        case .newTestamentOnly: 1
        case .oldTestamentOnly: 2
        case .partial: 3
        }
    }
}
