import Foundation

/// Single source of truth for which Bible texts Bible+ is legally allowed to
/// display, quote, search, or hand to the AI companion.
///
/// Why this exists: Bible+ is a paid subscription app, so every translation
/// it shows is "commercial use". Most modern translations (NIV, ESV, NLT,
/// NASB, NKJV, MSG, RVR1960, NVI, …) are copyrighted and require a publisher
/// license; many open translations on eBible.org / helloao are licensed
/// CC BY-NC (non-commercial) or CC BY-ND (no derivatives), which a paid app
/// with an AI that excerpts and paraphrases Scripture cannot satisfy.
///
/// Rule: a translation is allowed only if it is public domain, or its license
/// explicitly allows BOTH commercial use AND derivatives. Unknown = denied.
enum TranslationLicensePolicy {

    // MARK: - Hand-vetted translations

    private static let publicDomain = TranslationRef.License(
        attribution: "not-required", commercialUse: "allowed", derivatives: "allowed", publicDomain: true
    )
    private static let ccBySA = TranslationRef.License(
        attribution: "required", commercialUse: "allowed", derivatives: "allowed", publicDomain: false
    )

    /// Licenses for translations the app references by ID before the helloao
    /// catalog has loaded (featured English refs + per-language defaults).
    /// Verified against helloao's manifest on 2026-11-13. Re-verify whenever
    /// an ID is added here.
    static let knownLicenses: [String: TranslationRef.License] = [
        // Featured English (public domain)
        "BSB": publicDomain, "eng_asv": publicDomain, "eng_ylt": publicDomain, "eng_dra": publicDomain,
        // Language defaults — public domain
        "spa_r09": publicDomain, "fra_lsg": publicDomain, "deu_l12": publicDomain,
        "ita_riv": publicDomain, "rus_syn": publicDomain, "cmn_cu1": publicDomain,
        "cmn_cuv": publicDomain, "kor_old": publicDomain, "jpn_kou": publicDomain,
        // Language defaults — CC BY-SA (attribution required)
        "por_blj": ccBySA, "pol_bib": ccBySA, "ind_tsi": ccBySA,
        "tgl_ulb": ccBySA, "swh_bib": ccBySA,
    ]

    /// Translations previously offered that are NOT licensed for commercial
    /// use. Any stored preference pointing at one is migrated away on launch.
    static let knownRestrictedRefIDs: Set<String> = [
        "ind_ayt",   // Indonesian AYT — CC BY-NC (non-commercial)
        "pol_ubg",   // Polish UBG — CC BY-ND (no derivatives)
        "amh_amh",   // Amharic NT — no license information
    ]

    // MARK: - Catalog-backed allowlist

    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var refs: [String: TranslationRef] = [:]
    }
    private static let storage = Storage()

    /// Called by `TranslationCatalog` whenever its (already filtered) list
    /// changes, so non-main-actor code can check refs synchronously.
    static func updateCatalog(_ refs: [TranslationRef]) {
        let map = Dictionary(refs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        storage.lock.lock()
        storage.refs = map
        storage.lock.unlock()
    }

    static func catalogRef(id: String) -> TranslationRef? {
        storage.lock.lock(); defer { storage.lock.unlock() }
        return storage.refs[id]
    }

    // MARK: - Queries

    /// Whether a translation ID may be loaded and shown.
    static func isAllowed(refID: String) -> Bool {
        if refID.hasPrefix(TranslationRef.bundledPrefix) { return true }
        if knownRestrictedRefIDs.contains(refID) { return false }
        if let known = knownLicenses[refID] { return known.permitsCommercialAppUse }
        return catalogRef(id: refID)?.isLicensedForCommercialUse ?? false
    }

    /// Attribution line required by the translation's license, or nil when
    /// none is required (public domain).
    static func attribution(for refID: String) -> String? {
        if refID.hasPrefix(TranslationRef.bundledPrefix) { return nil }
        let ref = catalogRef(id: refID)
        let license = knownLicenses[refID] ?? ref?.license
        guard license?.requiresAttribution ?? true else { return nil }
        let name = ref?.englishName ?? refID
        let source = ref?.licenseUrl ?? "https://ebible.org"
        return String(localized: "Scripture text: \(name). Licensed under Creative Commons Attribution-ShareAlike. Source: \(source)")
    }
}
