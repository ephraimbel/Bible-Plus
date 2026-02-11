import SwiftUI
import AVFoundation

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    var isPlaying: Bool = true

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(videoName: videoName, autoPlay: isPlaying)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        if uiView.currentVideoName != videoName {
            uiView.loadVideo(named: videoName, autoPlay: isPlaying)
        } else {
            uiView.setPlaying(isPlaying)
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
///
/// Supports paused preloading: when `autoPlay` is false, sets up players
/// and seeks to frame 0 (showing the first frame as a thumbnail) without
/// starting playback. Call `setPlaying(true)` to begin.
final class LoopingPlayerUIView: UIView {
    private(set) var currentVideoName: String?
    private var isCurrentlyPlaying: Bool = false

    /// Tracks the desired play state so async setup applies the correct state.
    private var desiredPlaying: Bool = false

    // Shared caches — since all feed cards use the same video, avoid re-loading
    private static var durationCache: [String: Double] = [:]
    private static var assetCache: [String: AVAsset] = [:]

    // Dual players for crossfade
    private var playerA: AVPlayer?
    private var playerB: AVPlayer?
    private var layerA: AVPlayerLayer?
    private var layerB: AVPlayerLayer?

    private var activeIsA = true // tracks which player is currently "on top"
    private var timeObserver: Any?
    private weak var timeObserverPlayer: AVPlayer?
    private var videoDuration: Double = 0
    private var isCrossfading = false
    private var videoURL: URL?

    private let crossfadeDuration: Double = 1.2

    init(videoName: String, autoPlay: Bool = true) {
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
        loadVideo(named: videoName, autoPlay: autoPlay)

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

    func loadVideo(named name: String, autoPlay: Bool = true) {
        cleanup()
        currentVideoName = name
        desiredPlaying = autoPlay

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        self.videoURL = url

        // Use cached asset or create new one
        let asset: AVAsset
        if let cached = Self.assetCache[name] {
            asset = cached
        } else {
            asset = AVAsset(url: url)
            Self.assetCache[name] = asset
        }

        // Use cached duration for instant setup (no async wait)
        if let cachedDuration = Self.durationCache[name] {
            self.videoDuration = cachedDuration
            self.setupDualPlayers(asset: asset)
            return
        }

        // First time: load duration async, then set up players
        Task { @MainActor in
            let duration = try? await asset.load(.duration)
            let seconds = duration.map { CMTimeGetSeconds($0) } ?? 0
            guard seconds > 0 else { return }
            self.videoDuration = seconds
            Self.durationCache[name] = seconds
            self.setupDualPlayers(asset: asset)
        }
    }

    /// Start or pause playback. Safe to call before players are set up —
    /// the desired state is stored and applied when setup completes.
    func setPlaying(_ playing: Bool) {
        desiredPlaying = playing
        guard playerA != nil else { return }
        guard playing != isCurrentlyPlaying else { return }
        applyPlayState(playing)
    }

    private func applyPlayState(_ playing: Bool) {
        isCurrentlyPlaying = playing
        let activePlayer = activeIsA ? playerA : playerB

        if playing {
            activePlayer?.play()
            if let activePlayer {
                addTimeObserver(for: activePlayer)
            }
        } else {
            activePlayer?.pause()
            removeTimeObserver()
        }
    }

    private func setupDualPlayers(asset: AVAsset) {
        // Player A — visible, shows first frame
        let itemA = AVPlayerItem(asset: asset)
        let pA = AVPlayer(playerItem: itemA)
        pA.isMuted = true
        let lA = AVPlayerLayer(player: pA)
        lA.videoGravity = .resizeAspectFill
        lA.frame = bounds
        lA.opacity = 1.0
        layer.addSublayer(lA)

        // Player B — standby, hidden
        let itemB = AVPlayerItem(asset: asset)
        let pB = AVPlayer(playerItem: itemB)
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

        // Seek both to start with exact frame accuracy (shows first frame immediately)
        pA.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        pB.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        pB.pause()

        // Apply the desired play state (may have changed during async load)
        if desiredPlaying {
            pA.play()
            addTimeObserver(for: pA)
            isCurrentlyPlaying = true
        } else {
            pA.pause()
            isCurrentlyPlaying = false
        }
    }

    private func addTimeObserver(for player: AVPlayer) {
        removeTimeObserver()

        // Check every 0.1 seconds
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverPlayer = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.checkForCrossfade(currentTime: CMTimeGetSeconds(time))
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver, let ownerPlayer = timeObserverPlayer {
            ownerPlayer.removeTimeObserver(observer)
        }
        timeObserver = nil
        timeObserverPlayer = nil
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
        removeTimeObserver()

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
        guard isCurrentlyPlaying else { return }
        let activePlayer = activeIsA ? playerA : playerB
        activePlayer?.play()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }
}
