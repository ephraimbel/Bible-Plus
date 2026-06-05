import SwiftUI
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: - Navigation State
    var currentStep: Int = 0
    var navigationDirection: NavigationDirection = .forward
    let totalSteps: Int = 11

    enum NavigationDirection {
        case forward, backward
    }

    // MARK: - Screen Data
    var firstName: String = ""
    var selectedFaithLevel: FaithLevel? = nil
    var selectedLifeSeasons: Set<LifeSeason> = []
    var selectedBurdens: Set<Burden> = []
    var selectedTranslation: BibleTranslation = .kjv
    var selectedPrayerTimes: Set<PrayerTimeSlot> = []
    var selectedThemeID: String = "sunrise-mountains"
    var selectedBackgroundID: String = "warm-gold"

    // Extended onboarding interview
    var selectedGender: Gender? = nil
    var age: Int = 0                                   // exact age, 0 = unanswered
    var closenessRating: Int = 0                       // 1–5, 0 = unanswered
    var selectedGrowthBlockers: Set<GrowthBlocker> = []
    var selectedGoals: Set<AppGoal> = []
    var selectedTimeCommitment: TimeCommitment? = nil

    // MARK: - Services
    private let personalizationService: PersonalizationService
    private let modelContext: ModelContext
    let audioService: SoundscapeService
    let storeKitService: StoreKitService

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case 0: true                                                   // Welcome
        case 1: !firstName.trimmingCharacters(in: .whitespaces).isEmpty // Name
        case 2: selectedFaithLevel != nil                              // Faith
        case 3: !selectedLifeSeasons.isEmpty                           // Seasons
        case 4: !selectedBurdens.isEmpty                               // Burdens
        case 5: true                                                   // Translation
        case 6: true                                                   // DailyRhythm
        case 7: true                                                   // NotificationPermission
        case 8: true                                                   // Aesthetic
        case 9: true                                                   // Paywall
        case 10: true                                                  // WidgetSetup
        default: false
        }
    }

    // MARK: - Init

    init(modelContext: ModelContext, storeKitService: StoreKitService) {
        self.modelContext = modelContext
        self.personalizationService = PersonalizationService(modelContext: modelContext)
        self.audioService = SoundscapeService()
        self.storeKitService = storeKitService
    }

    // MARK: - Navigation

    func goNext() {
        guard canProceed, currentStep < totalSteps - 1 else { return }
        saveCurrentStep()
        navigationDirection = .forward
        withAnimation(BPAnimation.pageTransition) {
            currentStep += 1
        }
        HapticService.impact(.light)
    }

    func goBack() {
        guard currentStep > 0 else { return }
        navigationDirection = .backward
        withAnimation(BPAnimation.pageTransition) {
            currentStep -= 1
        }
    }

    func completeOnboarding() {
        saveCurrentStep()
        personalizationService.completeOnboarding()
        audioService.stop()
        HapticService.notification(.success)

        TikTokAnalyticsService.shared.trackOnboardingComplete()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            await TikTokAnalyticsService.shared.requestTrackingAuthorization()
        }

        // ── First-session retention hooks ────────────────────────────────
        // Each of these is independently safe to fail — none of them throw
        // and none gate the onboarding completion. The user is now in the
        // app regardless of whether the seeding succeeds.
        seedDay1Streak()
        scheduleDay1WelcomeBackNotification()
    }

    // MARK: - First Session Hooks

    /// Change 1 — log a single activity event for "today" so the streak
    /// counter immediately shows Day 1 instead of Day 0. This is the
    /// psychological foundation of the don't-break-the-chain loop.
    private func seedDay1Streak() {
        ActivityService.log(.appOpened, detail: "onboarding_completed", in: modelContext)
    }

    /// Change 4 — schedule a recurring local notification at the user's
    /// first chosen prayer time, starting tomorrow. Recurring (not
    /// one-shot) so the daily ritual anchors the streak hook from day 2
    /// onward. Skipped if the user opted out of notifications.
    private func scheduleDay1WelcomeBackNotification() {
        let profile = personalizationService.getOrCreateProfile()
        guard profile.notificationsEnabled else { return }
        guard let firstSlot = selectedPrayerTimes.sorted(by: { $0.rawValue < $1.rawValue }).first
            ?? profile.prayerTimes.sorted(by: { $0.rawValue < $1.rawValue }).first
        else { return }

        NotificationService.shared.scheduleWelcomeBackDaily(
            name: firstName.trimmingCharacters(in: .whitespaces),
            slot: firstSlot
        )
    }

    // MARK: - Multi-Select Toggles

    func toggleLifeSeason(_ season: LifeSeason) {
        if selectedLifeSeasons.contains(season) {
            selectedLifeSeasons.remove(season)
        } else if selectedLifeSeasons.count < 3 {
            selectedLifeSeasons.insert(season)
        }
    }

    func toggleBurden(_ burden: Burden) {
        if selectedBurdens.contains(burden) {
            selectedBurdens.remove(burden)
        } else if selectedBurdens.count < 3 {
            selectedBurdens.insert(burden)
        }
    }

    func togglePrayerTime(_ time: PrayerTimeSlot) {
        if selectedPrayerTimes.contains(time) {
            selectedPrayerTimes.remove(time)
        } else {
            selectedPrayerTimes.insert(time)
        }
    }

    func toggleGrowthBlocker(_ blocker: GrowthBlocker) {
        if selectedGrowthBlockers.contains(blocker) {
            selectedGrowthBlockers.remove(blocker)
        } else if selectedGrowthBlockers.count < 3 {
            selectedGrowthBlockers.insert(blocker)
        }
    }

    func toggleGoal(_ goal: AppGoal) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else if selectedGoals.count < 3 {
            selectedGoals.insert(goal)
        }
    }

    // MARK: - Personalized Summary

    var summaryItems: [(label: String, value: String)] {
        var items: [(String, String)] = []

        if !selectedBurdens.isEmpty {
            let burdenNames = selectedBurdens.map(\.displayName).joined(separator: ", ")
            items.append(("Your prayers will focus on", burdenNames))
        }

        items.append(("Verses in", selectedTranslation.displayName))

        if let bg = SanctuaryBackground.background(for: selectedBackgroundID) {
            items.append(("Background", bg.name))
        }

        if !selectedPrayerTimes.isEmpty {
            let times = selectedPrayerTimes.sorted { $0.rawValue < $1.rawValue }
                .map(\.displayName).joined(separator: ", ")
            items.append(("Daily moments", times))
        }

        return items
    }

    // MARK: - Private

    private func saveCurrentStep() {
        switch currentStep {
        case 1:
            personalizationService.updateName(firstName.trimmingCharacters(in: .whitespaces))
        case 2:
            if let faithLevel = selectedFaithLevel {
                personalizationService.updateFaithLevel(faithLevel)
            }
        case 3:
            personalizationService.updateLifeSeasons(Array(selectedLifeSeasons))
        case 4:
            personalizationService.updateBurdens(Array(selectedBurdens))
        case 5:
            personalizationService.updateTranslation(selectedTranslation)
        case 6:
            personalizationService.updatePrayerTimes(Array(selectedPrayerTimes))
        case 8:
            personalizationService.updateSanctuaryBackground(selectedBackgroundID)
            let themeID = SanctuaryBackground.nearestThemeID(for: selectedBackgroundID)
            selectedThemeID = themeID
            personalizationService.updateTheme(themeID)
        default:
            break
        }
        personalizationService.save()
    }

    // MARK: - Notification Permission (Step 7)

    func requestNotificationPermission() {
        Task {
            await requestNotificationPermissionStandalone()
            goNext()
        }
    }

    /// Request notification permission WITHOUT calling goNext at the end.
    /// Used by the conversational onboarding flow which controls its own
    /// step transitions.
    @discardableResult
    func requestNotificationPermissionStandalone() async -> Bool {
        let profile = personalizationService.getOrCreateProfile()
        let contentDescriptor = FetchDescriptor<PrayerContent>()
        let allContent = (try? modelContext.fetch(contentDescriptor)) ?? []

        let granted = await NotificationService.shared.requestAuthorization()
        if granted {
            profile.notificationsEnabled = true
            profile.streakReminderEnabled = true
            profile.planReminderEnabled = true
            personalizationService.save()

            if !profile.prayerTimes.isEmpty {
                NotificationService.shared.reschedule(
                    profile: profile,
                    content: allContent
                )
            }

            NotificationService.shared.scheduleStreakReminders(
                streakCount: profile.streakCount,
                firstName: profile.firstName
            )
        }
        return granted
    }

    // MARK: - Conversational Onboarding Helpers
    //
    // Each `persist*` method writes the corresponding field to the user
    // profile *without* changing currentStep — the conversational view drives
    // its own navigation, so it needs save-only entry points distinct from
    // the legacy `goNext`/`saveCurrentStep` flow.

    func persistName() {
        personalizationService.updateName(firstName.trimmingCharacters(in: .whitespaces))
    }

    func persistFaithLevel() {
        if let level = selectedFaithLevel {
            personalizationService.updateFaithLevel(level)
        }
    }

    func persistLifeSeasons() {
        personalizationService.updateLifeSeasons(Array(selectedLifeSeasons))
    }

    func persistBurdens() {
        personalizationService.updateBurdens(Array(selectedBurdens))
    }

    func persistPrayerTimes() {
        personalizationService.updatePrayerTimes(Array(selectedPrayerTimes))
    }

    func persistGender() {
        if let gender = selectedGender {
            personalizationService.updateGender(gender)
        }
    }

    func persistAge() {
        guard age > 0 else { return }
        personalizationService.updateAge(age)
    }

    func persistCloseness() {
        guard closenessRating > 0 else { return }
        personalizationService.updateClosenessRating(closenessRating)
    }

    func persistGrowthBlockers() {
        personalizationService.updateGrowthBlockers(Array(selectedGrowthBlockers))
    }

    func persistGoals() {
        personalizationService.updateAppGoals(Array(selectedGoals))
    }

    func persistTimeCommitment() {
        if let commitment = selectedTimeCommitment {
            personalizationService.updateTimeCommitment(commitment)
        }
    }

    func persistBackground() {
        personalizationService.updateSanctuaryBackground(selectedBackgroundID)
        let themeID = SanctuaryBackground.nearestThemeID(for: selectedBackgroundID)
        selectedThemeID = themeID
        personalizationService.updateTheme(themeID)
        personalizationService.save()
    }
}
