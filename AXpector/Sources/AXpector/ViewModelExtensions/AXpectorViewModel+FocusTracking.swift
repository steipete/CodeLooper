import SwiftUI // For @MainActor
import AppKit // For NSWorkspace, NSRunningApplication, AXUIElement, AXObserver, pid_t
import AXorcist // For AXorcist.Element
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
                guard let self = self, self.isFocusTrackingModeActive,
                      let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                axInfoLog("App activated: \(activatedApp.localizedName ?? "unknown") with PID \(activatedApp.processIdentifier). AXpector will update focus tracking.") // CHANGED
                
                let pidToObserve = self.selectedApplicationPID ?? activatedApp.processIdentifier
                _ = Task {
                    // AXorcist.startFocusTracking uses ax...Log internally
                    await self.axorcist.startFocusTracking(for: pidToObserve, callback: self.handleFocusNotificationFromAXorcist)
                }
            }
        }

        Task {
            if let pid = selectedApplicationPID {
                // AXorcist.startFocusTracking uses ax...Log internally
                _ = await axorcist.startFocusTracking(for: pid, callback: self.handleFocusNotificationFromAXorcist)
            } else if let frontmostApp = NSWorkspace.shared.frontmostApplication {
                // AXorcist.startFocusTracking uses ax...Log internally
                _ = await axorcist.startFocusTracking(for: frontmostApp.processIdentifier, callback: self.handleFocusNotificationFromAXorcist)
            } else {
                axWarningLog("Focus Tracking: No application selected and no frontmost application found to observe.") // CHANGED
            }
        }
    }

    internal func stopFocusTrackingMonitoring() {
        axInfoLog("AXpectorViewModel: Requesting to stop focus tracking monitoring.") // CHANGED
        Task {
            // AXorcist.stopFocusTracking uses ax...Log internally
            _ = await axorcist.stopFocusTracking()
        }
    }

    private func handleFocusNotificationFromAXorcist(focusedElement: AXUIElement, pid: pid_t) {
        axDebugLog("AXpectorVM.handleFocusNotification: Element: \(focusedElement), PID: \(pid)") // CHANGED
        
        if let selectedPID = selectedApplicationPID, selectedPID != pid {
            axInfoLog("Focus change in PID \(pid) ignored as different PID (\(selectedPID)) is selected in AXpector.") // CHANGED
            if temporarilySelectedNodeIDByFocus != nil { temporarilySelectedNodeIDByFocus = nil; highlightWindowController.hideHighlight() }
            return
        }

        if selectedApplicationPID == nil {
            let appNameForInfo = runningApplications.first(where: { $0.processIdentifier == pid })?.localizedName ?? "App PID \(pid)"
            if self.accessibilityTree.first?.pid != pid {
                if autoSelectFocusedApp {
                    axInfoLog("Focus in app (\(appNameForInfo)) not currently selected. Auto-selecting and fetching tree.") // CHANGED
                    self.selectedApplicationPID = pid // This will trigger fetchAccessibilityTreeForSelectedApp
                } else {
                    axInfoLog("Focus in app (\(appNameForInfo)) not currently selected. Auto-select disabled. Update info message.") // CHANGED
                    self.focusedElementInfo = "Focused: \(appNameForInfo) - Tree not loaded. Select to inspect."
                    if self.temporarilySelectedNodeIDByFocus != nil { self.temporarilySelectedNodeIDByFocus = nil; self.highlightWindowController.hideHighlight() }
                    return
                }
            }
        }

        let axLibElement = AXorcist.Element(focusedElement) // CHANGED from AXElement to AXorcist.Element
        let appElementForPath = AXUIElementCreateApplication(pid)

        let role = axLibElement.role()
        let title = axLibElement.title()
        let pathArray = axLibElement.generatePathArray(upTo: appElementForPath)
        CFRelease(appElementForPath)
        // PathComponent in AXorcist.Element's Path struct might have a better string representation.
        // Assuming generatePathArray returns [String] for now, or that Path.PathComponent.description is suitable.
        // For now, using map { $0.isEmpty ? "(empty)" : $0 } as was originally there for String arrays.
        let pathString = pathArray.map { $0.description.isEmpty ? "(empty)" : $0.description }.joined(separator: " / ") // Adjusted if pathArray is [PathComponent]

        var infoParts: [String] = []
        infoParts.append("Focused Path: \(pathString)")
        if let r = role, !r.isEmpty { infoParts.append("Role: \(r)") }
        if let t = title, !t.isEmpty { infoParts.append("Title: \(t)") }
        self.focusedElementInfo = infoParts.joined(separator: "\n")

        if let appTree = self.accessibilityTree.first, appTree.pid == pid, 
           let foundNode = findNodeByAXElement(focusedElement, in: [appTree]) { 
            self.temporarilySelectedNodeIDByFocus = foundNode.id 
            _ = expandParents(for: foundNode.id, in: self.accessibilityTree) 
            updateHighlightForNode(foundNode, isFocusHighlight: true) 
            axInfoLog("Focus tracked to node: \(foundNode.displayName)") // CHANGED
        } else {
            if self.accessibilityTree.first?.pid != pid && !autoSelectFocusedApp {
                // Info already set to "Tree not loaded" or will be updated by selectedApplicationPID change.
            } else {
                axInfoLog("Focused element (\(title ?? role ?? "unknown")) not found in currently loaded AXpector tree for PID \(pid).") // CHANGED
            }
            self.temporarilySelectedNodeIDByFocus = nil 
            highlightWindowController.hideHighlight()
        }
    }
} 