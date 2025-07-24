import AVFoundation

public final class CelestialVideoCache: @unchecked Sendable {
    public static let shared = CelestialVideoCache()

    private var cache: [String: AVPlayerLooper] = [:]
    private var players: [String: AVQueuePlayer] = [:]
    private let lock = NSLock()

    private init() {}

    /// Получение плеера (создаётся только один раз)
    public func player(for name: String) -> AVQueuePlayer? {
        lock.lock()
        if let player = players[name] {
            print("♻️ Cache hit for video: \(name)")
            lock.unlock()
            return player
        }
        lock.unlock()

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
            print("❌ Video not found: \(name).mp4")
            return nil
        }

        print("📂 Loading video: \(name)")
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: item)

        lock.lock()
        players[name] = player
        cache[name] = looper
        lock.unlock()

        // запускаем сразу — он готов, даже если слой появится позже
        DispatchQueue.main.async { player.play() }
        return player
    }

    /// Полностью очищает кэш
    public func clearAll() {
        lock.lock()
        print("🧹 Clearing ALL videos")
        players.removeAll()
        cache.removeAll()
        lock.unlock()
    }

    /// Удаляет конкретное видео
    public func clear(name: String) {
        lock.lock()
        print("🧹 Clearing video: \(name)")
        players.removeValue(forKey: name)
        cache.removeValue(forKey: name)
        lock.unlock()
    }

    /// Прогрузка видео заранее (без старта слоя)
    public func preload(name: String) {
        DispatchQueue.global(qos: .utility).async {
            _ = self.player(for: name)
        }
    }
}
