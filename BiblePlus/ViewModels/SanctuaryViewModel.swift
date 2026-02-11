import Foundation
import SwiftData

@Observable
final class SanctuaryViewModel {
    // MARK: - Dependencies

    let soundscapeService: SoundscapeService
    private let personalizationService: PersonalizationService

    // MARK: - Sheet State

    var showSoundscapePicker = false
    var showBackgroundPicker = false
    var showSleepTimerPicker = false

    // MARK: - Init

    init(soundscapeService: SoundscapeService, personalizationService: PersonalizationService) {
        self.soundscapeService = soundscapeService
        self.personalizationService = personalizationService
    }

    // MARK: - Profile

    var profile: UserProfile {
        personalizationService.getOrCreateProfile()
    }

    // MARK: - Soundscapes

    var currentSoundscape: Soundscape {
        soundscapeService.currentSoundscape
    }

    var isPlaying: Bool {
        soundscapeService.isPlaying
    }

    var availableSoundscapes: [Soundscape] {
        Soundscape.freeSoundscapes
    }

    var proSoundscapes: [Soundscape] {
        Soundscape.proSoundscapes
    }

    func selectSoundscape(_ soundscape: Soundscape) {
        soundscapeService.play(soundscape)
        personalizationService.updateSoundscape(soundscape.rawValue)
    }

    func togglePlayback() {
        soundscapeService.togglePlayback()
    }

    // MARK: - Backgrounds

    var selectedBackground: SanctuaryBackground {
        SanctuaryBackground.background(for: profile.selectedBackgroundID)
            ?? SanctuaryBackground.allBackgrounds[0]
    }

    func backgroundsByCollection(_ collection: BackgroundCollection) -> [SanctuaryBackground] {
        SanctuaryBackground.backgrounds(in: collection)
    }

    func selectBackground(_ background: SanctuaryBackground) {
        personalizationService.updateSanctuaryBackground(background.id)
    }

    // MARK: - Volume

    var volume: Float {
        get { soundscapeService.volume }
        set { soundscapeService.setVolume(newValue) }
    }

    // MARK: - Sleep Timer

    var sleepTimer: SleepTimerDuration? {
        soundscapeService.sleepTimer
    }

    var sleepTimerFormatted: String? {
        soundscapeService.sleepTimerFormatted
    }

    func startSleepTimer(_ duration: SleepTimerDuration) {
        soundscapeService.startSleepTimer(duration)
    }

    func cancelSleepTimer() {
        soundscapeService.cancelSleepTimer()
    }
}
