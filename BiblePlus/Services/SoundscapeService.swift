import ActivityKit
import AVFoundation
import Foundation

@Observable
final class SoundscapeService {
    // MARK: - State

    private(set) var currentSoundscape: Soundscape
    private(set) var isPlaying: Bool = false
    var volume: Float = 0.3 {
        didSet { applyVolume() }
    }
    private(set) var sleepTimer: SleepTimerDuration?
    private(set) var sleepTimerRemaining: TimeInterval?

    // MARK: - Live Activity

    private var sanctuaryActivity: Activity<SanctuarySessionAttributes>?

    // MARK: - Private

    private var activePlayer: AVAudioPlayer?
    private var crossfadePlayer: AVAudioPlayer?
    private var sleepTimerTask: Task<Void, Never>?
    private var timerTickTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Init

    init(soundscapeID: String? = nil) {
        let id = soundscapeID ?? "pureSilence"
        self.currentSoundscape = Soundscape(rawValue: id) ?? .pureSilence
        setupInterruptionHandling()
    }

    deinit {
        sleepTimerTask?.cancel()
        timerTickTask?.cancel()
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Silently handle — audio won't play but app won't crash
        }
    }

    private func setupInterruptionHandling() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                self.isPlaying = false
            case .ended:
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.activePlayer?.play()
                        self.isPlaying = true
                    }
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Playback

    func play(_ soundscape: Soundscape) {
        if soundscape == .pureSilence {
            stop()
            currentSoundscape = .pureSilence
            return
        }

        guard soundscape.isAvailable else { return }

        if soundscape == currentSoundscape && activePlayer != nil {
            // Resume the same soundscape
            activePlayer?.play()
            isPlaying = true
            return
        }

        // Crossfade to new soundscape
        crossfade(to: soundscape)
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else if currentSoundscape == .pureSilence {
            // Nothing to play for silence
            return
        } else {
            play(currentSoundscape)
        }
    }

    func pause() {
        activePlayer?.pause()
        isPlaying = false
    }

    func stop() {
        fadeOut(player: activePlayer, duration: 1.0) { [weak self] in
            self?.activePlayer?.stop()
            self?.activePlayer = nil
        }
        isPlaying = false
        cancelSleepTimer()

        if let activity = sanctuaryActivity {
            LiveActivityService.endSanctuarySession(activity)
            sanctuaryActivity = nil
        }
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
    }

    /// Play an arbitrary bundled audio resource (used for onboarding ambient music)
    func playResource(_ resource: String, ext: String = "mp3") {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else { return }
        configureAudioSession()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            player.play()
            fadeIn(player: player, to: volume, duration: 2.0)
            activePlayer = player
            isPlaying = true
        } catch {
            // Audio file couldn't be loaded
        }
    }

    // MARK: - Crossfade

    private func crossfade(to soundscape: Soundscape) {
        guard let fileName = soundscape.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: "m4a") else {
            return
        }

        configureAudioSession()

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0
            newPlayer.prepareToPlay()
            newPlayer.play()

            // Fade out old player
            let oldPlayer = activePlayer
            fadeOut(player: oldPlayer, duration: 1.5) {
                oldPlayer?.stop()
            }

            // Fade in new player
            fadeIn(player: newPlayer, to: volume, duration: 1.5)

            activePlayer = newPlayer
            currentSoundscape = soundscape
            isPlaying = true
        } catch {
            // Audio file couldn't be loaded — fail gracefully
        }
    }

    // MARK: - Volume Fading

    private func applyVolume() {
        guard let player = activePlayer, isPlaying else { return }
        fadeVolume(player: player, to: volume, duration: 0.3)
    }

    private func fadeIn(player: AVAudioPlayer, to target: Float, duration: TimeInterval) {
        fadeVolume(player: player, to: target, duration: duration)
    }

    private func fadeOut(player: AVAudioPlayer?, duration: TimeInterval, completion: @escaping () -> Void) {
        guard let player else {
            completion()
            return
        }
        fadeVolume(player: player, to: 0, duration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }

    private func fadeVolume(player: AVAudioPlayer, to target: Float, duration: TimeInterval) {
        let steps = 20
        let interval = duration / Double(steps)
        let startVolume = player.volume
        let volumeStep = (target - startVolume) / Float(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                if i == steps {
                    player.volume = target
                } else {
                    player.volume = startVolume + volumeStep * Float(i)
                }
            }
        }
    }

    // MARK: - Sleep Timer

    func startSleepTimer(_ duration: SleepTimerDuration) {
        cancelSleepTimer()
        sleepTimer = duration

        guard let interval = duration.timeInterval else {
            // "Until I Close" — no countdown needed
            sleepTimerRemaining = nil
            // Start Live Activity without timer
            sanctuaryActivity = LiveActivityService.startSanctuarySession(
                soundscapeName: currentSoundscape.displayName,
                timerDuration: nil
            )
            return
        }

        sleepTimerRemaining = interval

        // Start Live Activity with timer
        sanctuaryActivity = LiveActivityService.startSanctuarySession(
            soundscapeName: currentSoundscape.displayName,
            timerDuration: interval
        )

        // Tick countdown every second
        timerTickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }

                guard let remaining = self.sleepTimerRemaining else { return }
                let newRemaining = remaining - 1
                if newRemaining <= 0 {
                    self.sleepTimerRemaining = 0
                    self.stop()
                    self.sleepTimer = nil
                    self.sleepTimerRemaining = nil
                    return
                }
                self.sleepTimerRemaining = newRemaining
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        timerTickTask?.cancel()
        timerTickTask = nil
        sleepTimer = nil
        sleepTimerRemaining = nil

        if let activity = sanctuaryActivity {
            LiveActivityService.endSanctuarySession(activity)
            sanctuaryActivity = nil
        }
    }

    var sleepTimerFormatted: String? {
        guard let remaining = sleepTimerRemaining else {
            if sleepTimer == .untilClose { return "∞" }
            return nil
        }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
