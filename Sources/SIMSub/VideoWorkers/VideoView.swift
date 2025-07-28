import SwiftUI
import AVKit

// MARK: - Video Asset Queue Enum
public enum VideoAssetQueue {
    case main, userInitiated, utility, background
    
    var dispatchQueue: DispatchQueue {
        switch self {
        case .main: return .main
        case .userInitiated: return .global(qos: .userInitiated)
        case .utility: return .global(qos: .utility)
        case .background: return .global(qos: .background)
        }
    }
}

// MARK: - VideoSimpleView
public struct VideoSimpleView: UIViewControllerRepresentable {
    public let name: String
    public let gravity: AVLayerVideoGravity
    public let loop: Bool
    public let assetQueue: VideoAssetQueue

    public init(
        name: String,
        gravity: AVLayerVideoGravity,
        loop: Bool = true,
        assetQueue: VideoAssetQueue = .userInitiated
    ) {
        self.name = name
        self.gravity = gravity
        self.loop = loop
        self.assetQueue = assetQueue
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.showsPlaybackControls = false
        vc.videoGravity = gravity
        vc.view.backgroundColor = .clear
        vc.allowsPictureInPicturePlayback = false

        Task {
            await VideoManager.shared.registerVideo(name: name, loop: loop, controller: vc, assetQueue: assetQueue)
            if let player = vc.player, player.currentItem?.status == .readyToPlay {
                player.play()
                print("Playing video on view controller creation: \(name)")
            }
        }
        return vc
    }

    public func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.videoGravity != gravity {
            vc.videoGravity = gravity
        }
    }
}

// MARK: - VideoContainerViewRepresentable
public struct VideoContainerViewRepresentable: UIViewRepresentable {
    let videoName: String
    let gravity: AVLayerVideoGravity
    let cornerRadius: CGFloat
    let loop: Bool
    
    public init(videoName: String, gravity: AVLayerVideoGravity, cornerRadius: CGFloat = 0, loop: Bool = true) {
        self.videoName = videoName
        self.gravity = gravity
        self.cornerRadius = cornerRadius
        self.loop = loop
    }
    
    public func makeUIView(context: Context) -> VideoSimpleContainerView {
        let view = VideoSimpleContainerView(cornerRadius: cornerRadius)
        view.setupVideo(name: videoName, gravity: gravity, loop: loop)
        return view
    }
    
    public func updateUIView(_ uiView: VideoSimpleContainerView, context: Context) {}
}

// MARK: - VideoSimpleContainerView
@MainActor
public final class VideoSimpleContainerView: UIView {
    private let coordinator: VideoViewCoordinator
    private var playerLayer: AVPlayerLayer?
    private let radius: CGFloat
    
    public init(cornerRadius: CGFloat) {
        self.radius = cornerRadius
        self.coordinator = VideoViewCoordinator()
        super.init(frame: .zero)
        clipsToBounds = true
        layer.cornerRadius = radius
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public func setupVideo(name: String, gravity: AVLayerVideoGravity, loop: Bool = true) {
        Task {
            await coordinator.setup(videoName: name, loop: loop)
            if let player = coordinator.player {
                setPlayer(player, gravity: gravity)
                coordinator.play()
            }
        }
    }
    
    private func setPlayer(_ player: AVPlayer, gravity: AVLayerVideoGravity) {
        if let existingLayer = playerLayer {
            if existingLayer.player !== player {
                existingLayer.player = player
                print("Updated player for existing layer: \(String(describing: player.currentItem?.asset))")
            }
            if existingLayer.videoGravity != gravity {
                existingLayer.videoGravity = gravity
            }
            return
        }
        
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = gravity
        layer.frame = bounds
        layer.cornerRadius = radius
        layer.masksToBounds = true
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.layer.insertSublayer(layer, at: 0)
        CATransaction.commit()
        
        playerLayer = layer
        print("Set new player layer for video: \(String(describing: player.currentItem?.asset))")
    }
    
    public func updateLayout() {
        guard let playerLayer = playerLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
}

// MARK: - VideoViewCoordinator
@MainActor
final class VideoViewCoordinator: ObservableObject, Hashable {
    private let id = UUID()
    private(set) var player: AVPlayer?
    private var currentVideoName: String?
    private var shouldLoop: Bool = true
    
    nonisolated static func == (lhs: VideoViewCoordinator, rhs: VideoViewCoordinator) -> Bool {
        lhs.id == rhs.id
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated init() {}
    
    func setup(videoName: String, loop: Bool = true) async {
        if currentVideoName == videoName && player != nil {
            if let player = player, player.currentItem?.status == .readyToPlay {
                player.play()
                print("Playing existing player for: \(videoName)")
            } else {
                print("Existing player for \(videoName) not ready")
            }
            return
        }
        
        cleanup()
        currentVideoName = videoName
        shouldLoop = loop
        
        player = await VideoManager.shared.getPlayer(for: videoName, loop: loop)
        if let player = player, player.currentItem?.status == .readyToPlay {
            player.play()
            print("Playing new player for: \(videoName)")
        }
    }
    
    func play() {
        if let player = player, player.currentItem?.status == .readyToPlay {
            player.play()
            print("Coordinator play called for: \(String(describing: currentVideoName))")
        }
    }
    
    func pause() {
        player?.pause()
        print("Coordinator pause called for: \(String(describing: currentVideoName))")
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
        currentVideoName = nil
        print("Coordinator cleaned up")
    }
}

// MARK: - Sendable Observer Wrapper
final class ObserverHolder: @unchecked Sendable {
    let observer: NSObjectProtocol
    let center: NotificationCenter

    init(observer: NSObjectProtocol, center: NotificationCenter) {
        self.observer = observer
        self.center = center
    }

    func remove() {
        center.removeObserver(observer)
    }
}


struct LoopObserver: Sendable {
    private let id: String
    private let holder: ObserverHolder

    init(id: String, observer: NSObjectProtocol, center: NotificationCenter = .default) {
        self.id = id
        self.holder = ObserverHolder(observer: observer, center: center)
    }

    func remove() {
        holder.remove()
    }
}


// MARK: - VideoManager
@MainActor
public final class VideoManager: NSObject {
    public static let shared = VideoManager()
    private var playerCache: [String: AVPlayer] = [:]
    private var activeControllers: [String: WeakRef<AVPlayerViewController>] = [:]
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    private var playerItemObservers: [String: NSKeyValueObservation] = [:]
    private var loopObservers: [String: LoopObserver] = [:]
    
    private class WeakRef<T: AnyObject> {
        weak var value: T?
        init(_ value: T) {
            self.value = value
        }
    }
    
    private override init() {
        super.init()
        setupAppLifecycleObservers()
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.resumeAllVideos() }
        }
        
    }
    
    public func registerVideo(name: String, loop: Bool, controller: AVPlayerViewController, assetQueue: VideoAssetQueue) async {
        activeControllers[name] = WeakRef(controller)
        let player = await getPlayer(for: name, loop: loop, assetQueue: assetQueue)
        controller.player = player
        logPlayerState(player, name: name)
        if player.currentItem?.status == .readyToPlay {
            player.play()
            print("Playing video in registerVideo: \(name)")
        } else {
            let observer = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
                Task { @MainActor in
                    if item.status == .readyToPlay {
                        player.play()
                        print("Playing video after ready in registerVideo: \(name)")
                        self?.playerItemObservers[name] = nil
                    } else if item.status == .failed {
                        print("AVPlayerItem failed in registerVideo: \(name), error: \(String(describing: item.error))")
                        self?.playerItemObservers[name] = nil
                    }
                }
            }
            if let observer = observer {
                playerItemObservers[name] = observer
            }
        }
    }
    
    public func getPlayer(for name: String, loop: Bool = true, assetQueue: VideoAssetQueue = .userInitiated) async -> AVPlayer {
        if let cachedPlayer = playerCache[name] {
            logPlayerState(cachedPlayer, name: name)
            if cachedPlayer.currentItem?.status == .readyToPlay {
                cachedPlayer.play()
                print("Returning cached player for: \(name)")
            } else {
                print("Cached player for \(name) not ready")
            }
            return cachedPlayer
        }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
            print("Video file not found: \(name)")
            return AVPlayer()
        }
        
        let asset = AVURLAsset(url: url)
        let keys = ["playable"]
        
        return await withCheckedContinuation { continuation in
            assetQueue.dispatchQueue.async {
                asset.loadValuesAsynchronously(forKeys: keys) {
                    guard asset.statusOfValue(forKey: "playable", error: nil) == .loaded else {
                        print("Failed to load asset for: \(name)")
                        continuation.resume(returning: AVPlayer())
                        return
                    }
                    Task { @MainActor in
                        let item = AVPlayerItem(asset: asset)
                        let player = AVPlayer(playerItem: item)
                        self.playerCache[name] = player
                        
                        let observer = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                            Task { @MainActor in
                                if item.status == .readyToPlay {
                                    player.play()
                                    print("AVPlayerItem ready for playback: \(name)")
                                    self?.playerItemObservers[name] = nil
                                } else if item.status == .failed {
                                    print("AVPlayerItem failed for: \(name), error: \(String(describing: item.error))")
                                    self?.playerItemObservers[name] = nil
                                }
                            }
                        }
                        self.playerItemObservers[name] = observer
                        
                        if loop, let item = player.currentItem {
                            let observer = NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: item,
                                queue: .main
                            ) { [weak self] _ in
                                Task { @MainActor in
                                    if let player = self?.playerCache[name] {
                                        player.seek(to: .zero)
                                        player.play()
                                        print("Looping video in VideoManager: \(name)")
                                    }
                                }
                            }
                            self.loopObservers[name] = LoopObserver(id: name, observer: observer)
                        }
                        
                        continuation.resume(returning: player)
                    }
                }
            }
        }
    }
    
    public func preloadVideos(names: [String], queue: VideoAssetQueue = .background) {
        for name in names {
            if playerCache[name] == nil, preloadTasks[name] == nil {
                preloadTasks[name] = Task {
                    let player = await self.getPlayer(for: name, loop: true, assetQueue: queue)
                    self.preloadTasks[name] = nil
                    print("Preloaded video: \(name)")
                    self.logPlayerState(player, name: name)
                }
            }
        }
    }
    
    private func pauseAllVideos() async {
        for (name, player) in playerCache {
            print("Pausing video: \(name)")
            player.pause()
        }
    }
    
    private func resumeAllVideos() async {
        for (name, player) in playerCache {
            if let controller = activeControllers[name]?.value, controller.player == player, player.currentItem?.status == .readyToPlay {
                print("Resuming video: \(name)")
                player.play()
            } else {
                print("Not resuming video \(name): not displayed or not ready")
            }
        }
    }
    
    private func clearCache() {
        for (name, observer) in loopObservers {
            observer.remove()
            print("Removed loop observer for: \(name)")
        }
        loopObservers.removeAll()
        playerCache.removeAll()
        activeControllers.removeAll()
        playerItemObservers.removeAll()
        print("Cache cleared")
    }
    
    private func softClearCache() {
        print("Received memory warning")
        
        let activeNames = Set(activeControllers.keys)
        
        for name in playerCache.keys {
            if !activeNames.contains(name) {
                playerCache[name]?.pause()
                playerCache[name] = nil
                loopObservers[name]?.remove()
                loopObservers[name] = nil
                print("Removed inactive video: \(name)")
            }
        }
        
    }

    
    private func logPlayerState(_ player: AVPlayer, name: String) {
        if let item = player.currentItem {
            switch item.status {
            case .unknown:
                print("Player state for \(name): Unknown")
            case .readyToPlay:
                print("Player state for \(name): Ready to play")
            case .failed:
                print("Player state for \(name): Failed, error: \(String(describing: item.error))")
            @unknown default:
                print("Player state for \(name): Unknown status")
            }
        } else {
            print("Player state for \(name): No current item")
        }
    }
    
    @MainActor
    private func cleanupObservers() {
        NotificationCenter.default.removeObserver(self)
        for (name, observer) in loopObservers {
            observer.remove()
            print("Removed loop observer for: \(name)")
        }
        loopObservers.removeAll()
        print("VideoManager deinit")
    }

    deinit {
        DispatchQueue.main.async { [weak self] in
            self?.cleanupObservers()
        }
    }
}
