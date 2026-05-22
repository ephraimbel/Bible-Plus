import Foundation
import SwiftUI
import ObjectiveC.runtime

/// Single source of truth for the app's active language. Persists the
/// selection to `UserDefaults` (mirrored to `UserProfile` via SettingsViewModel
/// so it survives reinstalls through iCloud) and, on change, flips
/// `Bundle.main` over to the selected `.lproj` so every `Text("…")` in SwiftUI
/// resolves against the new strings without an app restart.
///
/// Why an `@Observable` service instead of plain UserDefaults: SwiftUI views
/// need a *signal* to re-render. Mutating `currentCode` bumps the observation
/// and — paired with `.environment(\.locale, …)` at the root — forces every
/// view that reads `LocalizedStringKey` to re-resolve.
@MainActor
@Observable
final class LocalizationService {
    static let shared = LocalizationService()

    private static let defaultsKey = "io.bibleplus.selectedLanguageCode"
    private static let hasInitializedKey = "io.bibleplus.languageInitialized"
    /// iOS system key that drives the Bundle's preferred-localizations search.
    /// We keep this in sync with our custom key so iOS itself loads the right
    /// `.lproj` — our Bundle swizzle alone isn't enough if iOS has already
    /// decided at app launch (before the swizzle installs) which localization
    /// to use.
    private static let appleLanguagesKey = "AppleLanguages"

    /// Current selection. `nil` means "follow the system" — we map that to
    /// `SupportedLanguage.system` in UI. Setting this value persists and
    /// reapplies the bundle override.
    private(set) var currentCode: String?

    private init() {
        // First-launch policy: lock to English regardless of device locale.
        // Without this, a Spanish-phone user would see Spanish strings
        // immediately on first launch — before they've had a chance to pick,
        // and partial translations look worse than clean English. We also
        // write `AppleLanguages = ["en"]` so iOS itself selects English when
        // resolving `Bundle.main.preferredLocalizations`. The Bundle swizzle
        // alone doesn't suffice because iOS decides the initial language
        // before our @Observable service even initializes.
        let hasInitialized = UserDefaults.standard.bool(forKey: Self.hasInitializedKey)
        if !hasInitialized {
            UserDefaults.standard.set("en", forKey: Self.defaultsKey)
            UserDefaults.standard.set(["en"], forKey: Self.appleLanguagesKey)
            UserDefaults.standard.set(true, forKey: Self.hasInitializedKey)
            self.currentCode = "en"
        } else {
            self.currentCode = UserDefaults.standard.string(forKey: Self.defaultsKey)
            // On every relaunch, keep `AppleLanguages` in sync with our
            // stored code. Covers users who launched before this fix landed,
            // and prevents iOS from drifting back to device locale if its
            // own preferences were edited out-of-band.
            if let code = self.currentCode {
                let appleValue: [String] = {
                    if code.contains("-") {
                        let base = String(code.prefix { $0 != "-" })
                        return [code, base]
                    }
                    return [code]
                }()
                UserDefaults.standard.set(appleValue, forKey: Self.appleLanguagesKey)
            }
        }
        // Apply on startup before any SwiftUI view reads a localized string.
        // Safe to call even with `nil` — that path just clears the override.
        Bundle.setLanguage(self.currentCode)
    }

    /// Eager bootstrap — call from `BiblePlusApp.init()` so the first-launch
    /// English lock lands in UserDefaults *before* iOS resolves any Bundle
    /// localization. Otherwise the splash and first onboarding screen can
    /// render in the device locale (e.g. Spanish) before the @State-owned
    /// `LocalizationService.shared` gets instantiated.
    static func bootstrap() {
        _ = LocalizationService.shared
    }

    /// The concrete `SupportedLanguage` in effect. Falls back to system, which
    /// itself falls back to the first preferred language iOS can match against
    /// the bundles we ship.
    var current: SupportedLanguage {
        guard let code = currentCode,
              let lang = SupportedLanguage.language(for: code) else {
            return SupportedLanguage.system
        }
        return lang
    }

    /// The language code we should use for *locale-dependent defaults* —
    /// Bible translation picking, TTS voice resolution, AI directives, etc.
    /// When the user explicitly picked a language, that's the answer. On
    /// "system", we look up the device's preferred languages and pick the
    /// first one that maps to a language we support — so a Spanish-speaking
    /// device without a manual pick still lands on Reina-Valera and Mónica.
    var effectiveLanguageCode: String {
        if let code = currentCode { return code }
        let systemCandidates = Locale.preferredLanguages.map { raw -> String in
            // Locale.preferredLanguages returns BCP-47 tags ("es-US",
            // "zh-Hans-CN"). Normalize to what `SupportedLanguage` uses.
            if raw.hasPrefix("zh-Hans") { return "zh-Hans" }
            if raw.hasPrefix("zh-Hant") { return "zh-Hant" }
            if raw.hasPrefix("pt-BR") { return "pt-BR" }
            if raw.hasPrefix("pt") { return "pt-BR" }
            return String(raw.prefix { $0 != "-" })
        }
        for candidate in systemCandidates where SupportedLanguage.language(for: candidate) != nil {
            return candidate
        }
        return "en"
    }

    /// The `Locale` SwiftUI should render with. For system, we return
    /// `Locale.current` so date/number formatting follows the device; for an
    /// override we build a Locale from the selected code so `Text(date, …)`
    /// formatters stay consistent with UI strings.
    var locale: Locale {
        guard let code = currentCode else { return Locale.current }
        return Locale(identifier: code)
    }

    var layoutDirection: LayoutDirection {
        current.isRTL ? .rightToLeft : .leftToRight
    }

    /// Apply a new language selection. Pass `nil` (or `SupportedLanguage.system`)
    /// to clear the override. `languageDidChange` posts so any non-SwiftUI
    /// subsystem (e.g. ContentSeeder caches, notification body generators) can
    /// refresh too.
    func setLanguage(_ language: SupportedLanguage?) {
        let code: String? = {
            guard let language, language.code != SupportedLanguage.system.code else { return nil }
            return language.code
        }()
        guard code != currentCode else { return }
        currentCode = code
        if let code {
            UserDefaults.standard.set(code, forKey: Self.defaultsKey)
            // Keep iOS in sync so a relaunch lands on the same language
            // without waiting for the Bundle swizzle. For sub-tagged codes
            // like `pt-BR` we pass the tag itself plus the base as a fallback.
            let appleValue: [String] = {
                if code.contains("-") {
                    let base = String(code.prefix { $0 != "-" })
                    return [code, base]
                }
                return [code]
            }()
            UserDefaults.standard.set(appleValue, forKey: Self.appleLanguagesKey)
        } else {
            // "System" pick — clear both keys so iOS falls back to the
            // device's preferred languages on the next relaunch.
            UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
            UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
        }
        Bundle.setLanguage(code)
        NotificationCenter.default.post(name: .bpLanguageDidChange, object: nil)
    }
}

extension Notification.Name {
    static let bpLanguageDidChange = Notification.Name("io.bibleplus.languageDidChange")
}

// MARK: - Nonisolated accessor

extension LocalizationService {
    /// Nonisolated read of the currently-selected language code. Backed by the
    /// same `UserDefaults` key the main-actor service writes to, so callers
    /// from background tasks (AIService system-prompt builder, notification
    /// scheduler, etc.) can check the language without hopping to the main
    /// actor. Returns `nil` when the user is on "follow system".
    nonisolated static func currentLanguageCode() -> String? {
        UserDefaults.standard.string(forKey: "io.bibleplus.selectedLanguageCode")
    }

    /// Nonisolated counterpart of `effectiveLanguageCode`. Falls back to the
    /// device's preferred languages when the user is on "follow system" so
    /// background services (notification scheduler, audio intro speaker,
    /// BibleReader default picker) land on the right language without a
    /// main-actor hop.
    nonisolated static func effectiveLanguageCode() -> String {
        if let code = currentLanguageCode() { return code }
        for raw in Locale.preferredLanguages {
            let candidate: String
            if raw.hasPrefix("zh-Hans") { candidate = "zh-Hans" }
            else if raw.hasPrefix("zh-Hant") { candidate = "zh-Hant" }
            else if raw.hasPrefix("pt-BR") { candidate = "pt-BR" }
            else if raw.hasPrefix("pt") { candidate = "pt-BR" }
            else { candidate = String(raw.prefix { $0 != "-" }) }
            if SupportedLanguage.all.contains(where: { $0.code == candidate }) {
                return candidate
            }
        }
        return "en"
    }

    /// Human-readable English name for whatever `currentLanguageCode()`
    /// returns, or "English" as the fallback. Nonisolated so AIService can
    /// inject it into the system prompt from any context.
    nonisolated static func currentLanguageEnglishName() -> String {
        guard let code = currentLanguageCode(),
              let lang = SupportedLanguage.all.first(where: { $0.code == code })
        else { return "English" }
        return lang.englishName
    }
}

// MARK: - Bundle override
//
// Swizzle `Bundle.main` so `localizedString(forKey:value:table:)` routes
// through the selected `.lproj`. This is the standard trick for in-app
// language switching without a relaunch — SwiftUI's `LocalizedStringKey`
// ultimately calls through to this method, and `NSLocalizedString` does too.

private final class BPLocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let override = objc_getAssociatedObject(self, &Bundle.bpLanguageBundleKey) as? Bundle {
            return override.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    fileprivate static var bpLanguageBundleKey: UInt8 = 0

    /// One-time swap of `Bundle.main`'s class so our `localizedString` override
    /// is installed. Guarded by `swizzledOnce` so repeated calls are cheap.
    private static let swizzledOnce: Void = {
        object_setClass(Bundle.main, BPLocalizedBundle.self)
    }()

    /// Routes future string lookups through the `.lproj` matching `code`. Pass
    /// `nil` to clear the override (lookups fall back to the system default).
    /// Unknown codes also clear the override rather than leaving the app with
    /// a half-broken UI.
    static func setLanguage(_ code: String?) {
        _ = swizzledOnce

        let targetBundle: Bundle? = {
            guard let code else { return nil }
            // Try exact match first (e.g. "pt-BR"), then the language-only
            // variant ("pt") so fine-grained codes still land on a bundle
            // when only the base language is shipped.
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            let base = String(code.prefix { $0 != "-" })
            if base != code,
               let path = Bundle.main.path(forResource: base, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            return nil
        }()

        objc_setAssociatedObject(Bundle.main, &bpLanguageBundleKey, targetBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - SwiftUI convenience

// We don't expose the service through an EnvironmentKey — `@Observable`
// services are idiomatically passed via `.environment(service)` and read
// with `@Environment(LocalizationService.self)`, which avoids the
// main-actor-isolated-default-value pitfall with `EnvironmentKey`.
