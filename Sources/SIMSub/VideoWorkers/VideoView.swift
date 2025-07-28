import SwiftUI
import AVKit
import os

/// A logger for video-related operations in the VideoManager.
@available(iOS 14.0, *)
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app", category: "VideoManager")

/// Defines dispatch queue priorities for loading video assets.
public enum VideoAssetQueue {
    case main
    case userInitiated
    case utility
    case background
    
    /// Returns the corresponding `DispatchQueue` for the queue type.
    var dispatchQueue: DispatchQueue {
        switch self {
        case .main: return .main
        case .userInitiated: return .global(qos: .userInitiated)
        case .utility: return .global(qos: .utility)
        case .background: return .global(qos: .background)
        }
    }
}

/// A SwiftUI view that wraps an `AVPlayerViewController` to display a video.
@available(iOS 14.0, *)
public struct VideoSimpleView: UIViewControllerRepresentable {
    public let name: String
    public let gravity: AVLayerVideoGravity
    public let loop: Bool
    public let assetQueue: VideoAssetQueue
    
    /// Initializes a `VideoSimpleView` with the specified video parameters.
    /// - Parameters:
    ///   - name: The name of the video file (without extension).
    ///   - gravity: The video gravity for playback (e.g., `.resizeAspectFill`).
    ///   - loop: Whether the video should loop. Defaults to `true`.
    ///   - assetQueue: The dispatch queue for loading the video asset. Defaults to `.userInitiated`.
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
    
    /// Creates and configures an `AVPlayerViewController` for video playback.
    /// - Parameter context: The context provided by SwiftUI.
    /// - Returns: A configured `AVPlayerViewController`.
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
                logger.info("Playing video on view controller creation: \(name)")
            }
        }
        return vc
    }
    
    /// Updates the `AVPlayerViewController` with new properties if needed.
    /// - Parameters:
    ///   - vc: The `AVPlayerViewController` to update.
    ///   - context: The context provided by SwiftUI.
    public func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.videoGravity != gravity {
            vc.videoGravity = gravity
        }
    }
}

/// A SwiftUI view that wraps a `VideoSimpleContainerView` for custom video rendering.
@available(iOS 14.0, *)
public struct VideoContainerViewRepresentable: UIViewRepresentable {
    let videoName: String
    let gravity: AVLayerVideoGravity
    let cornerRadius: CGFloat
    let loop: Bool
    
    /// Initializes a `VideoContainerViewRepresentable` with the specified video parameters.
    /// - Parameters:
    ///   - videoName: The name of the video file (without extension).
    ///   - gravity: The video gravity for playback (e.g., `.resizeAspectFill`).
    ///   - cornerRadius: The corner radius for the video view. Defaults to `0`.
    ///   - loop: Whether the video should loop. Defaults to `true`.
    public init(videoName: String, gravity: AVLayerVideoGravity, cornerRadius: CGFloat = 0, loop: Bool = true) {
        self.videoName = videoName
        self.gravity = gravity
        self.cornerRadius = cornerRadius
        self.loop = loop
    }
    
    /// Creates a `VideoSimpleContainerView` for video playback.
    /// - Parameter context: The context provided by SwiftUI.
    /// - Returns: A configured `VideoSimpleContainerView`.
    public func makeUIView(context: Context) -> VideoSimpleContainerView {
        let view = VideoSimpleContainerView(cornerRadius: cornerRadius)
        view.setupVideo(name: videoName, gravity: gravity, loop: loop)
        return view
    }
    
    /// Updates the `VideoSimpleContainerView` (currently a no-op).
    /// - Parameters:
    ///   - uiView: The `VideoSimpleContainerView` to update.
    ///   - context: The context provided by SwiftUI.
    public func updateUIView(_ uiView: VideoSimpleContainerView, context: Context) {}
}

/// A custom `UIView` for displaying videos with an `AVPlayerLayer`.
@MainActor
@available(iOS 14.0, *)
public final class VideoSimpleContainerView: UIView {
    private let coordinator: VideoViewCoordinator
    private var playerLayer: AVPlayerLayer?
    private let radius: CGFloat
    
    /// Initializes a `VideoSimpleContainerView` with a specified corner radius.
    /// - Parameter cornerRadius: The corner radius for the video view.
    public init(cornerRadius: CGFloat) {
        self.radius = cornerRadius
        self.coordinator = VideoViewCoordinator()
        super.init(frame: .zero)
        clipsToBounds = true
        layer.cornerRadius = radius
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    /// Sets up the video with the specified parameters.
    /// - Parameters:
    ///   - name: The name of the video file (without extension).
    ///   - gravity: The video gravity for playback (e.g., `.resizeAspectFill`).
    ///   - loop: Whether the video should loop. Defaults to `true`.
    public func setupVideo(name: String, gravity: AVLayerVideoGravity, loop: Bool = true) {
        Task {
            await coordinator.setup(videoName: name, loop: loop)
            if let player = coordinator.player {
                setPlayer(player, gravity: gravity)
                coordinator.play()
            }
        }
    }
    
    /// Configures the `AVPlayerLayer` with the provided player and gravity.
    /// - Parameters:
    ///   - player: The `AVPlayer` to display.
    ///   - gravity: The video gravity for playback.
    private func setPlayer(_ player: AVPlayer, gravity: AVLayerVideoGravity) {
        if let existingLayer = playerLayer {
            if existingLayer.player !== player {
                existingLayer.player = player
                logger.info("Updated player for existing layer: \(String(describing: player.currentItem?.asset))")
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
        logger.info("Set new player layer for video: \(String(describing: player.currentItem?.asset))")
    }
    
    /// Updates the layout of the `AVPlayerLayer` to match the view's bounds.
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

/// Coordinates video playback and manages the `AVPlayer` instance.
@MainActor
@available(iOS 14.0, *)
final class VideoViewCoordinator: ObservableObject, Hashable {
    private let id = UUID()
    private(set) var player: AVPlayer?
    private var currentVideoName: String?
    private var shouldLoop: Bool = true
    
    /// Compares two coordinators for equality based on their IDs.
    nonisolated static func == (lhs: VideoViewCoordinator, rhs: VideoViewCoordinator) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashes the coordinator using its ID.
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Initializes a new `VideoViewCoordinator`.
    nonisolated init() {}
    
    /// Sets up the video with the specified name and looping behavior.
    /// - Parameters:
    ///   - videoName: The name of the video file (without extension).
    ///   - loop: Whether the video should loop. Defaults to `true`.
    func setup(videoName: String, loop: Bool = true) async {
        if currentVideoName == videoName && player != nil {
            if let player = player, player.currentItem?.status == .readyToPlay {
                player.play()
                logger.info("Playing existing player for: \(videoName)")
            } else {
                logger.info("Existing player for \(videoName) not ready")
            }
            return
        }
        
        cleanup()
        currentVideoName = videoName
        shouldLoop = loop
        
        player = await VideoManager.shared.getPlayer(for: videoName, loop: loop)
        if let player = player, player.currentItem?.status == .readyToPlay {
            player.play()
            logger.info("Playing new player for: \(videoName)")
        }
    }
    
    /// Starts video playback if the player is ready.
    func play() {
        if let player = player, player.currentItem?.status == .readyToPlay {
            player.play()
            logger.info("Coordinator play called for: \(String(describing: self.currentVideoName))")
        }
    }
    
    /// Pauses video playback.
    func pause() {
        player?.pause()
        logger.info("Coordinator pause called for: \(String(describing: self.currentVideoName))")
    }
    
    /// Cleans up the coordinator by pausing and releasing the player.
    private func cleanup() {
        player?.pause()
        player = nil
        currentVideoName = nil
        logger.info("Coordinator cleaned up")
    }
}

/// A `Sendable` wrapper for holding and removing notification observers.
final class ObserverHolder: @unchecked Sendable {
    let observer: NSObjectProtocol
    let center: NotificationCenter
    
    /// Initializes an `ObserverHolder` with the given observer and notification center.
    /// - Parameters:
    ///   - observer: The notification observer to hold.
    ///   - center: The notification center managing the observer.
    init(observer: NSObjectProtocol, center: NotificationCenter) {
        self.observer = observer
        self.center = center
    }
    
    /// Removes the held observer from the notification center.
    func remove() {
        center.removeObserver(observer)
    }
}

/// A `Sendable` struct for managing video loop observers.
@available(iOS 14.0, *)
struct LoopObserver: Sendable {
    private let id: String
    private let holder: ObserverHolder
    
    /// Initializes a `LoopObserver` with the given ID and observer.
    /// - Parameters:
    ///   - id: The identifier for the observer (typically the video name).
    ///   - observer: The notification observer to manage.
    ///   - center: The notification center managing the observer. Defaults to `.default`.
    init(id: String, observer: NSObjectProtocol, center: NotificationCenter = .default) {
        self.id = id
        self.holder = ObserverHolder(observer: observer, center: center)
    }
    
    /// Removes the observer from the notification center.
    func remove() {
        holder.remove()
    }
}

/// Manages video playback, caching, and lifecycle events for the app.
@MainActor
@available(iOS 14.0, *)
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
    
    /// Sets up observers for app lifecycle events (foreground, background, memory warnings).
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.resumeAllVideos() }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.pauseAllVideos() }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.softClearCache()
            }
        }
    }
    
    /// Resumes a specific video by name if it's ready to play.
    public func resumeVideo(name: String) async {
        if let player = playerCache[name], player.currentItem?.status == .readyToPlay {
            player.play()
            logger.info("Resumed video: \(name)")
        } else {
            logger.info("Not resuming video \(name): not in cache or not ready")
        }
    }
    
    public func pauseVideo(name: String) async {
        if let player = playerCache[name] {
            player.pause()
            logger.info("Paused video: \(name)")
        }
    }
    
    /// Registers a video to be played in an `AVPlayerViewController`.
    /// - Parameters:
    ///   - name: The name of the video file (without extension).
    ///   - loop: Whether the video should loop.
    ///   - controller: The `AVPlayerViewController` to display the video.
    ///   - assetQueue: The dispatch queue for loading the video asset.
    public func registerVideo(name: String, loop: Bool, controller: AVPlayerViewController, assetQueue: VideoAssetQueue) async {
        activeControllers[name] = WeakRef(controller)
        let player = await getPlayer(for: name, loop: loop, assetQueue: assetQueue)
        controller.player = player
        logPlayerState(player, name: name)
        if player.currentItem?.status == .readyToPlay {
            player.play()
            logger.info("Playing video in registerVideo: \(name)")
        } else {
            let observer = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
                Task { @MainActor in
                    if item.status == .readyToPlay {
                        player.play()
                        logger.info("Playing video after ready in registerVideo: \(name)")
                        self?.playerItemObservers[name] = nil
                    } else if item.status == .failed {
                        logger.error("AVPlayerItem failed in registerVideo: \(name), error: \(String(describing: item.error))")
                        self?.playerItemObservers[name] = nil
                    }
                }
            }
            if let observer = observer {
                playerItemObservers[name] = observer
            }
        }
    }
    
    /// Retrieves or creates an `AVPlayer` for the specified video.
    /// - Parameters:
    ///   - name: The name of the video file (without extension).
    ///   - loop: Whether the video should loop. Defaults to `true`.
    ///   - assetQueue: The dispatch queue for loading the video asset. Defaults to `.userInitiated`.
    /// - Returns: An `AVPlayer` configured for the video.
    public func getPlayer(for name: String, loop: Bool = true, assetQueue: VideoAssetQueue = .userInitiated) async -> AVPlayer {
        if let cachedPlayer = playerCache[name] {
            logPlayerState(cachedPlayer, name: name)
            if cachedPlayer.currentItem?.status == .readyToPlay {
                cachedPlayer.play()
                logger.info("Returning cached player for: \(name)")
            } else {
                logger.info("Cached player for \(name) not ready")
            }
            return cachedPlayer
        }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
            logger.error("Video file not found: \(name)")
            return AVPlayer()
        }
        
        let asset = AVURLAsset(url: url)
        let keys = ["playable"]
        
        return await withCheckedContinuation { continuation in
            assetQueue.dispatchQueue.async {
                asset.loadValuesAsynchronously(forKeys: keys) {
                    guard asset.statusOfValue(forKey: "playable", error: nil) == .loaded else {
                        logger.error("Failed to load asset for: \(name)")
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
                                    logger.info("AVPlayerItem ready for playback: \(name)")
                                    self?.playerItemObservers[name] = nil
                                } else if item.status == .failed {
                                    logger.error("AVPlayerItem failed for: \(name), error: \(String(describing: item.error))")
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
                                        logger.info("Looping video in VideoManager: \(name)")
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
    
    /// Preloads videos to improve playback performance.
    /// - Parameters:
    ///   - names: An array of video file names to preload.
    ///   - queue: The dispatch queue for preloading. Defaults to `.background`.
    public func preloadVideos(names: [String], queue: VideoAssetQueue = .background) {
        for name in names {
            if playerCache[name] == nil, preloadTasks[name] == nil {
                preloadTasks[name] = Task {
                    let player = await self.getPlayer(for: name, loop: true, assetQueue: queue)
                    self.preloadTasks[name] = nil
                    logger.info("Preloaded video: \(name)")
                    self.logPlayerState(player, name: name)
                }
            }
        }
    }
    
    /// Pauses all cached videos.
    public func pauseAllVideos() async {
        for (name, player) in playerCache {
            logger.info("Pausing video: \(name)")
            player.pause()
        }
    }
    
    /// Resumes playback for all active videos.
    public func resumeAllVideos() async {
        for (name, player) in playerCache {
            if let controller = activeControllers[name]?.value, controller.player == player, player.currentItem?.status == .readyToPlay {
                logger.info("Resuming video: \(name)")
                player.play()
            } else {
                logger.info("Not resuming video \(name): not displayed or not ready")
            }
        }
    }
    
    /// Clears all cached resources and observers.
    public func clearCache() {
        for (name, observer) in loopObservers {
            observer.remove()
            logger.info("Removed loop observer for: \(name)")
        }
        loopObservers.removeAll()
        playerCache.removeAll()
        activeControllers.removeAll()
        playerItemObservers.removeAll()
        logger.info("Cache cleared")
    }
    
    /// Clears cached resources for inactive videos in response to memory warnings.
    public func softClearCache() {
        logger.info("Received memory warning")
        
        let activeNames = Set(activeControllers.keys)
        
        for name in playerCache.keys {
            if !activeNames.contains(name) {
                playerCache[name]?.pause()
                playerCache[name] = nil
                loopObservers[name]?.remove()
                loopObservers[name] = nil
                logger.info("Removed inactive video: \(name)")
            }
        }
    }
    
    /// Logs the state of an `AVPlayer` for debugging.
    /// - Parameters:
    ///   - player: The `AVPlayer` to inspect.
    ///   - name: The name of the video associated with the player.
    private func logPlayerState(_ player: AVPlayer, name: String) {
        if let item = player.currentItem {
            switch item.status {
            case .unknown:
                logger.info("Player state for \(name): Unknown")
            case .readyToPlay:
                logger.info("Player state for \(name): Ready to play")
            case .failed:
                logger.error("Player state for \(name): Failed, error: \(String(describing: item.error))")
            @unknown default:
                logger.info("Player state for \(name): Unknown status")
            }
        } else {
            logger.info("Player state for \(name): No current item")
        }
    }
    
    /// Cleans up all observers and resources.
    @MainActor
    private func cleanupObservers() {
        NotificationCenter.default.removeObserver(self)
        for (name, observer) in loopObservers {
            observer.remove()
            logger.info("Removed loop observer for: \(name)")
        }
        loopObservers.removeAll()
        logger.info("VideoManager deinit")
    }
    
    deinit {
        DispatchQueue.main.async { [weak self] in
            self?.cleanupObservers()
        }
    }
}
