import SwiftUI // For @MainActor
import AXorcist // For AXPermissions
// import OSLog // For Logger // REMOVE OSLog
// AXorcist import already includes logging utilities

// MARK: - Accessibility Permissions Check
extension AXpectorViewModel {
    func checkAccessibilityPermissions(promptIfNeeded: Bool = false) {
        let trusted = AXTrustUtil.checkAccessibilityPermissions(promptIfNeeded: promptIfNeeded)
        
        if self.isAccessibilityEnabled != trusted { 
            self.isAccessibilityEnabled = trusted
            if trusted {
                axInfoLog("Accessibility API is enabled.")
            } else {
                axWarningLog("Accessibility API is NOT enabled. AXpector functionality will be limited.")
            }
        } else if isAccessibilityEnabled == nil { 
            self.isAccessibilityEnabled = trusted 
            if trusted {
                axInfoLog("Accessibility API is enabled (initial/nil check).")
            } else {
                 axWarningLog("Accessibility API is NOT enabled (initial/nil check). AXpector functionality will be limited.")
            }
        }
    }
} 