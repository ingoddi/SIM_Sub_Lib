import Adjust
import PushwooshFramework
import AppTrackingTransparency
import AdSupport


@MainActor
public final class AnalyticsIntegrateService {
    
    public static let shared = AnalyticsIntegrateService()
    private init() {}
    
    public func initializeAdjust(adjustConfigKey: String) {
#if DEBUG
        let environment = (ADJEnvironmentSandbox as? String)!
#else
        let environment = (ADJEnvironmentProduction as? String)!
#endif
        let adjustConfig = ADJConfig(appToken: adjustConfigKey, environment: environment)
        
        adjustConfig?.logLevel = ADJLogLevelVerbose
        Adjust.appDidLaunch(adjustConfig)
    }
    
    public func initializePushwoosh(delegate: PWMessagingDelegate, pushwooshToken: String, pushwooshAppName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Pushwoosh.sharedInstance().delegate = delegate;
            PushNotificationManager.initialize(withAppCode: pushwooshToken, appName: pushwooshAppName)
            PWInAppManager.shared().resetBusinessCasesFrequencyCapping()
            PWGDPRManager.shared().showGDPRDeletionUI()
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    public func makeATTAlert() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("Authorized")
                    let idfa = ASIdentifierManager.shared().advertisingIdentifier
                    print("UserAccess Succesful. IDFA: ", idfa)
                    let authorizationStatus = Adjust.appTrackingAuthorizationStatus()
                    Adjust.updateConversionValue(Int(authorizationStatus))
                    Adjust.checkForNewAttStatus()
                    print(ASIdentifierManager.shared().advertisingIdentifier)
                case .denied:
                    print("Denied")
                case .notDetermined:
                    print("Not Determined")
                case .restricted:
                    print("Restricted")
                @unknown default:
                    print("Unknown")
                }
            }
        }
    }
    
    public func makePushAlert() {
        DispatchQueue.main.async() {
            Pushwoosh.sharedInstance().registerForPushNotifications()
        }
    }
    
}
