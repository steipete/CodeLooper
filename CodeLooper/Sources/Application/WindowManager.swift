@MainActor
private func setupAccessibilityMonitoring() {
    // Initial check
    Task {
        // Assume checkAccessibilityPermissions no longer takes logging parameters
        // and uses GlobalAXLogger internally if needed.
        self.isAccessibilityTrusted = try await AXorcist.checkAccessibilityPermissions()
        if !self.isAccessibilityTrusted {
            logger.warning("Accessibility permissions are not granted. AXorcist functionality will be limited.")
        }
    }

    // Set up a timer to re-check periodically, e.g., every 30 seconds
}
