import AVFoundation
import Foundation

@Observable
final class AudioService {
    private var audioPlayer: AVAudioPlayer?
    var isPlaying: Bool = false
    var volume: Float = 0.3

    func startAmbientMusic(resource: String = "ambient-piano", ext: String = "mp3") {
        guard audioPlayer == nil else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }

        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            audioPlayer = player

            // Fade in over 2 seconds
            fadeVolume(to: volume, duration: 2.0)
            isPlaying = true
        } catch {
            return
        }
    }

    func stopAmbientMusic() {
        guard let player = audioPlayer, isPlaying else { return }

        // Fade out over 1 second then stop
        fadeVolume(to: 0, duration: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            player.stop()
            self?.audioPlayer = nil
            self?.isPlaying = false
        }
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        fadeVolume(to: newVolume, duration: 0.3)
    }

    func togglePlayback() {
        if isPlaying {
            stopAmbientMusic()
        } else {
            startAmbientMusic()
        }
    }

    private func fadeVolume(to target: Float, duration: TimeInterval) {
        guard let player = audioPlayer else { return }

        let steps = 20
        let interval = duration / Double(steps)
        let volumeStep = (target - player.volume) / Float(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                player.volume = player.volume + volumeStep
                if i == steps {
                    player.volume = target
                }
            }
        }
    }
}
