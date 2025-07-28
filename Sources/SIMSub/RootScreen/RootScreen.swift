import SwiftUI
import StoreKit

@available(iOS 15.0, *)
public struct RootScreen<
    OnboardingContainer: View,
    PaywallScreen: SubscriptionPaywallScreen,
    MainContent: View
>: View {
    
    @EnvironmentObject var subManager: SK2SubscriptionManager
    @EnvironmentObject var audioManager: AudioManagerService
    @Environment(\.scenePhase) private var scenePhase
    
    let onboardingContainer: () -> OnboardingContainer
    
    let paywallScreen: (
        [Product], // список продуктов
        @escaping (Product) -> Void, // покупка
        @escaping () -> Void, // restore
        @escaping () -> Void  // skip
    ) -> PaywallScreen
    
    let mainContent: () -> MainContent
    
    @State private var showPaywall: Bool = false
    
    public init(
        onboardingContainer: @escaping () -> OnboardingContainer,
        paywallScreen: @escaping (
            [Product],
            @escaping (Product) -> Void,
            @escaping () -> Void,
            @escaping () -> Void
        ) -> PaywallScreen,
        @ViewBuilder mainContent: @escaping () -> MainContent
    ) {
        self.onboardingContainer = onboardingContainer
        self.paywallScreen = paywallScreen
        self.mainContent = mainContent
    }
    
    public var body: some View {
        ZStack {
            if subManager.isSubscribed || subManager.isPaywallSkipped {
                mainContent()
            } else {
                onboardingContainer()
                    .onOnboardingFinished {
                        DispatchQueue.main.async {
                            subManager.showSubscription = true
                        }
                    }
            }

            if subManager.showSubscription {
                paywallScreen(
                    subManager.products,
                    { product in
                        Task {
                            await subManager.purchase(product)
                            if subManager.isSubscribed {
                                subManager.showSubscription = false
                            }
                        }
                    },
                    {
                        Task {
                            await subManager.restore()
                            if subManager.isSubscribed {
                                subManager.showSubscription = false
                            }
                        }
                    },
                    {
                        subManager.isPaywallSkipped = true
                        subManager.showSubscription = false
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .zIndex(1000)
                .onAppear { audioManager.playbackStartet() }
                .onDisappear { audioManager.playbackPauseу() }
            }
        }
        .animation(.easeInOut, value: subManager.showSubscription)
        .onChange(of: subManager.isSubscribed) { _ in updateAudioPlayback() }
        .onChange(of: subManager.isPaywallSkipped) { _ in updateAudioPlayback() }
        .onAppear { updateAudioPlayback() }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active, .inactive:
                updateAudioPlayback()
            case .background:
                audioManager.playbackPauseу()
            @unknown default:
                break
            }
        }
        .alert(item: $subManager.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    subManager.alert = nil
                }
            )
        }
    }



    
    
    private func updateAudioPlayback() {
        if subManager.isSubscribed || subManager.isPaywallSkipped {
            // Мы в Main
            if subManager.showSubscription {
                audioManager.playbackStartet()   // Paywall поверх Main
            } else {
                audioManager.playbackPauseу()   // Чистый Main
            }
        } else {
            // Onboarding + обычный Paywall
            audioManager.playbackStartet()
        }
    }
    
    
}

// MARK: - Onboarding Finished Environment

public struct OnOnboardingFinishedKey: EnvironmentKey {
    public static let defaultValue: @Sendable () -> Void = {}
}

public extension EnvironmentValues {
    var onOnboardingFinished: @Sendable () -> Void {
        get { self[OnOnboardingFinishedKey.self] }
        set { self[OnOnboardingFinishedKey.self] = newValue }
    }
}

public extension View {
    func onOnboardingFinished(_ action: @escaping @Sendable () -> Void) -> some View {
        environment(\.onOnboardingFinished, action)
    }
}
