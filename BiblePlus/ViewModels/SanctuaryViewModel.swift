import Foundation

@MainActor
@Observable
final class SanctuaryViewModel {
    // MARK: - Dependencies

    let soundscapeService: SoundscapeService
    private let personalizationService: PersonalizationService

    // MARK: - Sheet State

    var showSoundscapePicker = false
    var showBackgroundPicker = false
    var showSleepTimerPicker = false

    // MARK: - Verse Display

    var verseText: String?
    var verseReference: String?

    var hasVerse: Bool { verseText != nil }

    // MARK: - Init

    init(soundscapeService: SoundscapeService, personalizationService: PersonalizationService,
         verseText: String? = nil, verseReference: String? = nil) {
        self.soundscapeService = soundscapeService
        self.personalizationService = personalizationService
        self.verseText = verseText
        self.verseReference = verseReference
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
        guard soundscape.isAvailable else { return }
        guard !soundscape.isProOnly || profile.isPro else { return }
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
