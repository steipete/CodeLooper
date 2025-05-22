import AppKit
import Foundation

/// Protocol defining alert presentation capabilities
@MainActor
public protocol AlertPresenting: Sendable {
    /// Show a simple information alert
    func showInfo(title: String, message: String)

    /// Show an error alert for authentication issues
    func showAuthError(_ message: String)

    /// Show an error alert for upload issues
    func showUploadError(_ message: String)

    /// Show an error alert for export issues
    func showExportError(_ message: String)

    /// Show a generic alert
    func showAlert(title: String, message: String, style: NSAlert.Style)

    /// Show a confirmation dialog with Yes/No options
    func showConfirmation(
        title: String,
        message: String,
        yesTitle: String,
        noTitle: String,
        completion: @escaping (Bool) -> Void
    )

    /// Show an alert with three button options
    func showThreeButtonAlert(
        title: String,
        message: String,
        firstButtonTitle: String,
        secondButtonTitle: String,
        thirdButtonTitle: String,
        completion: @escaping (Int) -> Void
    )

    /// Show an alert with primary and secondary buttons and action handlers
    func showAlert(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String,
        primaryAction: @escaping () -> Void
    )

    /// Show an alert with primary and secondary buttons and action handlers for both
    func showChoiceAlert(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)?
    )
}

// Default implementations for convenience
extension AlertPresenting {
    func showConfirmation(title: String, message: String, completion: @escaping (Bool) -> Void) {
        showConfirmation(title: title, message: message, yesTitle: "Yes", noTitle: "No", completion: completion)
    }
}
