import Foundation

/// Explicit user permission to send personal data to our third-party AI
/// provider (OpenAI, via our Supabase edge function).
///
/// App Store Guideline 5.1.2(i): apps must clearly disclose where personal
/// data will be shared — including with third-party AI — and obtain explicit
/// permission before doing so. Every AI network call in `AIService` checks
/// `isGranted` and throws `AIError.consentRequired` when it is false.
enum AIConsent {
    private static let key = "io.bibleplus.aiDataSharingConsent.v1"

    static var isGranted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func grant() {
        UserDefaults.standard.set(true, forKey: key)
        Analytics.track(.aiConsentGranted)
    }

    static func revoke() {
        UserDefaults.standard.set(false, forKey: key)
    }
}
