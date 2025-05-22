import AppKit
import Foundation

/// Centralized alert presentation manager
/// Since this is isolated to the MainActor, it's safe to make Sendable
@MainActor
public final class AlertPresenter: AlertPresenting {
    // MARK: - Singleton

    public static let shared = AlertPresenter()

    // MARK: - Properties

    private var activeAlerts: [NSAlert] = []

    // MARK: - Initialization

    public init() {
        // Public initializer for singleton and for testing
    }

    // MARK: - Public Alert Methods

    /// Show a generic alert
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - style: Alert style
    public func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = createAlert(title: title, message: message, style: style)
        alert.addButton(withTitle: "OK")
        showAlert(alert)
    }

    /// Show an alert with primary and secondary buttons and action handlers
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - primaryButtonTitle: Title for the primary button
    ///   - secondaryButtonTitle: Title for the secondary button
    ///   - primaryAction: Action to execute when primary button is clicked
    ///   - secondaryAction: Action to execute when secondary button is clicked (optional)
    public func showChoiceAlert(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        showConfirmation(
            title: title,
            message: message,
            yesTitle: primaryButtonTitle,
            noTitle: secondaryButtonTitle
        ) { result in
            if result {
                primaryAction()
            } else if let secondaryAction {
                secondaryAction()
            }
        }
    }

    // Implementation of protocol method
    public func showAlert(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String,
        primaryAction: @escaping () -> Void
    ) {
        showChoiceAlert(
            title: title,
            message: message,
            primaryButtonTitle: primaryButtonTitle,
            secondaryButtonTitle: secondaryButtonTitle,
            primaryAction: primaryAction
        )
    }

    /// Show a simple information alert
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    public func showInfo(title: String, message: String) {
        showAlert(title: title, message: message, style: .informational)
    }

    /// Show an error alert for authentication issues
    /// - Parameter message: Error message to display
    public func showAuthError(_ message: String) {
        let alert = createAlert(title: "Authentication Error", message: message, style: .critical)
        alert.addButton(withTitle: "OK")
        showAlert(alert)
    }

    /// Show an error alert for upload issues
    /// - Parameter message: Error message to display
    public func showUploadError(_ message: String) {
        let alert = createAlert(title: "Upload Failed", message: message, style: .critical)
        alert.addButton(withTitle: "OK")
        showAlert(alert)
    }

    /// Show an error alert for export issues
    /// - Parameter message: Error message to display
    public func showExportError(_ message: String) {
        let alert = createAlert(title: "Export Failed", message: message, style: .critical)
        alert.addButton(withTitle: "OK")
        showAlert(alert)
    }

    /// Show a confirmation dialog with Yes/No options
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - yesTitle: Title for the "Yes" button
    ///   - noTitle: Title for the "No" button
    ///   - completion: Callback with bool indicating user's choice
    public func showConfirmation(
        title: String,
        message: String,
        yesTitle: String = "Yes",
        noTitle: String = "No",
        completion: @escaping (Bool) -> Void
    ) {
        let alert = createAlert(title: title, message: message, style: .informational)

        // Add buttons in reverse order since rightmost button is default
        alert.addButton(withTitle: yesTitle)
        alert.addButton(withTitle: noTitle)

        // Show the alert and process response
        Task { @MainActor in
            // Make sure app is active
            NSApp.activate(ignoringOtherApps: true)

            // If we have a key window, show as sheet, otherwise run modally
            if let window = NSApp.keyWindow {
                // Track the alert to prevent it from being deallocated
                self.activeAlerts.append(alert)

                // Use continuation to handle modal presentation
                // Define continuation type for readability
                typealias AlertResponse = CheckedContinuation<NSApplication.ModalResponse, Never>
                let response = await withCheckedContinuation { (cont: AlertResponse) in
                    alert.beginSheetModal(for: window) { response in
                        cont.resume(returning: response)
                    }
                }

                // Clean up the alert tracker
                // Remove alert from managed alerts collection
                if let index = self.activeAlerts.firstIndex(where: { $0 === alert }) {
                    self.activeAlerts.remove(at: index)
                }

                // Process the result - return true if first button (Yes) was clicked
                let result = (response == .alertFirstButtonReturn)
                completion(result)
            } else {
                // No window available, run as modal alert
                let response = alert.runModal()
                let result = (response == .alertFirstButtonReturn)
                completion(result)
            }
        }
    }

    /// Show an alert with three button options
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - firstButtonTitle: Title for the first button
    ///   - secondButtonTitle: Title for the second button
    ///   - thirdButtonTitle: Title for the third button
    ///   - completion: Callback with integer indicating user's choice (0, 1, or 2)
    public func showThreeButtonAlert(
        title: String,
        message: String,
        firstButtonTitle: String,
        secondButtonTitle: String,
        thirdButtonTitle: String,
        completion: @escaping (Int) -> Void
    ) {
        let alert = createAlert(title: title, message: message, style: .informational)

        // Add buttons in reverse order
        alert.addButton(withTitle: firstButtonTitle)
        alert.addButton(withTitle: secondButtonTitle)
        alert.addButton(withTitle: thirdButtonTitle)

        // Show the alert and process response
        Task { @MainActor in
            // Make sure app is active
            NSApp.activate(ignoringOtherApps: true)

            // If we have a key window, show as sheet, otherwise run modally
            if let window = NSApp.keyWindow {
                // Track the alert to prevent it from being deallocated
                self.activeAlerts.append(alert)

                // Use continuation to handle modal presentation
                // Define continuation type for readability
                typealias AlertResponse = CheckedContinuation<NSApplication.ModalResponse, Never>
                let response = await withCheckedContinuation { (cont: AlertResponse) in
                    alert.beginSheetModal(for: window) { response in
                        cont.resume(returning: response)
                    }
                }

                // Clean up the alert tracker
                if let index = self.activeAlerts.firstIndex(where: { $0 === alert }) {
                    self.activeAlerts.remove(at: index)
                }

                // Convert modal response to index (0, 1, or 2)
                let result = switch response {
                case .alertFirstButtonReturn:
                    0
                case .alertSecondButtonReturn:
                    1
                case .alertThirdButtonReturn:
                    2
                default:
                    0
                }

                completion(result)
            } else {
                // No window available, run as modal alert
                let response = alert.runModal()

                // Convert modal response to index (0, 1, or 2)
                let result = switch response {
                case .alertFirstButtonReturn:
                    0
                case .alertSecondButtonReturn:
                    1
                case .alertThirdButtonReturn:
                    2
                default:
                    0
                }

                completion(result)
            }
        }
    }

    // MARK: - Private Helper Methods

    /// Create a standard alert with consistent styling
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - style: Alert style (warning, critical, informational)
    /// - Returns: Configured NSAlert
    @MainActor
    private func createAlert(title: String, message: String, style: NSAlert.Style) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.icon = createAlertIcon(for: style)
        return alert
    }

    /// Create an appropriate icon for the alert style
    /// - Parameter style: Alert style
    /// - Returns: NSImage icon
    @MainActor
    private func createAlertIcon(for style: NSAlert.Style) -> NSImage? {
        // Using system-provided icons for consistency
        switch style {
        case .warning:
            return NSImage(named: NSImage.cautionName)
        case .critical:
            return NSImage(named: NSImage.stopProgressTemplateName)
        case .informational:
            return NSImage(named: "logo") ?? NSImage(named: NSImage.infoName)
        @unknown default:
            return NSImage(named: NSImage.infoName)
        }
    }

    /// Show an alert, ensuring it's displayed from the main thread
    /// - Parameter alert: Alert to show
    @MainActor
    private func showAlert(_ alert: NSAlert) {
        Task { @MainActor in
            // Ensure app is active
            NSApp.activate(ignoringOtherApps: true)

            // If we have a key window, show as sheet, otherwise run modally
            if let window = NSApp.keyWindow {
                // Track the alert to prevent it from being deallocated
                self.activeAlerts.append(alert)

                // Use async/await pattern for sheet presentation
                // Define continuation type for readability
                typealias AlertResponse = CheckedContinuation<NSApplication.ModalResponse, Never>
                _ = await withCheckedContinuation { (cont: AlertResponse) in
                    alert.beginSheetModal(for: window) { response in
                        // Remove alert from tracking array when closed
                        if let index = self.activeAlerts.firstIndex(where: { $0 === alert }) {
                            self.activeAlerts.remove(at: index)
                        }
                        cont.resume(returning: response)
                    }
                }
            } else {
                // No window available, run as modal alert
                alert.runModal()
            }
        }
    }
}
