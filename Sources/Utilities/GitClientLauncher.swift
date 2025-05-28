import AppKit
import Defaults
import Diagnostics
import Foundation

/// Utility to launch Git client applications with specific repositories
@MainActor
public enum GitClientLauncher {
    private static let logger = Logger(category: .general)
    
    /// Launch the configured Git client with the specified repository
    /// - Parameter repositoryPath: Path to the Git repository
    /// - Returns: True if launch was successful, false otherwise
    public static func launchGitClient(for repositoryPath: String) -> Bool {
        let gitClientPath = Defaults[.gitClientApp]
        
        // Check if the Git client exists
        guard FileManager.default.fileExists(atPath: gitClientPath) else {
            logger.error("Git client not found at path: \(gitClientPath)")
            return false
        }
        
        // Check if the repository path exists
        guard FileManager.default.fileExists(atPath: repositoryPath) else {
            logger.error("Repository path not found: \(repositoryPath)")
            return false
        }
        
        let gitClientURL = URL(fileURLWithPath: gitClientPath)
        let appName = gitClientURL.deletingPathExtension().lastPathComponent.lowercased()
        
        // Launch based on the Git client
        switch appName {
        case "tower":
            return launchTower(at: gitClientURL, with: repositoryPath)
        case "sourcetree":
            return launchSourceTree(at: gitClientURL, with: repositoryPath)
        case "gitkraken":
            return launchGitKraken(at: gitClientURL, with: repositoryPath)
        case "fork":
            return launchFork(at: gitClientURL, with: repositoryPath)
        default:
            // Generic launch - just open the app and hope it handles the path
            return genericLaunch(at: gitClientURL, with: repositoryPath)
        }
    }
    
    // MARK: - Private Methods
    
    private static func launchTower(at appURL: URL, with repositoryPath: String) -> Bool {
        // Launch Tower binary directly with the repository path as argument
        let process = Process()
        process.executableURL = appURL.appendingPathComponent("Contents/MacOS/Tower")
        process.arguments = [repositoryPath]
        
        do {
            logger.info("Launching Tower with repository: \(repositoryPath)")
            try process.run()
            return true
        } catch {
            logger.error("Failed to launch Tower: \(error.localizedDescription)")
            // Fallback to opening with file
            return openAppWithFile(appURL: appURL, filePath: repositoryPath)
        }
    }
    
    private static func launchSourceTree(at appURL: URL, with repositoryPath: String) -> Bool {
        // SourceTree can open repositories by passing the path
        return openAppWithFile(appURL: appURL, filePath: repositoryPath)
    }
    
    private static func launchGitKraken(at appURL: URL, with repositoryPath: String) -> Bool {
        // GitKraken URL scheme
        let gitKrakenURLString = "gitkraken://repo/\(repositoryPath)"
        
        if let gitKrakenURL = URL(string: gitKrakenURLString) {
            logger.info("Launching GitKraken with URL: \(gitKrakenURLString)")
            return NSWorkspace.shared.open(gitKrakenURL)
        }
        
        return openAppWithFile(appURL: appURL, filePath: repositoryPath)
    }
    
    private static func launchFork(at appURL: URL, with repositoryPath: String) -> Bool {
        // Fork can open repositories by passing the path
        return openAppWithFile(appURL: appURL, filePath: repositoryPath)
    }
    
    private static func genericLaunch(at appURL: URL, with repositoryPath: String) -> Bool {
        // Try to open the app with the repository path
        return openAppWithFile(appURL: appURL, filePath: repositoryPath)
    }
    
    private static func openAppWithFile(appURL: URL, filePath: String) -> Bool {
        let fileURL = URL(fileURLWithPath: filePath)
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        logger.info("Opening \(appURL.lastPathComponent) with repository: \(filePath)")
        
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: appURL,
            configuration: configuration
        ) { app, error in
            if let error = error {
                logger.error("Failed to open Git client: \(error.localizedDescription)")
            } else if let app = app {
                logger.info("Successfully launched \(app.localizedName ?? "Git client")")
            }
        }
        
        return true
    }
}
