import AVFoundation
import Combine
import UIKit

public final class VideoContainerView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var player: AVQueuePlayer?
    private var cancellable: AnyCancellable?
    private let radius: CGFloat

    public init(cornerRadius: CGFloat) {
        self.radius = cornerRadius
        super.init(frame: .zero)
        clipsToBounds = true
        layer.cornerRadius = radius

        // слушаем возврат из background
        cancellable = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.resumeIfNeeded() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Устанавливаем плеер только один раз
    public func setPlayer(_ player: AVQueuePlayer, gravity: AVLayerVideoGravity) {
        if let existingLayer = playerLayer {
            existingLayer.player = player   // обновляем плеер (если другой, но обычно тот же)
            self.player = player
            return
        }

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = gravity
        layer.frame = bounds
        layer.cornerRadius = radius
        layer.masksToBounds = true

        self.layer.addSublayer(layer)
        playerLayer = layer
        self.player = player
    }

    public func updateLayout() {
        playerLayer?.frame = bounds
    }

    private func resumeIfNeeded() {
        guard let player = player else { return }
        if player.timeControlStatus != .playing {
            print("▶️ Resuming playback after background")
            player.play()
        }
    }
}
