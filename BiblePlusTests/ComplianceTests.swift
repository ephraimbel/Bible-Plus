import Foundation
import SwiftData
import Testing
@testable import Bible_Plus

@Suite("Compliance release", .serialized)
@MainActor
struct ComplianceTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: UserProfile.self, SavedBibleVerse.self, ActivityEvent.self, PrayerContent.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func allowlistRejectsUnknownAndRestrictedIDs() {
        for id in ["NIV", "ESV", "ind_ayt", "pol_ubg", "amh_amh", "bundled_niv", "unknown", "bundled_kjv"] {
            #expect(!TranslationLicensePolicy.isAllowed(refID: id), "Unexpected permission: \(id)")
        }
        #expect(BibleTranslation.available == [.web])
        for translation in BibleTranslation.allCases where !translation.isLicensedForUse {
            #expect(translation.licensed == .web)
        }
        for id in LanguageDefaultBible.defaults.values {
            #expect(TranslationLicensePolicy.isAllowed(refID: id))
        }
    }

    @Test func allEnglishTranslationsLoadGenesisAndJohnOffline() async throws {
        let repo = BibleRepository.shared
        for id in ["bundled_web", "BSB", "eng_asv", "eng_ylt", "eng_dra"] {
            let genesis = try await repo.verses(refID: id, book: "GEN", chapter: 1)
            let john = try await repo.verses(refID: id, book: "JHN", chapter: 3)
            #expect(genesis.count == 31, "Genesis missing: \(id)")
            #expect(john.contains { $0.number == 16 && !$0.text.isEmpty }, "John missing: \(id)")
        }
    }

    @Test func allBundledResourcesLoadAndHaveAttribution() async throws {
        for id in TranslationLicensePolicy.bundled.keys.sorted() {
            let verses = try await BibleRepository.shared.verses(refID: id, book: "JHN", chapter: 3)
            #expect(!verses.isEmpty, "Missing bundled text: \(id)")
        }
        #expect(BibleRepository.shared.localizedBookName(refID: "spa_r09", bookID: "GEN") == "Génesis")
        for id in ["por_blj", "ind_tsi", "tgl_ulb", "swh_ulb"] {
            #expect(TranslationLicensePolicy.attribution(for: id)?.contains("https://") == true)
        }
    }

    @Test func offlineSearchFindsVerseInWEB() {
        let repo = BibleRepository.shared
        for translation in BibleTranslation.available {
            let results = repo.searchBundled(query: "God", translation: translation)
            #expect(results.total > 0)
            #expect(!results.results.isEmpty)
        }
    }

    @Test func indonesianMissingBookReallyUsesWEBAfterWEBSelection() async throws {
        let container = try container()
        let context = container.mainContext
        let profile = UserProfile(preferredTranslation: .web, lastReadBookID: "PSA")
        profile.preferredTranslationRefID = "ind_tsi"
        context.insert(profile)
        try context.save()
        let vm = BibleReaderViewModel(modelContext: context)
        for _ in 0..<100 where vm.isLoading { try await Task.sleep(for: .milliseconds(20)) }
        #expect(!vm.isLoading)
        #expect(vm.isShowingOfflineFallback)
        #expect(vm.translationName == "WEB")
        let expected = BibleRepository.shared.versesSync(book: "PSA", chapter: 1, translation: .web)
        #expect(vm.verses.map(\.text) == expected.map(\.text))
        #expect(vm.translationAttribution == nil)
        vm.changeTranslationRef("BSB")
        for _ in 0..<100 where vm.isLoading { try await Task.sleep(for: .milliseconds(20)) }
        #expect(vm.translationName == "BSB")
        #expect(!vm.isShowingOfflineFallback)
        #expect(vm.translationAttribution == nil)
    }

    @Test func migrationPreservesUserDataAndRemovesOldCaches() throws {
        let container = try container()
        let context = container.mainContext
        let profile = UserProfile(firstName: "Compliance Test", preferredTranslation: .niv)
        profile.preferredTranslationRefID = "ind_ayt"
        context.insert(profile)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        for name in ["BibleCache", "TranslationCatalog"] {
            let path = base.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            try Data("legacy-cache-fixture".utf8).write(to: path.appendingPathComponent("fixture.json"))
        }
        LicenseCompliance.migrate(modelContext: context)
        #expect(profile.preferredTranslation == .web)
        #expect(profile.preferredTranslationRefID == nil)
        #expect(profile.firstName == "Compliance Test")
        for name in ["BibleCache", "TranslationCatalog"] {
            #expect(!FileManager.default.fileExists(atPath: base.appendingPathComponent(name).path))
        }
        LicenseCompliance.migrate(modelContext: context)
        #expect(profile.preferredTranslation == .web)
    }

    @Test func allAIEntrypointsRejectMissingConsent() async {
        AIConsent.revoke()
        #expect(!AIConsent.isGranted)
        do {
            try await AIService.streamCompletion(messages: [("user", "Consent test")]) { _ in Issue.record("Token before consent") }
            Issue.record("Streaming accepted missing consent")
        } catch AIError.consentRequired {} catch { Issue.record("Wrong error: \(error)") }
        do {
            _ = try await AIService.streamCompletionWithTools(messages: [], tools: []) { _ in Issue.record("Tool token before consent") }
            Issue.record("Tool streaming accepted missing consent")
        } catch AIError.consentRequired {} catch { Issue.record("Wrong error: \(error)") }
        do {
            _ = try await AIService.utilityCompletion(systemPrompt: "test", userPrompt: "test")
            Issue.record("Utility completion accepted missing consent")
        } catch AIError.consentRequired {} catch { Issue.record("Wrong error: \(error)") }
        AIConsent.grant()
        #expect(AIConsent.isGranted)
        AIConsent.revoke()
        #expect(!AIConsent.isGranted)
    }
}
