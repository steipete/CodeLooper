import Foundation

/// Provides system information for diagnostic reports
enum SystemInfoProvider {
    /// Get detailed system information for diagnostics
    /// - Returns: A formatted string with system information
    static func getSystemInfoSection() -> String {
        // Get system information - All operations are thread-safe
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceName = Host.current().localizedName ?? "Unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        // Get memory and CPU information - ProcessInfo is thread-safe
        let physicalMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024) // Convert to MB
        let processorCount = ProcessInfo.processInfo.processorCount
        let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount

        // Get disk space information - FileManager needs to be used in a thread-safe way
        var freeSpace = "Unknown"
        var totalSpace = "Unknown"

        let fileManager = FileManager.default
        if let homeDirectory = fileManager.homeDirectoryForCurrentUser.path as String? {
            do {
                let attributes = try fileManager.attributesOfFileSystem(forPath: homeDirectory)
                if let freeSize = attributes[.systemFreeSize] as? UInt64,
                   let totalSize = attributes[.systemSize] as? UInt64
                {
                    freeSpace = "\(freeSize / (1024 * 1024 * 1024)) GB" // Convert to GB
                    totalSpace = "\(totalSize / (1024 * 1024 * 1024)) GB" // Convert to GB
                }
            } catch {
                // Silently fail, we'll keep the "Unknown" values
            }
        }

        // Use safe default values for state properties to avoid actor isolation issues
        let contactsAccessState = "Unknown" // Can't access Defaults directly
        let isAuthenticated = "Unknown" // Can't access KeychainManager directly
        let uploadInterval = "3600" // Default value
        let lastUploadDate = "Never" // Default value

        // Create the system information section without actor-isolated properties
        return """
        == System Information ==
        Device: \(deviceName)
        macOS: \(osVersion)
        App Version: \(appVersion) (\(buildNumber))
        Memory: \(physicalMemory) MB
        Processors: \(processorCount) (Active: \(activeProcessorCount))
        Disk Space: \(freeSpace) free of \(totalSpace)

        == App State ==
        Contacts Access: \(contactsAccessState)
        Authenticated: \(isAuthenticated)
        Last Upload: \(lastUploadDate)
        Upload Interval: \(uploadInterval) seconds

        Note: Logs are available through Apple's Console.app 
        (using Subsystem: \(Bundle.main.bundleIdentifier ?? "me.steipete.codelooper"))
        """
    }
}
