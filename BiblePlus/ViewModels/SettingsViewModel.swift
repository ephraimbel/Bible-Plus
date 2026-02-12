import Foundation
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Dependencies

    private let personalizationService: PersonalizationService
    private let soundscapeService: SoundscapeService
    private let modelContext: ModelContext

    // MARK: - Sheet State

    var showEditName = false
    var showEditFaithLevel = false
    var showEditLifeSeasons = false
    var showEditBurdens = false
    var showEditTranslation = false
    var showEditPrayerTimes = false
    var showSoundscapePicker = false
    var showBackgroundPicker = false
    var showSanctuary = false
    var showVoicePicker = false

    // MARK: - Local Editing Copies

    var editingName: String = ""
    var editingFaithLevel: FaithLevel = .growing
    var editingLifeSeasons: [LifeSeason] = []
    var editingBurdens: [Burden] = []
    var editingTranslation: BibleTranslation = .niv
    var editingPrayerTimes: [PrayerTimeSlot] = []

    // MARK: - Sanctuary

    private var _sanctuaryVM: SanctuaryViewModel?

    var sanctuaryViewModel: SanctuaryViewModel {
        if let existing = _sanctuaryVM { return existing }
        let vm = SanctuaryViewModel(
            soundscapeService: soundscapeService,
            personalizationService: personalizationService
        )
        _sanctuaryVM = vm
        return vm
    }

    // MARK: - Init

    init(modelContext: ModelContext, soundscapeService: SoundscapeService) {
        self.modelContext = modelContext
        self.personalizationService = PersonalizationService(modelContext: modelContext)
        self.soundscapeService = soundscapeService
    }

    // MARK: - Profile

    var profile: UserProfile {
        personalizationService.getOrCreateProfile()
    }

    // MARK: - Begin Editing (loads current values into local copies)

    func beginEditingName() {
        editingName = profile.firstName
        showEditName = true
    }

    func beginEditingFaithLevel() {
        editingFaithLevel = profile.faithLevel
        showEditFaithLevel = true
    }

    func beginEditingLifeSeasons() {
        editingLifeSeasons = profile.lifeSeasons
        showEditLifeSeasons = true
    }

    func beginEditingBurdens() {
        editingBurdens = profile.currentBurdens
        showEditBurdens = true
    }

    func beginEditingTranslation() {
        editingTranslation = profile.preferredTranslation
        showEditTranslation = true
    }

    func beginEditingPrayerTimes() {
        editingPrayerTimes = profile.prayerTimes
        showEditPrayerTimes = true
    }

    // MARK: - Toggle Helpers (multi-select)

    func toggleLifeSeason(_ season: LifeSeason) {
        if editingLifeSeasons.contains(season) {
            editingLifeSeasons.removeAll { $0 == season }
        } else if editingLifeSeasons.count < 3 {
            editingLifeSeasons.append(season)
        }
    }

    func toggleBurden(_ burden: Burden) {
        if editingBurdens.contains(burden) {
            editingBurdens.removeAll { $0 == burden }
        } else if editingBurdens.count < 3 {
            editingBurdens.append(burden)
        }
    }

    func togglePrayerTime(_ slot: PrayerTimeSlot) {
        if editingPrayerTimes.contains(slot) {
            editingPrayerTimes.removeAll { $0 == slot }
        } else {
            editingPrayerTimes.append(slot)
        }
    }

    // MARK: - Save Methods

    func saveName() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        personalizationService.updateName(trimmed)
        postFeedRefresh()
    }

    func saveFaithLevel() {
        personalizationService.updateFaithLevel(editingFaithLevel)
        postFeedRefresh()
    }

    func saveLifeSeasons() {
        personalizationService.updateLifeSeasons(editingLifeSeasons)
        postFeedRefresh()
    }

    func saveBurdens() {
        personalizationService.updateBurdens(editingBurdens)
        postFeedRefresh()
    }

    func saveTranslation() {
        personalizationService.updateTranslation(editingTranslation)
    }

    func savePrayerTimes() {
        personalizationService.updatePrayerTimes(editingPrayerTimes)
        rescheduleNotifications()
    }

    // MARK: - Notifications Toggle

    func toggleNotifications() {
        let newValue = !profile.notificationsEnabled
        if newValue {
            // Turning ON — request authorization first
            Task {
                let granted = await NotificationService.shared.requestAuthorization()
                if granted {
                    profile.notificationsEnabled = true
                    profile.updatedAt = Date()
                    personalizationService.save()
                    rescheduleNotifications()
                }
                // If denied, the toggle stays off (system denied permission)
            }
        } else {
            // Turning OFF — cancel all and persist
            profile.notificationsEnabled = false
            profile.updatedAt = Date()
            personalizationService.save()
            NotificationService.shared.cancelAll()
        }
    }

    private func rescheduleNotifications() {
        guard profile.notificationsEnabled else {
            NotificationService.shared.cancelAll()
            return
        }
        let contentDescriptor = FetchDescriptor<PrayerContent>()
        let allContent = (try? modelContext.fetch(contentDescriptor)) ?? []
        if profile.prayerTimes.isEmpty {
            NotificationService.shared.cancelAll()
        } else {
            NotificationService.shared.reschedule(
                profile: profile,
                content: allContent
            )
        }
    }

    func updateColorMode(_ mode: ColorMode) {
        personalizationService.updateColorMode(mode)
    }

    // MARK: - Display Helpers

    var streakDisplay: String {
        let count = profile.streakCount
        if count == 0 { return "Not started" }
        if count == 1 { return "1 day" }
        return "\(count) days"
    }

    var lifeSeasonsDisplay: String {
        let seasons = profile.lifeSeasons
        guard !seasons.isEmpty else { return "Not set" }
        return seasons.map(\.displayName).joined(separator: ", ")
    }

    var burdensDisplay: String {
        let burdens = profile.currentBurdens
        guard !burdens.isEmpty else { return "Not set" }
        return burdens.map(\.displayName).joined(separator: ", ")
    }

    var prayerTimesDisplay: String {
        let times = profile.prayerTimes
        guard !times.isEmpty else { return "Not set" }
        return times.map(\.displayName).joined(separator: ", ")
    }

    var currentVoiceDisplay: String {
        BibleVoice.voice(for: profile.selectedBibleVoiceID)?.displayName ?? "The Preacher"
    }

    var currentSoundscapeDisplay: String {
        let id = profile.selectedSoundscapeID
        return Soundscape(rawValue: id)?.displayName ?? "Pure Silence"
    }

    var currentBackgroundDisplay: String {
        SanctuaryBackground.background(for: profile.selectedBackgroundID)?.name ?? "Warm Gold"
    }

    // MARK: - Notification

    static let personalizationDidChange = Notification.Name("PersonalizationDidChange")

    private func postFeedRefresh() {
        NotificationCenter.default.post(name: Self.personalizationDidChange, object: nil)
    }
}
