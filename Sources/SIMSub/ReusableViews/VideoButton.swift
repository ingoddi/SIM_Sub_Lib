import SwiftUI

public struct VideoButton: View {
    // MARK: - Параметры
    private let videoName: String
    private let maskImageName: String?
    private let pressedImageName: String?
    private let action: () -> Void

    private let width: CGFloat?
    private let height: CGFloat?
    private let expandHitAreaPercent: CGFloat
    private let showHitAreaDebug: Bool
    private let cornerRadius: CGFloat
    private let priority: CelestialVideoPriority

    // MARK: - Состояние
    @State private var isPressed: Bool = false

    // MARK: - Инициализация
    public init(
        videoName: String,
        maskImageName: String? = nil,
        pressedImageName: String? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = 0,
        expandHitAreaPercent: CGFloat = 0.1,
        showHitAreaDebug: Bool = false,
        priority: CelestialVideoPriority = .button,
        action: @escaping () -> Void
    ) {
        self.videoName = videoName
        self.maskImageName = maskImageName
        self.pressedImageName = pressedImageName
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.expandHitAreaPercent = expandHitAreaPercent
        self.showHitAreaDebug = showHitAreaDebug
        self.priority = priority
        self.action = action
    }

    // MARK: - Body
    public var body: some View {
        GeometryReader { geo in
            let hitWidth = geo.size.width * (1 + expandHitAreaPercent * 2)
            let hitHeight = geo.size.height * (1 + expandHitAreaPercent * 2)

            ZStack {
                if isPressed, let pressedImageName = pressedImageName {
                    Image(pressedImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .applyMask(maskImageName)
                } else {
                    CelestialVideoView(
                        name: videoName,
                        cornerRadius: cornerRadius,
                        gravity: .resizeAspectFill,
                        priority: priority
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .applyMask(maskImageName)
                }
            }
            .frame(width: width ?? geo.size.width, height: height ?? geo.size.height)
            .contentShape(Rectangle()
                .inset(by: -max(hitWidth - geo.size.width, hitHeight - geo.size.height) / 2)
            )
            .background(showHitAreaDebug ? Color.red.opacity(0.2) : Color.clear)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Mask Modifier
fileprivate extension View {
    @ViewBuilder
    func applyMask(_ maskName: String?) -> some View {
        if let maskName = maskName {
            self.mask(
                Image(maskName)
                    .resizable()
                    .scaledToFit()
            )
        } else {
            self
        }
    }
}
