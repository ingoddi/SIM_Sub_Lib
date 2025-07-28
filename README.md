

# Onboarding and RootScreen Integration Guide

This guide explains how to use the `RootScreen` view, set it up in your main `App` struct, and create an onboarding flow using the provided SwiftUI-based codebase. The code is designed to handle an onboarding experience with video playback, a subscription paywall, and a main content screen, as seen in the provided files (`RootScreen.swift`, `OnboardingSteps.swift`, `Onboarding.swift`, `SIM_Sub_LibApp.swift`, and `VideoView.swift`).

## Table of Contents
1. [Overview](#overview)
2. [Setting Up the App](#setting-up-the-app)
3. [Using RootScreen](#using-rootscreen)
4. [Creating the Onboarding Flow](#creating-the-onboarding-flow)
5. [Customizing Onboarding Steps](#customizing-onboarding-steps)
6. [Video Playback in Onboarding](#video-playback-in-onboarding)
7. [Handling Subscriptions](#handling-subscriptions)
8. [Testing and Debugging](#testing-and-debugging)
9. [Best Practices](#best-practices)

## Overview

The app uses a modular structure to manage an onboarding flow, subscription paywall, and main content screen. Key components include:

- **`RootScreen`**: The top-level view that orchestrates the app’s flow, showing either the onboarding, paywall, or main content based on the user’s subscription status.
- **`OnboardingContainer`**: Manages a sequence of onboarding screens with a sliding transition and a video-based navigation button.
- **`OnboardingSteps`**: Individual screens (`Step1`, `Step2`, `Step3`) that display background videos and, in the case of `Step3`, interactive video grid items.
- **`VideoView`**: Handles video playback and looping for onboarding screens and interactive elements.
- **`SK2SubscriptionManager`**: Manages in-app subscriptions and paywall logic.
- **`AudioManagerService`**: Controls background audio playback during onboarding and paywall screens.

The app supports iOS 15.0 and later, using SwiftUI, StoreKit, and AVKit for video playback. It also integrates analytics (Adjust) and push notifications (Pushwoosh).

## Setting Up the App

To set up the app, configure the main `App` struct (e.g., `SIM_Sub_LibApp`) to initialize dependencies and integrate `RootScreen`. Here’s how to do it:

1. **Define Dependencies**:
   - Create instances of `SK2SubscriptionManager`, `AudioManagerService`, and `OnboardingFlowModel` as `@StateObject` properties in your `App` struct.
   - `SK2SubscriptionManager` requires product IDs for subscriptions (e.g., `DemoSubscriptionProduct`).
   - `AudioManagerService` requires the name and format of the background audio file.
   - `OnboardingFlowModel` requires the total number of onboarding steps.

2. **Configure `RootScreen`**:
   - Pass closures to `RootScreen` for `onboardingContainer`, `paywallScreen`, and `mainContent`.
   - Inject dependencies (`subManager`, `audioManager`) as environment objects.

3. **Example `App` Struct** (based on `SIM_Sub_LibApp.swift`):

```swift
import SwiftUI
import SIMSub

@main
struct MyApp: App {
    @StateObject private var subManager = SK2SubscriptionManager(
        productIds: DemoSubscriptionProduct.allCases.map { $0.productId }
    )
    @StateObject private var audioManager = AudioManagerService(
        musicResourceName: "musicFileName",
        formatMusic: .wav
    )
    @StateObject private var flow = OnboardingFlowModel(totalSteps: 3)

    var body: some Scene {
        WindowGroup {
            RootScreen<
                OnboardingContainer,
                MyPaywallScreen,
                MainScreen
            >(
                onboardingContainer: {
                    OnboardingContainer(
                        flowModel: flow,
                        screens: [
                            AnyOnboardingStep(Step1(nextAction: flow.nextStep)),
                            AnyOnboardingStep(Step2(nextAction: flow.nextStep)),
                            AnyOnboardingStep(Step3(nextAction: flow.nextStep))
                        ]
                    )
                },
                paywallScreen: { products, onPurchase, onRestore, onSkip in
                    MyPaywallScreen(
                        onSkip: onSkip,
                        startPurchase: onPurchase,
                        startRestore: onRestore,
                        availableProducts: products
                    )
                },
                mainContent: {
                    MainScreen()
                }
            )
            .environmentObject(subManager)
            .environmentObject(audioManager)
        }
    }
}
```

4. **AppDelegate Setup**:
   - If using analytics or push notifications, configure `AppDelegate` as shown in `SIM_Sub_LibApp.swift` for Adjust and Pushwoosh integration.
   - Ensure `UIApplicationDelegateAdaptor` is set up to handle app lifecycle events.

5. **Bundle Configuration**:
   - Add video files (e.g., `EmpyreanChorusMysticSerenityQuest.mp4`, `AstralRadianceEternalEchoSymphony.mp4`) and audio files (e.g., `CelestialOdysseySpectralFluxRebirth.wav`) to the app bundle.
   - Update `AppConstants` with your actual subscription product IDs, Adjust configuration, Pushwoosh token, and URLs for terms and privacy policies.

## Using RootScreen

`RootScreen` is a generic SwiftUI view that manages the app’s flow, showing the onboarding, paywall, or main content based on the user’s subscription status (`SK2SubscriptionManager`).

### Key Features
- **Conditional Display**: Shows `onboardingContainer` if the user is not subscribed and hasn’t skipped the paywall. Shows `paywallScreen` when `subManager.showSubscription` is `true`. Shows `mainContent` if subscribed or paywall is skipped.
- **Subscription Integration**: Uses `SK2SubscriptionManager` to handle purchases, restores, and skipping the paywall.
- **Audio Management**: Integrates with `AudioManagerService` to play/pause background audio based on the current screen.
- **Scene Phase Handling**: Pauses audio in the background and resumes it when active.

### Configuration
- **Generics**:
  - `OnboardingContainer`: The view for the onboarding flow (e.g., `OnboardingContainer`).
  - `PaywallScreen`: The subscription paywall view (e.g., `MyPaywallScreen`).
  - `MainContent`: The main app content view (e.g., `MainScreen`).
- **Parameters**:
  - `onboardingContainer`: A closure returning the onboarding view.
  - `paywallScreen`: A closure that takes products, purchase, restore, and skip callbacks to return the paywall view.
  - `mainContent`: A closure returning the main content view.
- **Environment Objects**:
  - Inject `SK2SubscriptionManager` and `AudioManagerService` using `.environmentObject`.

### Example Usage
See the `SIM_Sub_LibApp.swift` example above for how to initialize `RootScreen` with `OnboardingContainer`, `MyPaywallScreen`, and `MainScreen`.

## Creating the Onboarding Flow

The onboarding flow is managed by `OnboardingContainer` and `OnboardingFlowModel`, with individual steps defined in `OnboardingSteps.swift`. Here’s how to create and customize the onboarding flow:

1. **Define Onboarding Steps**:
   - Create structs conforming to `OnboardingStepScreen` (a protocol not shown but implied in `OnboardingSteps.swift`).
   - Each step should have a `body` view and an optional `nextAction` closure to advance to the next step.
   - Example from `Step1`:

```swift
struct Step1: OnboardingStepScreen {
    var nextAction: (() -> Void)?
    let backgroundVideoName = "EmpyreanChorusMysticSerenityQuest"
    
    var body: some View {
        VideoSimpleView(
            name: backgroundVideoName,
            gravity: .resizeAspectFill,
            loop: true,
            assetQueue: .main
        )
        .ignoresSafeArea()
    }
}
```

2. **Set Up `OnboardingFlowModel`**:
   - Initialize with the total number of steps: `@StateObject private var flow = OnboardingFlowModel(totalSteps: 3)`.
   - Use `flow.nextStep` to advance to the next step in each screen’s `nextAction`.

3. **Configure `OnboardingContainer`**:
   - Pass the `flowModel` and an array of `AnyOnboardingStep` wrapping each step.
   - Example from `SIM_Sub_LibApp.swift`:

```swift
OnboardingContainer(
    flowModel: flow,
    screens: [
        AnyOnboardingStep(Step1(nextAction: flow.nextStep)),
        AnyOnboardingStep(Step2(nextAction: flow.nextStep)),
        AnyOnboardingStep(Step3(nextAction: flow.nextStep))
    ]
)
```

4. **Add Navigation Button**:
   - `OnboardingContainer` includes a `VideoButton` with a video (`AstralRadianceEternalEchoSymphony`) that triggers `handleNext` to advance or complete the onboarding.
   - Customize the button’s appearance by modifying `VideoButton` parameters (e.g., `maskImageName`, `pressedImageName`, `height`).

5. **Handle Onboarding Completion**:
   - Use the `onOnboardingFinished` environment key to trigger the paywall when onboarding completes.
   - Example in `RootScreen`:

```swift
onboardingContainer()
    .onOnboardingFinished {
        DispatchQueue.main.async {
            subManager.showSubscription = true
        }
    }
```

## Customizing Onboarding Steps

Each onboarding step can be customized to include videos, images, text, or interactive elements. Examples from `OnboardingSteps.swift`:

- **Step1 and Step2**: Display full-screen looping background videos using `VideoSimpleView`.
- **Step3**: Combines a background video with a grid of interactive `VideoGridItem` views that toggle between cover images and looping videos.

### Creating a New Step
1. Create a new struct conforming to `OnboardingStepScreen`:

```swift
struct Step4: OnboardingStepScreen {
    var nextAction: (() -> Void)?
    let backgroundVideoName = "NewVideoName"
    
    var body: some View {
        ZStack {
            VideoSimpleView(
                name: backgroundVideoName,
                gravity: .resizeAspectFill,
                loop: true,
                assetQueue: .main
            )
            .ignoresSafeArea()
            
            VStack {
                Text("Welcome to Step 4")
                    .font(.title)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
        }
    }
}
```

2. Add the step to `OnboardingContainer` in the `App` struct:

```swift
OnboardingContainer(
    flowModel: flow,
    screens: [
        AnyOnboardingStep(Step1(nextAction: flow.nextStep)),
        AnyOnboardingStep(Step2(nextAction: flow.nextStep)),
        AnyOnboardingStep(Step3(nextAction: flow.nextStep)),
        AnyOnboardingStep(Step4(nextAction: flow.nextStep))
    ]
)
```

3. Update `OnboardingFlowModel`’s `totalSteps`: `@StateObject private var flow = OnboardingFlowModel(totalSteps: 4)`.

### Customizing VideoGridItem
For interactive video grids like in `Step3`, modify `VideoGridItem` to adjust appearance or behavior:

- Change `cornerRadius`, `itemWidth`, or `itemHeight` in `Step3`.
- Update `cellVideos` and `cellCovers` arrays to include new videos or cover images.
- Adjust the `.onAppear` modifier in `VideoGridItem` to optimize video playback (already included for looping):

```swift
.onAppear {
    Task {
        await VideoManager.shared.getPlayer(for: videoName, loop: true, assetQueue: .utility).play()
    }
}
```

## Video Playback in Onboarding

Video playback is managed by `VideoView.swift`, which ensures videos play and loop correctly. Key considerations:

1. **Video Files**:
   - Ensure all video files (e.g., `EmpyreanChorusMysticSerenityQuest.mp4`, `AstralRadianceEternalEchoSymphony.mp4`) are included in the app bundle.
   - Verify file names match those specified in `backgroundVideoName`, `cellVideos`, and `buttonVideo`.

2. **Performance**:
   - Use `.main` or `.userInitiated` `assetQueue` for background videos to prioritize quick loading.
   - Use `.utility` or `.background` for grid cell videos to reduce resource contention.
   - Preload videos using `VideoManager.shared.preloadVideos(names:)` to improve performance:

```swift
VideoManager.shared.preloadVideos(names: ["Video1", "Video2"], queue: .background)
```

3. **Looping and Playback**:
   - The `VideoManager` ensures videos loop using `LoopObserver` and play when `AVPlayerItem` is ready.
   - Logs are available via `VideoLogger` (uses `os.Logger` on iOS 14.0+, falls back to `print` on earlier versions).

## Handling Subscriptions

Subscriptions are managed by `SK2SubscriptionManager` and displayed via `MyPaywallScreen`. Key points:

1. **Define Product IDs**:
   - Update `DemoSubscriptionProduct` in `SIM_Sub_LibApp.swift` with your actual StoreKit product IDs:

```swift
public enum DemoSubscriptionProduct: String, CaseIterable, SubscriptionsProductProtocol {
    case monthly
    case weekly
    
    public var productId: String {
        switch self {
        case .monthly: return "your.monthly.product.id"
        case .weekly: return "your.weekly.product.id"
        }
    }
}
```

2. **Paywall Integration**:
   - The `paywallScreen` closure in `RootScreen` receives products, purchase, restore, and skip callbacks.
   - Implement `MyPaywallScreen` to display subscription options and handle user interactions.

3. **Subscription Status**:
   - `subManager.isSubscribed` determines whether to show `mainContent` or `onboardingContainer`.
   - `subManager.showSubscription` triggers the paywall.
   - `subManager.isPaywallSkipped` allows bypassing the paywall for testing or free access.

## Testing and Debugging

1. **Verify Onboarding Flow**:
   - Ensure all steps (`Step1`, `Step2`, `Step3`) display correctly with looping videos.
   - Tap the `VideoButton` to advance through steps and trigger the paywall.
   - Test grid cell videos in `Step3` by tapping to toggle between cover images and videos.

2. **Check Video Playback**:
   - Confirm that background videos (`EmpyreanChorusMysticSerenityQuest`, etc.), grid cell videos (`ExcitedJumpPlay`, etc.), and button videos (`AstralRadianceEternalEchoSymphony`) play and loop.
   - Use `VideoLogger` output in Xcode’s Console to debug playback issues (e.g., `AVPlayerItem failed` or `Video file not found`).

3. **Test Subscriptions**:
   - Simulate purchases and restores in `MyPaywallScreen` to verify `subManager.isSubscribed` updates correctly.
   - Test the skip functionality to ensure `subManager.isPaywallSkipped` works.

4. **Audio Playback**:
   - Verify that `AudioManagerService` plays audio during onboarding and paywall, and pauses on the main screen unless the paywall is shown.

5. **Logs**:
   - Check logs in Xcode’s Console or via `os_log` with subsystem `com.example.app` and category `VideoManager`.
   - Replace `com.example.app` in `VideoLogger` with your app’s bundle identifier.

## Best Practices

1. **Optimize Video Performance**:
   - Preload videos in the background to reduce load times.
   - Use appropriate `assetQueue` priorities to balance performance and responsiveness.
   - Ensure video files are optimized (e.g., compressed MP4s) to minimize app size.

2. **Handle Edge Cases**:
   - Test with missing video files to ensure `VideoManager` handles errors gracefully.
   - Simulate low-memory conditions to verify `softClearCache` in `VideoManager`.

3. **Accessibility**:
   - Retain accessibility labels and hints in `VideoGridItem` and other views.
   - Ensure text and buttons are readable with sufficient contrast against video backgrounds.

4. **Subscription Management**:
   - Validate product IDs with StoreKit and test all purchase/restore scenarios.
   - Provide clear UI feedback in `MyPaywallScreen` for purchase errors.

5. **Analytics and Push Notifications**:
   - Configure Adjust and Pushwoosh correctly in `AppDelegate`.
   - Test ATT and push notification prompts to ensure compliance and functionality.

6. **Minimum iOS Version**:
   - The code requires iOS 15.0+ due to `RootScreen`’s availability annotation. For earlier versions, modify `RootScreen` to remove `@available(iOS 15.0, *)` and add compatibility checks.
   - `VideoLogger` handles iOS 13.0 compatibility by falling back to `print`.

## Example Project Structure

```plaintext
MyApp/
├── SIM_Sub_LibApp.swift
├── RootScreen.swift
├── Onboarding.swift
├── OnboardingSteps.swift
├── MainScreen.swift
├── VideoView.swift
├── Assets.xcassets/
│   ├── EmpyreanChorusMysticSerenityQuest.mp4
│   ├── NebularVoyageCelestialHarmonyPulse.mp4
│   ├── TemporalCascadeLuminousShardOdyssey.mp4
│   ├── AstralRadianceEternalEchoSymphony.mp4
│   ├── ExcitedJumpPlay.mp4
│   ├── CoverImage1.png
│   ├── ButtonMask.png
│   ├── pressed.png
│   ├── CelestialOdysseySpectralFluxRebirth.wav
```

This README provides a comprehensive guide to using `RootScreen` and creating an onboarding flow. For further assistance, refer to the code comments in `VideoView.swift` for video playback details or contact the development team.

