import SwiftUI


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
