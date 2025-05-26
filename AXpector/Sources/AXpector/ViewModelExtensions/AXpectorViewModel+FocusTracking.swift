import SwiftUI // For @MainActor
import AppKit // For NSWorkspace, NSRunningApplication, AXUIElement, AXObserver, pid_t
import AXorcist // For AXorcist.Element
import Defaults // ADDED
// import OSLog // For Logger // REMOVE OSLog
// AXorcist import already includes logging utilities

// MARK: - Focus Tracking Implementation
extension AXpectorViewModel {
    internal func startFocusTrackingMonitoring() {
        axInfoLog("AXpectorViewModel: Requesting to start focus tracking monitoring.") // CHANGED

        if appActivationObserver == nil {
            appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, 
                object: nil, 
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in // Run the whole handler on MainActor
                    guard let self = self else { return } 
                    guard self.isFocusTrackingModeActive,
                          let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                        return
                    }
                    axInfoLog("App activated: \(activatedApp.localizedName ?? "unknown") with PID \(activatedApp.processIdentifier). AXpector will update focus tracking.") // CHANGED
                    
                    let pidToObserve = self.selectedApplicationPID ?? activatedApp.processIdentifier
                    // The axorcist.startFocusTracking is async, so it's fine here.
                    _ = self.axorcist.startFocusTracking(for: pidToObserve, callback: self.handleFocusNotificationFromAXorcist)
                }
            }
        }

        Task {
            if let pid = selectedApplicationPID {
                // AXorcist.startFocusTracking uses ax...Log internally
                _ = axorcist.startFocusTracking(for: pid, callback: self.handleFocusNotificationFromAXorcist)
            } else if let frontmostApp = NSWorkspace.shared.frontmostApplication {
                // AXorcist.startFocusTracking uses ax...Log internally
                _ = axorcist.startFocusTracking(for: frontmostApp.processIdentifier, callback: self.handleFocusNotificationFromAXorcist)
            } else {
                axWarningLog("Focus Tracking: No application selected and no frontmost application found to observe.") // CHANGED
            }
        }
    }

    internal func stopFocusTrackingMonitoring() {
        axInfoLog("AXpectorViewModel: Requesting to stop focus tracking monitoring.") // CHANGED
        Task {
            // AXorcist.stopFocusTracking uses ax...Log internally
            axorcist.stopFocusTracking()
        }
    }

    @MainActor
    private func handleFocusNotificationFromAXorcist(focusedElement: Element, pid: pid_t, notification: AXNotification) {
        axDebugLog("AXpectorVM.handleFocusNotification: Element: \(focusedElement.briefDescription()), PID: \(pid), Notification: \(notification.rawValue)")
        
        Task { // WRAP async work in Task
            // Ensure we are on the main actor for UI updates if necessary, though most of this is data processing.
            // The original function was @MainActor, so this Task inherits that context.
            
            let (fetchedAttributes, _) = await getElementAttributes(
                element: focusedElement, 
                attributes: Self.defaultFetchAttributes, 
                outputFormat: .jsonString 
            )

            let newNode = AXPropertyNode(
                id: UUID(), // Generate a new ID for this focused element representation
                axElementRef: focusedElement.underlyingElement,
                pid: pid,
                role: fetchedAttributes[AXAttributeNames.kAXRoleAttribute]?.value as? String ?? "UnknownRole",
                title: fetchedAttributes[AXAttributeNames.kAXTitleAttribute]?.value as? String ?? "UnknownTitle",
                descriptionText: fetchedAttributes[AXAttributeNames.kAXDescriptionAttribute]?.value as? String ?? "",
                value: fetchedAttributes[AXAttributeNames.kAXValueAttribute]?.value as? String ?? "",
                fullPath: "focused://\(focusedElement.briefDescription())", // Create a pseudo-path
                children: [], // Focused elements are typically not expanded for children here
                attributes: fetchedAttributes,
                actions: focusedElement.supportedActions() ?? [],
                hasChildrenAXProperty: (focusedElement.children()?.count ?? 0) > 0,
                depth: 0 // Treat as a root for display purposes in the focus log
            )
            
            // Update the focused elements log
            self.focusedElementsLog.append(newNode)
            if self.focusedElementsLog.count > 20 { // Keep the log trimmed
                self.focusedElementsLog.removeFirst()
            }
            
            // If focus tracking also implies selecting in the main tree
            if Defaults[.selectTreeOnFocusChange], let mainTreeRoot = self.accessibilityTree.first, mainTreeRoot.pid == pid {
                if let existingNode = findNodeByAXElement(focusedElement.underlyingElement, in: [mainTreeRoot]) {
                    self.selectedNode = existingNode
                    self.scrollToSelectedNode = existingNode.id // Trigger scroll
                    self.updateHighlightForNode(existingNode, isHover: false, isFocusHighlight: true)
                } else {
                     axDebugLog("Focused element not found in main tree for selection.")
                }
            }
            // Ensure UI updates if selectedNode or logs changed by publishing changes.
            // self.objectWillChange.send() // This is often handled by @Published
        }
    }
} 