import SwiftUI

public struct ClearVideoCacheModifier: ViewModifier {
    private let clearAction: () -> Void

    public init(clearAction: @escaping () -> Void = {
        CelestialVideoCache.shared.clearAll()
    }) {
        self.clearAction = clearAction
    }

    public func body(content: Content) -> some View {
        content.onDisappear {
            clearAction()
        }
    }
}

public struct BackgroundCleanerModifier: ViewModifier {
    let stepIndex: Int
    @Binding var previousVideo: String?
    
    public func body(content: Content) -> some View {
        content.onAppear {
            if let oldVideo = previousVideo {
                CelestialVideoCache.shared.clear(name: oldVideo)
            }
            
            if let rootView = Mirror(reflecting: content).descendant("backgroundVideoName") as? String {
                previousVideo = rootView
            } else {
                previousVideo = nil
            }
        }
    }
}

public struct AnyOnboardingStep: OnboardingStepScreen {
    public var nextAction: (() -> Void)?
    public let backgroundVideoName: String
    private let viewBuilder: () -> AnyView

    public init<Step: OnboardingStepScreen>(_ step: Step) {
        self.nextAction = step.nextAction
        self.backgroundVideoName = step.backgroundVideoName
        self.viewBuilder = { AnyView(step) }
    }

    public var body: some View {
        viewBuilder()
    }
}
