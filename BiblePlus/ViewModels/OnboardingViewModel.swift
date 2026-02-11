import SwiftUI
import SwiftData

@Observable
final class OnboardingViewModel {
    // MARK: - Navigation State
    var currentStep: Int = 0
    var navigationDirection: NavigationDirection = .forward
    let totalSteps: Int = 10

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

    // MARK: - Services
    private let personalizationService: PersonalizationService
    let audioService: SoundscapeService
    let storeKitService: StoreKitService

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case 0: true
        case 1: !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: selectedFaithLevel != nil
        case 3: !selectedLifeSeasons.isEmpty
        case 4: !selectedBurdens.isEmpty
        case 5: true
        case 6: true
        case 7: true
        case 8: true
        case 9: true
        default: false
        }
    }

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.personalizationService = PersonalizationService(modelContext: modelContext)
        self.audioService = SoundscapeService()
        self.storeKitService = StoreKitService()
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

        if let theme = ThemeDefinition.allThemes.first(where: { $0.id == selectedThemeID }) {
            items.append(("Theme", theme.name))
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
        case 7:
            personalizationService.updateTheme(selectedThemeID)
            // Also set the matching background for the unified background system
            if let theme = ThemeDefinition.allThemes.first(where: { $0.id == selectedThemeID }) {
                personalizationService.updateSanctuaryBackground(theme.defaultBackgroundID)
            }
        default:
            break
        }
        personalizationService.save()
    }
}
