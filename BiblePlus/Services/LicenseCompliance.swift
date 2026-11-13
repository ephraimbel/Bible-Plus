import Foundation
import SwiftData
import CryptoKit

/// Launch-time cleanup that brings existing installs into licensing
/// compliance. Idempotent and cheap — runs on every launch.
///
/// - Users who had picked a copyrighted translation (NIV/ESV/NLT/NASB/MSG/
///   NKJV, previously streamed from bolls.life) are moved to the World
///   English Bible, the closest modern public-domain equivalent.
/// - Users whose stored helloao translation is non-commercial / no-derivatives
///   / unlicensed fall back to their language default (or bundled WEB).
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

        // Keep saved notes/highlights while replacing text from retired editions.
        let allowedBadges = Set(["WEB"] + TranslationLicensePolicy.bundled.values.map(\.shortName))
        if let saved = try? modelContext.fetch(FetchDescriptor<SavedBibleVerse>()) {
            for verse in saved where !allowedBadges.contains(verse.translation) {
                if let replacement = BibleRepository.shared.versesSync(
                    book: verse.bookID, chapter: verse.chapter, translation: .web
                ).first(where: { $0.number == verse.verseNumber }) {
                    verse.text = replacement.text
                    verse.translation = "WEB"
                }
            }
        }

        // Earlier feed bundles contained publisher text and translated paraphrases.
        // Match hashes, never ship the retired wording in the migration resource.
        struct Replacement: Decodable { let text: String; let reference: String }
        if let url = Bundle.main.url(forResource: "licensed-verse-replacements", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let replacements = try? JSONDecoder().decode([String: Replacement].self, from: data),
           let items = try? modelContext.fetch(FetchDescriptor<PrayerContent>()) {
            for item in items where item.verseReference != nil {
                let oldText = item.verseText ?? item.templateText
                let hash = SHA256.hash(data: Data(oldText.utf8)).map { String(format: "%02x", $0) }.joined()
                if let replacement = replacements[hash] {
                    item.verseText = replacement.text
                    item.templateText = replacement.text
                    item.verseReference = replacement.reference
                }
            }
        }
        modelContext.safeSave()
    }
}
