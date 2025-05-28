import Defaults // For accessing default values if needed
import Diagnostics
import Foundation
import OSLog

// Define simple structs for mcp.json structure (Spec 7)
// These can be expanded as needed based on the actual mcp.json format
struct MCPRoot: Codable {
    // MARK: Lifecycle

    // Initialize with empty servers and no shortcut if creating a new file
    init(mcpServers: [String: MCPServerEntry]? = [:], globalShortcut: String? = "") {
        self.mcpServers = mcpServers
        self.globalShortcut = globalShortcut
    }

    // MARK: Internal

    var mcpServers: [String: MCPServerEntry]? // Dictionary of MCP server configurations
    var globalShortcut: String? // Global shortcut configuration
}

struct MCPServerEntry: Codable {
    // MARK: Lifecycle

    // Custom initializer for backward compatibility
    init(
        name: String? = nil,
        enabled: Bool? = nil,
        command: String? = nil,
        args: [String]? = nil,
        type: String? = nil,
        env: [String: String]? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.enabled = enabled
        self.command = command
        self.args = args
        self.type = type
        self.env = env
        self.url = url
    }

    // MARK: Internal

    // Core MCP server properties matching actual mcp.json format
    var type: String? // "stdio" for some servers
    var command: String? // Main command (e.g., "npx", "mise", "env")
    var args: [String]? // Command arguments
    var env: [String: String]? // Environment variables
    var url: String? // For URL-based servers like gitmcp

    // Internal tracking properties (not in actual mcp.json)
    var name: String?
    var enabled: Bool?
    var version: String? // For XcodeBuildMCP
    var customCliName: String? // For Claude Code
    var incrementalBuildsEnabled: Bool? // For XcodeBuildMCP
    var sentryDisabled: Bool? // For XcodeBuildMCP
}

// New struct to hold comprehensive status for an MCP
struct MCPFullStatus {
    var id: String
    var name: String
    var enabled: Bool
    var displayStatus: String
    var command: String?
    var args: [String]?
    var type: String?
    var env: [String: String]?
    var url: String?
    var version: String?
    var customCliName: String?
    var incrementalBuildsEnabled: Bool?
    var sentryDisabled: Bool?
    // Add any other fields from MCPServerEntry that might be useful directly
}

@MainActor
class MCPConfigManager {
    // MARK: Lifecycle

    private init() {
        logger.info("MCPConfigManager initialized. MCP file path: \(self.mcpFilePath.path)")
        // Ensure the .cursor directory exists
        ensureDotCursorDirectoryExists()
    }

    // MARK: Internal

    static let shared = MCPConfigManager()

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
            logger.info("Successfully read mcp.json with \(config.mcpServers?.count ?? 0) servers")
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
        mcpFilePath
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

    func setMCPEnabled(
        mcpIdentifier: String,
        nameForEntry: String,
        enabled: Bool,
        defaultCommand: String? = nil,
        defaultArgs: [String]? = nil
    ) {
        ensureMCPFileExists() // Make sure the file exists before trying to modify it
        var currentConfig = readMCPConfig() ?? MCPRoot() // Start with current or default

        if currentConfig.mcpServers == nil { // Initialize if nil
            currentConfig.mcpServers = [:]
        }

        if enabled {
            var entry = currentConfig
                .mcpServers?[mcpIdentifier] ??
                MCPServerEntry(name: nameForEntry, enabled: true) // Default to new if not found
            entry.name = nameForEntry // Ensure name is set/updated
            entry.enabled = true
            if entry.command == nil, let defaultCommand {
                entry.command = defaultCommand
            }
            if entry.args == nil, let defaultArgs {
                entry.args = defaultArgs
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
                args: nil,
                type: nil,
                env: nil,
                url: nil,
                version: nil,
                customCliName: nil,
                incrementalBuildsEnabled: nil,
                sentryDisabled: nil
            )
        }

        // Determine if enabled based on presence in config (actual mcp.json doesn't have enabled field)
        let isEnabled = true // If it exists in the config, it's enabled

        var statusParts: [String] = []
        statusParts.append("Enabled")

        if let version = entry.version, !version.isEmpty {
            statusParts.append("v\(version)")
        }
        if let cliName = entry.customCliName, !cliName.isEmpty {
            statusParts.append("(CLI: \(cliName))")
        }
        if entry.incrementalBuildsEnabled == true {
            statusParts.append("(Incremental)")
        }
        // Add command info for display
        if let command = entry.command {
            statusParts.append("(\(command))")
        } else if let _ = entry.url {
            statusParts.append("(URL)")
        }

        let displayStatus = statusParts.joined(separator: " ")

        return MCPFullStatus(
            id: mcpIdentifier,
            name: entry.name ?? mcpIdentifier,
            enabled: isEnabled,
            displayStatus: displayStatus.isEmpty ? "Enabled" : displayStatus,
            command: entry.command,
            args: entry.args,
            type: entry.type,
            env: entry.env,
            url: entry.url,
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
              let entry = servers["XcodeBuildMCP"]
        else {
            return false // Default to false if not found
        }
        return entry.incrementalBuildsEnabled ?? false // Default to false if nil
    }

    func getXcodeBuildSentryDisabledFlag() -> Bool {
        guard let config = readMCPConfig(),
              let servers = config.mcpServers,
              let entry = servers["XcodeBuildMCP"]
        else {
            return false // Default to false
        }
        return entry.sentryDisabled ?? false // Default to false if nil
    }

    // MARK: Private

    private let logger = Logger(category: .mcpConfig)

    private var mcpFilePath: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".cursor/mcp.json")
    }

    private func ensureDotCursorDirectoryExists() {
        let dotCursorDir = mcpFilePath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dotCursorDir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: dotCursorDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.info("Created .cursor directory at \(dotCursorDir.path)")
            } catch {
                logger.error("Failed to create .cursor directory: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cursor Rule Set Management (Spec 3.3.C)

    private func getVersion(from ruleFileContent: String) -> String? {
        // Simple version parsing: looks for "// Version: X.Y.Z"
        let lines = ruleFileContent.split(whereSeparator: \.isNewline)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.starts(with: "// Version:") {
                return trimmedLine.replacingOccurrences(of: "// Version:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
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
