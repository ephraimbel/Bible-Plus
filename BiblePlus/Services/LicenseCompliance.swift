import Foundation
import SwiftData

/// Launch-time cleanup that brings existing installs into licensing
/// compliance. Idempotent and cheap — runs on every launch.
///
/// - Users who had picked a copyrighted translation (NIV/ESV/NLT/NASB/MSG/
///   NKJV, previously streamed from bolls.life) are moved to the World
///   English Bible, the closest modern public-domain equivalent.
/// - Users whose stored helloao translation is non-commercial / no-derivatives
///   / unlicensed fall back to their language default (or bundled KJV).
/// - All Bible text previously downloaded from third-party Bible APIs
///   (bolls.life, bible.helloao.org) is deleted — the app now ships every
///   translation it offers and makes no Bible API calls.
enum LicenseCompliance {
    @MainActor
    static func migrate(modelContext: ModelContext) {
        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first {
            var changed = false
            if !profile.preferredTranslation.isLicensedForUse {
                profile.preferredTranslation = profile.preferredTranslation.licensed
                changed = true
            }
            if let refID = profile.preferredTranslationRefID,
               !TranslationLicensePolicy.isAllowed(refID: refID) {
                profile.preferredTranslationRefID = nil
                changed = true
            }
            if changed { modelContext.safeSave() }
        }

        BibleRepository.shared.purgeUnlicensedCaches()
    }
}
