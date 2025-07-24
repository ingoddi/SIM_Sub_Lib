import Foundation

public enum SubscriptionAlert: Identifiable, Equatable {
    case restoreSuccess
    case restoreFailed(String)
    case generalError(String)
    
    public var id: String {
        switch self {
        case .restoreSuccess: return "restoreSuccess"
        case .restoreFailed(let msg): return "restoreFailed-\(msg)"
        case .generalError(let msg): return "generalError-\(msg)"
        }
    }
    
    public var title: String {
        switch self {
        case .restoreSuccess:
            return "Purchases Restored"
        case .restoreFailed:
            return "Restore Failed"
        case .generalError:
            return "Error"
        }
    }
    
    public var message: String {
        switch self {
        case .restoreSuccess:
            return "Your previous purchases have been successfully restored."
        case .restoreFailed(let msg), .generalError(let msg):
            return msg
        }
    }
}

