import AppKit
import Diagnostics
import Foundation
import OSLog
import UserNotifications

/// Class for showing visual success feedback after a contact upload completes
@MainActor
class UploadCompletionFeedback {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(statusItem: NSStatusItem?) {
        self.statusItem = statusItem
    }

    // MARK: Internal

    // MARK: - Public Methods

    /// Show a success indication in the menu bar after an upload completes
    func showUploadSuccess(contactCount: Int) {
        guard let button = statusItem?.button else {
            logger.warning("Unable to show upload success feedback - status item button is nil")
            return
        }

        // Cancel any existing feedback animations
        cancelTask(withId: "upload-success")

        // Configure the original state
        let originalImage = button.image
        let originalToolTip = button.toolTip ?? Constants.appName

        // Capture contact count to safely pass into the task
        let capturedContactCount = contactCount

        // Create the upload success Task with explicit @MainActor annotation
        let successTask: Task<Void, Error> = Task { @MainActor [weak self, weak button] in
            do {
                guard let self else { return }

                // Step 1: Show success icon
                await applySuccessIcon(to: button)

                // Step 2: Show toast notification if available
                // Ensure we're running on the MainActor by using explicit MainActor.run
                await MainActor.run {
                    self.showSuccessToast(contactCount: capturedContactCount)
                }

                // Step 3: Wait for 2 seconds
                try await Task.sleep(for: .seconds(2))

                // Check for cancellation
                try Task.checkCancellation()

                // Step 4: Animate back to normal image
                await restoreOriginalIcon(to: button, originalImage: originalImage)

                // Restore original tooltip - ensure this runs on the MainActor
                await MainActor.run {
                    button?.toolTip = originalToolTip
                }
            } catch {
                // Only log non-cancellation errors
                // Skip logging for cancellation errors
                if !(error is CancellationError) {
                    // Create a strong capture of self
                    let strongSelf = self
                    // Using MainActor.run to ensure proper isolation
                    await MainActor.run {
                        strongSelf?.logger.error("Upload success feedback interrupted: \(error.localizedDescription)")
                    }
                }

                // Make sure we restore the original state on error
                await MainActor.run {
                    button?.image = originalImage
                    button?.toolTip = originalToolTip
                }
            }
        }

        // Track the task
        trackTask(successTask, withId: "upload-success")
    }

    /// Cancel any active feedback animations
    func cancelFeedback() {
        cancelAllTasks()
    }

    /// Clean up all resources
    func cleanup() {
        // Cancel all active tasks
        cancelAllTasks()
    }

    // MARK: Private

    /// Weak reference to avoid reference cycles
    private weak var statusItem: NSStatusItem?

    /// Dictionary of stored tasks with identifiers
    private var tasks: [String: Task<Void, Error>] = [:]

    /// Logger for this class
    private let logger = Logger(category: .ui)

    // MARK: - Private Helper Methods

    /// Apply a success icon to the menu bar button with animation
    private func applySuccessIcon(to button: NSButton?) async {
        guard let button else { return }

        // Create a success check mark icon
        let successIcon = createSuccessIcon()

        // Update the tooltip
        button.toolTip = "Contact upload completed successfully!"

        // Animate from current to success icon
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                // Fade out current icon
                button.animator().alphaValue = 0

            }, completionHandler: {
                // Replace icon and fade back in
                button.image = successIcon

                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    button.animator().alphaValue = 1.0
                }, completionHandler: {
                    // Complete the async operation
                    continuation.resume()
                })
            })
        }
    }

    /// Restore the original icon with animation
    private func restoreOriginalIcon(to button: NSButton?, originalImage: NSImage?) async {
        guard let button, let originalImage else { return }

        // Animate back to original icon
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                // Fade out success icon
                button.animator().alphaValue = 0

            }, completionHandler: {
                // Replace with original icon and fade back in
                button.image = originalImage

                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    button.animator().alphaValue = 1.0
                }, completionHandler: {
                    // Complete the async operation
                    continuation.resume()
                })
            })
        }
    }

    /// Create a success check mark icon
    private func createSuccessIcon() -> NSImage {
        let size = Constants.menuBarIconSize
        let successImage = NSImage(size: size)

        successImage.lockFocus()

        // Use NSGraphicsContext to enable anti-aliasing for smooth edges
        if let context = NSGraphicsContext.current {
            context.shouldAntialias = true
            context.imageInterpolation = .high
        }

        // Draw a circle with green background
        let circlePath = NSBezierPath(ovalIn: NSRect(
            x: 1,
            y: 1,
            width: size.width - 2,
            height: size.height - 2
        ))

        // Use green color for success
        NSColor.systemGreen.setFill()
        circlePath.fill()

        // Draw a check mark in the center
        let checkmarkPath = NSBezierPath()
        checkmarkPath.move(to: NSPoint(x: size.width * 0.25, y: size.height * 0.5))
        checkmarkPath.line(to: NSPoint(x: size.width * 0.45, y: size.height * 0.3))
        checkmarkPath.line(to: NSPoint(x: size.width * 0.75, y: size.height * 0.7))

        // White check mark
        NSColor.white.setStroke()
        checkmarkPath.lineWidth = 2.0
        checkmarkPath.lineCapStyle = .round
        checkmarkPath.lineJoinStyle = .round
        checkmarkPath.stroke()

        // Set accessibility description
        successImage.accessibilityDescription = "Upload Successful"

        successImage.unlockFocus()

        return successImage
    }

    /// Show a toast notification for upload success
    @MainActor
    private func showSuccessToast(contactCount: Int) {
        // Format the message based on contact count
        let message = if contactCount == 1 {
            "1 contact uploaded successfully"
        } else {
            "\(contactCount) contacts uploaded successfully"
        }

        // Use modern UserNotifications framework
        let content = UNMutableNotificationContent()
        content.title = "Upload Complete"
        content.body = message
        content.sound = UNNotificationSound.default

        // Add icon if available - would require attachments but skipping for now

        // Create a request with the content and a unique identifier
        let request = UNNotificationRequest(
            identifier: "me.steipete.codelooper.upload-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        // Capture logger for use in callback to avoid actor isolation issues
        let loggerCopy = logger

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                // Use Task to properly transition to MainActor for logger access
                Task { @MainActor in
                    loggerCopy.error("Failed to deliver notification: \(error.localizedDescription)")
                }
            }
        }

        logger.info("Displayed upload success notification: \(message)")
    }

    // MARK: - Task Management

    /// Tracks a task with a specific identifier
    /// - Parameters:
    ///   - task: The task to track
    ///   - id: A unique identifier for the task
    private func trackTask(_ task: Task<Void, Error>, withId id: String) {
        // Cancel any existing task with the same ID
        if let existingTask = tasks[id] {
            existingTask.cancel()
        }

        // Store the new task
        tasks[id] = task
    }

    /// Cancels a task with the specified identifier
    /// - Parameter id: The identifier of the task to cancel
    private func cancelTask(withId id: String) {
        if let task = tasks[id] {
            task.cancel()
            tasks.removeValue(forKey: id)
        }
    }

    /// Cancels all tracked tasks
    private func cancelAllTasks() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
