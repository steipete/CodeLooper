import Foundation
import OSLog
import Defaults // For accessing default values if needed

// Define simple structs for mcp.json structure (Spec 7)
// These can be expanded as needed based on the actual mcp.json format
struct MCPRoot: Codable {
    var mcpServers: [String: MCPServerEntry]? // Dictionary of MCP server configurations

    // Initialize with empty servers and no shortcut if creating a new file
    init(mcpServers: [String : MCPServerEntry]? = [:]) {
        self.mcpServers = mcpServers
    }
}

struct MCPServerEntry: Codable {
    // Common properties for all MCP servers
    var name: String
    var enabled: Bool
    var command: [String]? // For command-line based MCPs like Claude Code, XcodeBuild
    // Add other MCP-specific properties here as needed
    // e.g., version for XcodeBuild, cliName for Claude Code
    var version: String? // For XcodeBuildMCP
    var customCliName: String? // For Claude Code
    // For macOS Automator, specific script paths or identifiers might be stored
    var incrementalBuildsEnabled: Bool? // For XcodeBuildMCP
    var sentryDisabled: Bool? // For XcodeBuildMCP
}

// New struct to hold comprehensive status for an MCP
struct MCPFullStatus {
    var id: String
    var name: String
    var enabled: Bool
    var displayStatus: String
    var command: [String]?
    var version: String?
    var customCliName: String?
    var incrementalBuildsEnabled: Bool?
    var sentryDisabled: Bool?
    // Add any other fields from MCPServerEntry that might be useful directly
}

@MainActor
class MCPConfigManager {
    static let shared = MCPConfigManager()
    private let logger = Logger(category: .mcpConfig)

    private var mcpFilePath: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".cursor/mcp.json")
    }

    private init() {
        logger.info("MCPConfigManager initialized. MCP file path: \(self.mcpFilePath.path)")
        // Ensure the .cursor directory exists
        ensureDotCursorDirectoryExists()
    }

    private func ensureDotCursorDirectoryExists() {
        let dotCursorDir = mcpFilePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dotCursorDir.path) {
            do {
                try FileManager.default.createDirectory(at: dotCursorDir, withIntermediateDirectories: true, attributes: nil)
                logger.info("Created .cursor directory at \(dotCursorDir.path)")
            } catch {
                logger.error("Failed to create .cursor directory: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - mcp.json Handling (Spec 7)

    func readMCPConfig() -> MCPRoot? {
        do {
            if !FileManager.default.fileExists(atPath: mcpFilePath.path) {
                logger.info("mcp.json does not exist. Will attempt to create with defaults if an MCP is enabled.")
                return MCPRoot() // Return a default empty structure
            }
            let data = try Data(contentsOf: mcpFilePath)
            let decoder = JSONDecoder()
            let config = try decoder.decode(MCPRoot.self, from: data)
            logger.info("Successfully read mcp.json")
            return config
        } catch {
            logger.error("Failed to read or decode mcp.json: \(error.localizedDescription)")
            return nil
        }
    }

    func writeMCPConfig(_ config: MCPRoot) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: mcpFilePath, options: .atomic)
            logger.info("Successfully wrote mcp.json to \(self.mcpFilePath.path)")
            return true
        } catch {
            logger.error("Failed to encode or write mcp.json: \(error.localizedDescription)")
            return false
        }
    }
    
    func ensureMCPFileExists() {
        if !FileManager.default.fileExists(atPath: mcpFilePath.path) {
            logger.info("mcp.json does not exist, creating with default structure.")
            let defaultConfig = MCPRoot(mcpServers: [:])
            _ = writeMCPConfig(defaultConfig)
        }
    }

    // MARK: - File Operations (Spec 7.A.3)

    func getMCPFilePath() -> URL {
        return mcpFilePath
    }

    func clearMCPFile() -> Bool {
        do {
            // Create a default empty MCPRoot structure
            let defaultConfig = MCPRoot(mcpServers: [:])
            // Write this default structure to the file, effectively clearing it
            // while keeping it as valid JSON.
            let success = writeMCPConfig(defaultConfig)
            if success {
                logger.info("mcp.json has been cleared (reset to default empty structure).")
            } else {
                logger.error("Failed to clear mcp.json by writing default structure.")
            }
            return success
        }
    }

    // MARK: - Specific MCP Management (Spec 3.3.D)

    func setMCPEnabled(mcpIdentifier: String, nameForEntry: String, enabled: Bool, defaultCommand: [String]? = nil) {
        ensureMCPFileExists() // Make sure the file exists before trying to modify it
        var currentConfig = readMCPConfig() ?? MCPRoot() // Start with current or default

        if currentConfig.mcpServers == nil { // Initialize if nil
            currentConfig.mcpServers = [:]
        }

        if enabled {
            var entry = currentConfig.mcpServers?[mcpIdentifier] ?? MCPServerEntry(name: nameForEntry, enabled: true) // Default to new if not found
            entry.name = nameForEntry // Ensure name is set/updated
            entry.enabled = true
            if entry.command == nil, let defaultCommand = defaultCommand {
                 entry.command = defaultCommand
            }
            currentConfig.mcpServers?[mcpIdentifier] = entry
            logger.info("Set MCP \(mcpIdentifier) enabled state to true")
        } else {
            // If disabling, remove the entry as per Spec 3.3.D
            currentConfig.mcpServers?.removeValue(forKey: mcpIdentifier)
            logger.info("Set MCP \(mcpIdentifier) enabled state to false and removed entry from mcp.json")
        }

        _ = writeMCPConfig(currentConfig)
    }

    func getMCPStatus(mcpIdentifier: String) -> MCPFullStatus {
        guard let config = readMCPConfig(), let servers = config.mcpServers, let entry = servers[mcpIdentifier] else {
            // Default status for an MCP not found in the config
            let name = mcpIdentifier // Or a more friendly default name mapping
            return MCPFullStatus(
                id: mcpIdentifier,
                name: name,
                enabled: false,
                displayStatus: "Not Configured",
                command: nil,
                version: nil,
                customCliName: nil,
                incrementalBuildsEnabled: nil,
                sentryDisabled: nil
            )
        }

        var statusParts: [String] = []
        if entry.enabled {
            statusParts.append("Enabled")
        } else {
            statusParts.append("Disabled")
        }

        if let version = entry.version, !version.isEmpty {
            statusParts.append("v\(version)")
        }
        if let cliName = entry.customCliName, !cliName.isEmpty {
            statusParts.append("(CLI: \(cliName))")
        }
        if entry.incrementalBuildsEnabled == true {
            statusParts.append("(Incremental)")
        }
        // Sentry status might not be something to show in a brief status string unless specifically required.

        let displayStatus = statusParts.joined(separator: " ")

        return MCPFullStatus(
            id: mcpIdentifier,
            name: entry.name,
            enabled: entry.enabled,
            displayStatus: displayStatus.isEmpty ? (entry.enabled ? "Enabled" : "Disabled") : displayStatus,
            command: entry.command,
            version: entry.version,
            customCliName: entry.customCliName,
            incrementalBuildsEnabled: entry.incrementalBuildsEnabled,
            sentryDisabled: entry.sentryDisabled
        )
    }

    // Placeholder for updating specific MCP configurations (e.g., XcodeBuild version)
    func updateMCPConfiguration(mcpIdentifier: String, params: [String: Any]) -> Bool {
        ensureMCPFileExists()
        var currentConfig = readMCPConfig() ?? MCPRoot()
        if currentConfig.mcpServers == nil { currentConfig.mcpServers = [:] }

        if var entry = currentConfig.mcpServers?[mcpIdentifier] {
            if let version = params["version"] as? String {
                entry.version = version
            }
            if let cliName = params["customCliName"] as? String {
                entry.customCliName = cliName
            }
            if let incremental = params["incrementalBuildsEnabled"] as? Bool {
                entry.incrementalBuildsEnabled = incremental
            }
            if let sentry = params["sentryDisabled"] as? Bool {
                entry.sentryDisabled = sentry
            }
            // Add other params as needed
            currentConfig.mcpServers?[mcpIdentifier] = entry
            let success = writeMCPConfig(currentConfig)
            if success {
                logger.info("Updated configuration for MCP \(mcpIdentifier)")
            } else {
                logger.error("Failed to write mcp.json when updating MCP \(mcpIdentifier)")
            }
            return success
        } else {
            logger.warning("Attempted to update non-existent MCP: \(mcpIdentifier)")
            return false // Indicate failure as the MCP entry doesn't exist
        }
    }

    // MARK: - Specific MCP Getters for Configuration Booleans

    func getXcodeBuildIncrementalBuildsFlag() -> Bool {
        guard let config = readMCPConfig(), 
              let servers = config.mcpServers, 
              let entry = servers["XcodeBuildMCP"] else {
            return false // Default to false if not found
        }
        return entry.incrementalBuildsEnabled ?? false // Default to false if nil
    }

    func getXcodeBuildSentryDisabledFlag() -> Bool {
        guard let config = readMCPConfig(), 
              let servers = config.mcpServers, 
              let entry = servers["XcodeBuildMCP"] else {
            return false // Default to false
        }
        return entry.sentryDisabled ?? false // Default to false if nil
    }

    // MARK: - Cursor Rule Set Management (Spec 3.3.C)

    enum RuleSetStatus {
        case notInstalled
        case installed(version: String)
        case updateAvailable(installedVersion: String, newVersion: String)
        case corrupted // If file exists but version can't be read
        case bundleResourceMissing // If the app's bundled rule is missing

        var displayName: String {
            switch self {
            case .notInstalled: "Not Installed"
            case .installed(let version): "Installed (v\(version))"
            case .updateAvailable(let installed, let new): "Update Available (Installed: v\(installed), New: v\(new))"
            case .corrupted: "Installed (Corrupted - Cannot Read Version)"
            case .bundleResourceMissing: "Error: App's rule file missing"
            }
        }
    }

    private func getVersion(from ruleFileContent: String) -> String? {
        // Simple version parsing: looks for "// Version: X.Y.Z"
        let lines = ruleFileContent.split(whereSeparator: \.isNewline)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.starts(with: "// Version:") {
                return trimmedLine.replacingOccurrences(of: "// Version:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil // No version found
    }

    private func getBundledRuleInfo() -> (content: String, version: String)? {
        guard let ruleSourceURL = Bundle.main.url(forResource: "codelooper_terminator_rule", withExtension: "mdc") else {
            logger.error("Bundled Terminator rule file 'codelooper_terminator_rule.mdc' not found.")
            return nil
        }
        do {
            let content = try String(contentsOf: ruleSourceURL)
            guard let version = getVersion(from: content) else {
                // Assuming the bundled file *must* have a version for this mechanism to work
                logger.error("Bundled Terminator rule file is missing a version string. This is a critical app resource issue.")
                // Return a placeholder or handle as a fatal error for the update mechanism for this rule.
                // For now, let's say it's "unknown" but this state should ideally not be reached in a production build.
                return (content, "unknown_bundle_version_error") 
            }
            return (content, version)
        } catch {
            logger.error("Failed to read bundled Terminator rule file: \(error.localizedDescription)")
            return nil
        }
    }

    func installTerminatorRuleSet(to projectRootURL: URL) -> Bool {
        logger.info("Attempting to install Terminator Rule Set to \(projectRootURL.path)")
        
        let scriptsDir = projectRootURL.appendingPathComponent(".cursor/scripts")
        let rulesDir = projectRootURL.appendingPathComponent(".cursor/rules")

        do {
            // Create directories if they don't exist
            try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(at: rulesDir, withIntermediateDirectories: true, attributes: nil)

            // Get paths to bundled resources (Spec 1.5)
            guard let scriptSourcePath = Bundle.main.url(forResource: "terminator", withExtension: "scpt"),
                  let ruleSourcePath = Bundle.main.url(forResource: "codelooper_terminator_rule", withExtension: "mdc") else {
                logger.error("Bundled Terminator rule set files not found.")
                return false
            }

            let scriptDestPath = scriptsDir.appendingPathComponent(scriptSourcePath.lastPathComponent)
            let ruleDestPath = rulesDir.appendingPathComponent(ruleSourcePath.lastPathComponent)

            // Copy files, overwrite if exist (as per Spec 3.3.C - "Prompts to overwrite")
            // For simplicity here, we'll just overwrite. A real implementation would prompt.
            if FileManager.default.fileExists(atPath: scriptDestPath.path) {
                try FileManager.default.removeItem(at: scriptDestPath)
            }
            try FileManager.default.copyItem(at: scriptSourcePath, to: scriptDestPath)
            logger.info("Copied \(scriptSourcePath.lastPathComponent) to \(scriptDestPath.path)")

            if FileManager.default.fileExists(atPath: ruleDestPath.path) {
                try FileManager.default.removeItem(at: ruleDestPath)
            }
            try FileManager.default.copyItem(at: ruleSourcePath, to: ruleDestPath)
            logger.info("Copied \(ruleSourcePath.lastPathComponent) to \(ruleDestPath.path)")
            
            logger.info("Terminator Rule Set installed successfully to \(projectRootURL.path)")
            return true
        } catch {
            logger.error("Failed to install Terminator Rule Set: \(error.localizedDescription)")
            // Show alert to user (AlertPresenter.shared.showError...)
            return false
        }
    }

    func verifyTerminatorRuleSet(at projectRootURL: URL) -> RuleSetStatus { 
        let scriptPath = projectRootURL.appendingPathComponent(".cursor/scripts/terminator.scpt")
        let rulePath = projectRootURL.appendingPathComponent(".cursor/rules/codelooper_terminator_rule.mdc")

        let scriptExists = FileManager.default.fileExists(atPath: scriptPath.path)
        let ruleFileExists = FileManager.default.fileExists(atPath: rulePath.path)

        guard let bundledInfo = getBundledRuleInfo() else {
            return .bundleResourceMissing
        }
        // If bundled version itself indicates an error (e.g. missing version string in bundled file)
        if bundledInfo.version == "unknown_bundle_version_error" {
            return .bundleResourceMissing // Treat as if the resource isn't properly available for versioning
        }
        let bundledVersion = bundledInfo.version

        if !scriptExists || !ruleFileExists {
            return .notInstalled
        }

        do {
            let installedRuleContent = try String(contentsOf: rulePath)
            guard let installedVersion = getVersion(from: installedRuleContent) else {
                return .corrupted 
            }

            // Basic semantic version comparison (major.minor.patch)
            // This is a simplified comparison. For robust semver, a dedicated library is better.
            let (installedMajor, installedMinor, installedPatch) = parseVersionString(installedVersion)
            let (bundledMajor, bundledMinor, bundledPatch) = parseVersionString(bundledVersion)

            if bundledMajor > installedMajor || 
               (bundledMajor == installedMajor && bundledMinor > installedMinor) || 
               (bundledMajor == installedMajor && bundledMinor == installedMinor && bundledPatch > installedPatch) {
                return .updateAvailable(installedVersion: installedVersion, newVersion: bundledVersion)
            } else if installedVersion == bundledVersion { // Or more comprehensively, if bundled is not newer
                return .installed(version: installedVersion)
            } else {
                // Installed version is newer or different in a non-upgrade path (e.g. manual edit, dev version)
                // Treat as installed, but log this unusual case.
                logger.info("Installed rule set (v\(installedVersion)) is newer than or different from bundled (v\(bundledVersion)). Treating as installed.")
                return .installed(version: installedVersion) 
            }
        } catch {
            logger.error("Failed to read installed rule file at \(rulePath.path): \(error.localizedDescription)")
            return .corrupted
        }
    }
    
    // Helper for basic version string parsing (e.g., "1.0.0" -> (1,0,0) )
    private func parseVersionString(_ versionString: String) -> (major: Int, minor: Int, patch: Int) {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        return (
            components.count > 0 ? components[0] : 0,
            components.count > 1 ? components[1] : 0,
            components.count > 2 ? components[2] : 0
        )
    }
}
