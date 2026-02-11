import SwiftUI
import AVFoundation

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(videoName: videoName)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        if uiView.currentVideoName != videoName {
            uiView.loadVideo(named: videoName)
        }
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.cleanup()
    }
}

/// Dual-player crossfade looping video view.
/// Uses two AVPlayers with overlapping playback — when one nears its end,
/// the other starts from the beginning and we crossfade between layers,
/// creating a seamless infinite loop with no visible cut.
final class LoopingPlayerUIView: UIView {
    private(set) var currentVideoName: String?

    // Dual players for crossfade
    private var playerA: AVPlayer?
    private var playerB: AVPlayer?
    private var layerA: AVPlayerLayer?
    private var layerB: AVPlayerLayer?

    private var activeIsA = true // tracks which player is currently "on top"
    private var timeObserver: Any?
    private var videoDuration: Double = 0
    private var isCrossfading = false
    private var videoURL: URL?

    private let crossfadeDuration: Double = 1.2

    init(videoName: String) {
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
        loadVideo(named: videoName)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layerA?.frame = bounds
        layerB?.frame = bounds
    }

    func loadVideo(named name: String) {
        cleanup()
        currentVideoName = name

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        self.videoURL = url

        let asset = AVAsset(url: url)

        // Get duration
        Task { @MainActor in
            let duration = try? await asset.load(.duration)
            let seconds = duration.map { CMTimeGetSeconds($0) } ?? 0
            guard seconds > 0 else { return }
            self.videoDuration = seconds
            self.setupDualPlayers(url: url)
        }
    }

    private func setupDualPlayers(url: URL) {
        // Player A — starts playing immediately
        let pA = AVPlayer(url: url)
        pA.isMuted = true
        let lA = AVPlayerLayer(player: pA)
        lA.videoGravity = .resizeAspectFill
        lA.frame = bounds
        lA.opacity = 1.0
        layer.addSublayer(lA)

        // Player B — ready but hidden
        let pB = AVPlayer(url: url)
        pB.isMuted = true
        let lB = AVPlayerLayer(player: pB)
        lB.videoGravity = .resizeAspectFill
        lB.frame = bounds
        lB.opacity = 0.0
        layer.addSublayer(lB)

        self.playerA = pA
        self.playerB = pB
        self.layerA = lA
        self.layerB = lB
        self.activeIsA = true
        self.isCrossfading = false

        // Start player A
        pA.seek(to: .zero)
        pA.play()

        // Pause player B at start
        pB.seek(to: .zero)
        pB.pause()

        // Add time observer on player A to trigger crossfade
        addTimeObserver(for: pA)
    }

    private func addTimeObserver(for player: AVPlayer) {
        // Remove old observer
        if let observer = timeObserver, let activePlayer = activeIsA ? playerA : playerB {
            activePlayer.removeTimeObserver(observer)
        }
        timeObserver = nil

        // Check every 0.1 seconds
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.checkForCrossfade(currentTime: CMTimeGetSeconds(time))
        }
    }

    private func checkForCrossfade(currentTime: Double) {
        guard !isCrossfading, videoDuration > crossfadeDuration * 2 else { return }

        let timeRemaining = videoDuration - currentTime
        if timeRemaining <= crossfadeDuration && timeRemaining > 0 {
            performCrossfade()
        }
    }

    private func performCrossfade() {
        isCrossfading = true

        let activeLayer = activeIsA ? layerA : layerB
        let standbyPlayer = activeIsA ? playerB : playerA
        let standbyLayer = activeIsA ? layerB : layerA

        guard let activeLayer, let standbyPlayer, let standbyLayer else {
            isCrossfading = false
            return
        }

        // Start standby player from beginning
        standbyPlayer.seek(to: .zero)
        standbyPlayer.play()

        // Crossfade layers
        CATransaction.begin()
        CATransaction.setAnimationDuration(crossfadeDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        // Fade out active, fade in standby
        activeLayer.opacity = 0.0
        standbyLayer.opacity = 1.0

        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }

            // Pause the now-hidden player and reset it
            let oldPlayer = self.activeIsA ? self.playerA : self.playerB
            oldPlayer?.pause()
            oldPlayer?.seek(to: .zero)

            // Swap active
            self.activeIsA.toggle()

            // Move time observer to the new active player
            let newActive = self.activeIsA ? self.playerA : self.playerB
            if let newActive {
                self.addTimeObserver(for: newActive)
            }

            self.isCrossfading = false
        }

        CATransaction.commit()
    }

    func cleanup() {
        if let observer = timeObserver {
            let activePlayer = activeIsA ? playerA : playerB
            activePlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }

        playerA?.pause()
        playerB?.pause()
        layerA?.removeFromSuperlayer()
        layerB?.removeFromSuperlayer()
        playerA = nil
        playerB = nil
        layerA = nil
        layerB = nil
        currentVideoName = nil
        videoURL = nil
        isCrossfading = false
    }

    @objc private func appDidEnterBackground() {
        playerA?.pause()
        playerB?.pause()
    }

    @objc private func appWillEnterForeground() {
        let activePlayer = activeIsA ? playerA : playerB
        activePlayer?.play()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }
}
