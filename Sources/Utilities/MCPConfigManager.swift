import Defaults // For accessing default values if needed
import Diagnostics
import Foundation
import OSLog

// Define simple structs for mcp.json structure (Spec 7)
// These can be expanded as needed based on the actual mcp.json format
struct MCPRoot: Codable {
    var mcpServers: [String: MCPServerEntry]? // Dictionary of MCP server configurations

    // Initialize with empty servers and no shortcut if creating a new file
    init(mcpServers: [String: MCPServerEntry]? = [:]) {
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

    // Helper for basic version string parsing (e.g., "1.0.0" -> (1,0,0) )
    private func parseVersionString(_ versionString: String) -> (major: Int, minor: Int, patch: Int) {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        return (
            !components.isEmpty ? components[0] : 0,
            components.count > 1 ? components[1] : 0,
            components.count > 2 ? components[2] : 0
        )
    }
}
