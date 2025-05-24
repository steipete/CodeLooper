import SwiftUI // For @MainActor
import AXorcist // For AXPermissions
// import OSLog // For Logger // REMOVE OSLog
// AXorcist import already includes logging utilities

// MARK: - Accessibility Permissions Check
extension AXpectorViewModel {
    func checkAccessibilityPermissions(initialCheck: Bool = false, promptIfNeeded: Bool = false) {
        let trusted = AXTrustUtil.checkAccessibilityPermissions(promptIfNeeded: promptIfNeeded)
        
        let previousState = self.isAccessibilityEnabled
        if self.isAccessibilityEnabled != trusted {
            self.isAccessibilityEnabled = trusted
        }

        if trusted {
            if previousState == false || previousState == nil {
                 axInfoLog("Accessibility API is now enabled.")
            }
        } else {
            if previousState == true || previousState == nil {
                axWarningLog("Accessibility API is NOT enabled. AXpector functionality will be limited.")
            }
            // If this was the initial silent check from init() and permissions are not granted,
            // make a one-time attempt to prompt the user.
            if initialCheck && !promptIfNeeded {
                axInfoLog("Initial check failed, attempting to prompt for Accessibility permissions.")
                // This call will prompt the system if appropriate.
                // We don't need to immediately re-assign 'trusted' or 'isAccessibilityEnabled' here,
                // as the user interaction will be async. The view can use 'Re-check' or will update on next view appearance.
                _ = AXTrustUtil.checkAccessibilityPermissions(promptIfNeeded: true) 
            }
        }
    }
} 