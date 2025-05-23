import OSLog
import SwiftUI

/// An observer that handles opening the settings scene programmatically
struct OpenSettingsObserver: ViewModifier {
    // Logger for tracing settings operations
    private let logger = Logger(label: "OpenSettingsObserver", category: .ui)

    // Access to open settings via environment
    @Environment(\.openSettings)
    private var openSettings

    // Store notification observer token
    @State private var notificationToken: NSObjectProtocol?

    // Apply the modifier
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Create observer for opening settings via notification
                notificationToken = NotificationCenter.default.addObserver(
                    forName: .openSettingsWindow,
                    object: nil,
                    queue: .main
                ) { [openSettings] _ in
                    // Use the captured openSettings action directly
                    logger.info("🔄 Received notification to open settings")
                    Task { @MainActor in
                        // Activate the app first to bring windows to foreground
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    }
                }

                logger.info("✅ Settings observer installed")
            }
            .onDisappear {
                // Clean up observer when view disappears
                if let token = notificationToken {
                    NotificationCenter.default.removeObserver(token)
                    notificationToken = nil
                    logger.info("🧹 Settings observer removed")
                }
            }
    }
}

// Extension to make the modifier easier to use
extension View {
    /// Adds an observer to the view that opens the Settings scene when .openSettingsWindow notification is posted
    func withSettingsObserver() -> some View {
        modifier(OpenSettingsObserver())
    }
}
