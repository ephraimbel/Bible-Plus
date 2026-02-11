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

final class LoopingPlayerUIView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private(set) var currentVideoName: String?

    init(videoName: String) {
        super.init(frame: .zero)
        backgroundColor = .black
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
        playerLayer?.frame = bounds
    }

    func loadVideo(named name: String) {
        cleanup()
        currentVideoName = name

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(items: [item])
        queuePlayer.isMuted = true

        let looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(asset: asset))

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)

        self.player = queuePlayer
        self.looper = looper
        self.playerLayer = layer

        queuePlayer.play()
    }

    func cleanup() {
        player?.pause()
        player?.removeAllItems()
        playerLayer?.removeFromSuperlayer()
        looper = nil
        player = nil
        playerLayer = nil
        currentVideoName = nil
    }

    @objc private func appDidEnterBackground() {
        player?.pause()
    }

    @objc private func appWillEnterForeground() {
        player?.play()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }
}
