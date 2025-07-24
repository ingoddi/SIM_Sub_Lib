import SwiftUI
import AVFoundation
import Foundation

/// Приоритет загрузки и обработки видео
public enum CelestialVideoPriority: Int {
    /// Видео на кнопках (загружается сразу в главной очереди)
    case button = 0
    /// Видео фона (загружается с высоким приоритетом)
    case background = 1
    /// Видео коллекций или вспомогательных элементов (низкий приоритет)
    case collection = 2

    /// Возвращает соответствующий QoS для GCD
    public var qos: DispatchQoS.QoSClass {
        switch self {
        case .button:
            return .userInteractive
        case .background:
            return .userInitiated
        case .collection:
            return .utility
        }
    }
}


public struct CelestialVideoView: UIViewRepresentable {
    private let name: String
    private let cornerRadius: CGFloat
    private let gravity: AVLayerVideoGravity
    private let priority: CelestialVideoPriority

    public init(name: String,
                cornerRadius: CGFloat = 0,
                gravity: AVLayerVideoGravity = .resizeAspectFill,
                priority: CelestialVideoPriority = .background) {
        self.name = name
        self.cornerRadius = cornerRadius
        self.gravity = gravity
        self.priority = priority
    }

    public func makeUIView(context: Context) -> VideoContainerView {
        print("🎬 makeUIView for video: \(name)")
        let view = VideoContainerView(cornerRadius: cornerRadius)
        view.backgroundColor = .clear
        loadVideo(into: view)
        return view
    }

    public func updateUIView(_ uiView: VideoContainerView, context: Context) {
        print("🔄 updateUIView for video: \(name)")
        uiView.updateLayout()
    }

    private func loadVideo(into view: VideoContainerView) {
        let block: @Sendable () -> Void = {
            guard let player = CelestialVideoCache.shared.player(for: name) else {
                print("❌ No player available for \(name)")
                return
            }
            DispatchQueue.main.async {
                view.setPlayer(player, gravity: gravity)
            }
        }

        if priority == .button {
            print("⚡ Button priority → loading immediately")
            block()
        } else {
            print("⏳ Loading with qos: \(priority.qos)")
            DispatchQueue.global(qos: priority.qos).async(execute: block)
        }
    }
}
