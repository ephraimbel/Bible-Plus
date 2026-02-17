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
    var selectedTranslation: BibleTranslation = .niv
    var selectedPrayerTimes: Set<PrayerTimeSlot> = []
    var selectedThemeID: String = "sunrise-mountains"
    var selectedBackgroundID: String = "warm-gold"

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
        let profile = personalizationService.getOrCreateProfile()
        let contentDescriptor = FetchDescriptor<PrayerContent>()
        let allContent = (try? modelContext.fetch(contentDescriptor)) ?? []

        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            if granted {
                profile.notificationsEnabled = true
                profile.streakReminderEnabled = true
                profile.planReminderEnabled = true
                personalizationService.save()

                // Schedule prayer notifications
                if !profile.prayerTimes.isEmpty {
                    NotificationService.shared.reschedule(
                        profile: profile,
                        content: allContent
                    )
                }

                // Schedule streak reminders
                NotificationService.shared.scheduleStreakReminders(
                    streakCount: profile.streakCount,
                    firstName: profile.firstName
                )
            }
            goNext()
        }
    }
}
