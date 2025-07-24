import SwiftUI
import StoreKit

public typealias OnboardingStepScreen = OnboardingStepScreenWithNextAction & OnboardingVideoBackgroundProvider

public protocol SubscriptionsProductProtocol {
    var productId: String { get }
}

public protocol OnboardingStepScreenWithNextAction: View {
    var nextAction: (() -> Void)? { get set }
}

@available(iOS 15.0, *)
public protocol SubscriptionPaywallScreen: View {
    var onSkip: (() -> Void)? { get set }
    var startPurchase: ((_ product: Product) -> Void)? { get set }
    var startRestore: (() -> Void)? { get set }
    var availableProducts: [Product] { get set }
}


public protocol OnboardingVideoBackgroundProvider {
    var backgroundVideoName: String { get }
}
