import SwiftUI

@MainActor
public class OnboardingFlowModel: ObservableObject {
    @Published public var currentStep: Int = 0
    public let totalSteps: Int

    public init(totalSteps: Int) {
        self.totalSteps = totalSteps
    }

    public func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }
}

