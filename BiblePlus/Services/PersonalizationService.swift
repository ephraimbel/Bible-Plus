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
        modelContext.safeSave()
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

    // MARK: - Extended Onboarding Profile

    func updateGender(_ gender: Gender) {
        let profile = getOrCreateProfile()
        profile.gender = gender
        profile.updatedAt = Date()
        save()
    }

    func updateAge(_ age: Int) {
        let profile = getOrCreateProfile()
        profile.age = age
        profile.updatedAt = Date()
        save()
    }

    func updateClosenessRating(_ rating: Int) {
        let profile = getOrCreateProfile()
        profile.closenessRating = rating
        profile.updatedAt = Date()
        save()
    }

    func updateGrowthBlockers(_ blockers: [GrowthBlocker]) {
        let profile = getOrCreateProfile()
        profile.growthBlockers = blockers
        profile.updatedAt = Date()
        save()
    }

    func updateAppGoals(_ goals: [AppGoal]) {
        let profile = getOrCreateProfile()
        profile.appGoals = goals
        profile.updatedAt = Date()
        save()
    }

    func updateTimeCommitment(_ commitment: TimeCommitment) {
        let profile = getOrCreateProfile()
        profile.timeCommitment = commitment
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

        // Only update widget image if no widget-specific background is set
        // WidgetBackgroundService handles reloadAllTimelines() after the image is ready
        let effectiveWidgetID = profile.widgetSelectedBackgroundID ?? backgroundID
        if let background = SanctuaryBackground.background(for: effectiveWidgetID) {
            WidgetBackgroundService.updateWidgetBackground(for: background)
        }
    }

    func updateWidgetBackground(_ backgroundID: String?) {
        let profile = getOrCreateProfile()
        profile.widgetSelectedBackgroundID = backgroundID
        profile.updatedAt = Date()
        save()

        // Determine which background the widget should use
        // WidgetBackgroundService handles reloadAllTimelines() after the image is ready
        let effectiveID = backgroundID ?? profile.selectedBackgroundID
        if let background = SanctuaryBackground.background(for: effectiveID) {
            WidgetBackgroundService.updateWidgetBackground(for: background)
        }
    }

    func updateProfileImage(_ data: Data?) {
        let profile = getOrCreateProfile()
        profile.profileImageData = data
        profile.updatedAt = Date()
        save()
    }

    func completeOnboarding() {
        let profile = getOrCreateProfile()
        profile.hasCompletedOnboarding = true
        profile.updatedAt = Date()
        save()
        Analytics.track(.onboardingCompleted)
    }

    func save() {
        modelContext.safeSave()
    }
}
