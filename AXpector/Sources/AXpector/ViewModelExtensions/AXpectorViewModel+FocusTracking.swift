import AppKit // For NSWorkspace, NSRunningApplication, AXUIElement, AXObserver, pid_t
import AXorcist // For AXorcist.Element
import Defaults // ADDED
import SwiftUI // For @MainActor

// import OSLog // For Logger // REMOVE OSLog
// AXorcist import already includes logging utilities

// MARK: - Focus Tracking Implementation

/// Extension providing real-time focus tracking across applications.
///
/// This extension manages:
/// - Application activation monitoring and switching
/// - Focused element change notifications via AXObserver
/// - Cross-application focus tracking with automatic tree updates
/// - Synchronization between focus changes and tree selection
/// - Cleanup of observers when applications quit
extension AXpectorViewModel {
    // swiftlint:disable:next function_body_length
    func startFocusTrackingMonitoring() {
        axInfoLog("AXpectorViewModel: Requesting to start focus tracking monitoring.") // CHANGED

        if appActivationObserver == nil {
            appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract notification data before crossing actor boundary
                guard let activatedApp = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else {
                    return
                }

                Task { @MainActor in // Run the whole handler on MainActor
                    guard let self else { return }
                    guard self.isFocusTrackingModeActive else {
                        return
                    }
                    axInfoLog(
                        """
                        App activated: \(activatedApp.localizedName ?? "unknown") with PID \(activatedApp
                            .processIdentifier). \
                        AXpector will update focus tracking.
                        """
                    ) // CHANGED

                    let pidToObserve = self.selectedApplicationPID ?? activatedApp.processIdentifier
                    // Create ObserveCommand for focus tracking
                    let observeCommand = ObserveCommand(
                        appIdentifier: String(pidToObserve),
                        locator: nil,
                        notifications: [AXNotificationName.focusedUIElementChanged.rawValue],
                        includeDetails: true,
                        watchChildren: false,
                        notificationName: .focusedUIElementChanged,
                        includeElementDetails: nil,
                        maxDepthForSearch: 10
                    )
                    _ = self.axorcist.handleObserve(command: observeCommand)
                }
            }
        }

        Task {
            if let pid = selectedApplicationPID {
                // Create ObserveCommand for focus tracking
                let observeCommand = ObserveCommand(
                    appIdentifier: String(pid),
                    locator: nil,
                    notifications: [AXNotificationName.focusedUIElementChanged.rawValue],
                    includeDetails: true,
                    watchChildren: false,
                    notificationName: .focusedUIElementChanged,
                    includeElementDetails: nil,
                    maxDepthForSearch: 10
                )
                _ = axorcist.handleObserve(command: observeCommand)
            } else if let frontmostApp = NSWorkspace.shared.frontmostApplication {
                // Create ObserveCommand for focus tracking
                let observeCommand = ObserveCommand(
                    appIdentifier: String(frontmostApp.processIdentifier),
                    locator: nil,
                    notifications: [AXNotificationName.focusedUIElementChanged.rawValue],
                    includeDetails: true,
                    watchChildren: false,
                    notificationName: .focusedUIElementChanged,
                    includeElementDetails: nil,
                    maxDepthForSearch: 10
                )
                _ = axorcist.handleObserve(command: observeCommand)
            } else {
                axWarningLog("Focus Tracking: No application selected and no frontmost application found to observe.") // CHANGED
            }
        }
    }

    func stopFocusTrackingMonitoring() {
        axInfoLog("AXpectorViewModel: Requesting to stop focus tracking monitoring.") // CHANGED
        Task {
            // Comment out stopFocusTracking as there's no clear corresponding stopObservation command
            // axorcist.stopFocusTracking()
        }
    }

    @MainActor
    private func handleFocusNotificationFromAXorcist(
        focusedElement: Element,
        pid: pid_t,
        notification: AXNotification
    ) {
        axDebugLog(
            """
            AXpectorVM.handleFocusNotification: Element: \(focusedElement.briefDescription()), \
            PID: \(pid), Notification: \(notification.rawValue)
            """
        )

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
            if Defaults[.selectTreeOnFocusChange], let mainTreeRoot = self.accessibilityTree.first,
               mainTreeRoot.pid == pid
            {
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
