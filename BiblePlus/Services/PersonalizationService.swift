import Foundation
import SwiftData

@Observable
final class PersonalizationService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Returns the singleton user profile, creating one if needed
    func getOrCreateProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    func updateName(_ name: String) {
        let profile = getOrCreateProfile()
        profile.firstName = name
        profile.updatedAt = Date()
        save()
    }

    func updateFaithLevel(_ level: FaithLevel) {
        let profile = getOrCreateProfile()
        profile.faithLevel = level
        profile.updatedAt = Date()
        save()
    }

    func updateLifeSeasons(_ seasons: [LifeSeason]) {
        let profile = getOrCreateProfile()
        profile.lifeSeasons = seasons
        profile.updatedAt = Date()
        save()
    }

    func updateBurdens(_ burdens: [Burden]) {
        let profile = getOrCreateProfile()
        profile.currentBurdens = burdens
        profile.updatedAt = Date()
        save()
    }

    func updateTranslation(_ translation: BibleTranslation) {
        let profile = getOrCreateProfile()
        profile.preferredTranslation = translation
        profile.updatedAt = Date()
        save()
    }

    func updatePrayerTimes(_ times: [PrayerTimeSlot]) {
        let profile = getOrCreateProfile()
        profile.prayerTimes = times
        profile.updatedAt = Date()
        save()
    }

    func updateTheme(_ themeID: String) {
        let profile = getOrCreateProfile()
        profile.selectedThemeID = themeID
        profile.updatedAt = Date()
        save()
    }

    func updateColorMode(_ mode: ColorMode) {
        let profile = getOrCreateProfile()
        profile.colorMode = mode
        profile.updatedAt = Date()
        save()
    }

    func updateProStatus(_ isPro: Bool) {
        let profile = getOrCreateProfile()
        profile.isPro = isPro
        profile.updatedAt = Date()
        save()
    }

    func updateSoundscape(_ soundscapeID: String) {
        let profile = getOrCreateProfile()
        profile.selectedSoundscapeID = soundscapeID
        profile.updatedAt = Date()
        save()
    }

    func updateSanctuaryBackground(_ backgroundID: String) {
        let profile = getOrCreateProfile()
        profile.selectedBackgroundID = backgroundID
        profile.updatedAt = Date()
        save()
    }

    func completeOnboarding() {
        let profile = getOrCreateProfile()
        profile.hasCompletedOnboarding = true
        profile.updatedAt = Date()
        save()
    }

    func save() {
        try? modelContext.save()
    }
}
