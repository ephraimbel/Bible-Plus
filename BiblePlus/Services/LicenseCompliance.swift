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
/// - Bible text cached on disk from unlicensed sources is deleted.
enum LicenseCompliance {
    @MainActor
    static func migrate(modelContext: ModelContext) {
        // Load the (license-filtered) catalog from disk first so the policy
        // can recognise every permitted translation before we judge stored IDs.
        _ = TranslationCatalog.shared

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
