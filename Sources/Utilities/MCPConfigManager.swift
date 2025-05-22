import Foundation

// Basic structure for an MCP server entry in mcp.json
// This can be expanded as needed based on actual MCP server configurations
struct MCPServerEntry: Codable, Hashable {
    var id: String
    var name: String
    var enabled: Bool // Reflects if CodeLooper thinks it should be in mcp.json
    var path: String? // e.g., for local CLIs
    var version: String? // e.g., for XcodeBuildMCP
    var environment: [String: String]? // e.g., for XcodeBuildMCP
    
    // Add other common or specific fields as necessary
}

struct MCPFileContent: Codable {
    var mcpServers: [String: MCPServerDetailsCodable] // Key is server ID like "claude-code"
    var globalShortcut: String? // Preserve this
    // Preserve any other top-level keys by using a dictionary for unknown keys
    // For simplicity in V1, we'll focus on mcpServers and globalShortcut
}

// A codable representation for the values in mcpServers dictionary
struct MCPServerDetailsCodable: Codable, Hashable {
    var name: String
    var path: String? // Used by Claude Code CLI, macOS Automator
    var version: String? // Used by XcodeBuildMCP
    var environment: [String: String]? // Used by XcodeBuildMCP
    // Add any other fields that specific MCPs might use in mcp.json
}

actor MCPConfigManager {
    static let shared = MCPConfigManager()
    private let logger = Logger(category: .mcpConfiguration) // Assumes LogCategory has .mcpConfiguration

    private var mcpFilePath: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".cursor").appendingPathComponent("mcp.json")
    }

    private func readMCPFile() throws -> MCPFileContent {
        let path = mcpFilePath
        if !FileManager.default.fileExists(atPath: path.path) {
            logger.info("mcp.json not found at \(path.path). Returning default empty content.")
            // Return a default structure if file doesn't exist
            return MCPFileContent(mcpServers: [:], globalShortcut: "") 
        }
        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            let content = try decoder.decode(MCPFileContent.self, from: data)
            logger.info("Successfully read and decoded mcp.json")
            return content
        } catch {
            logger.error("Failed to read or decode mcp.json: \(error.localizedDescription)")
            throw error
        }
    }

    private func writeMCPFile(_ content: MCPFileContent) throws {
        let path = mcpFilePath
        do {
            // Ensure .cursor directory exists
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(content)
            try data.write(to: path, options: .atomic)
            logger.info("Successfully wrote mcp.json to \(path.path)")
        } catch {
            logger.error("Failed to write mcp.json: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Example function to get all configured MCP servers from CodeLooper's perspective
    // This would merge defaults with actual mcp.json content
    public func getConfiguredMCPServers() async throws -> [MCPServerEntry] {
        let currentContent = try await readMCPFile()
        var entries: [MCPServerEntry] = []

        // Example for Claude Code
        let claudeDetails = currentContent.mcpServers["claude-code"]
        entries.append(MCPServerEntry(
            id: "claude-code", 
            name: "Claude Code Agent", 
            enabled: claudeDetails != nil,
            path: claudeDetails?.path
        ))

        // Example for macOS Automator
        let automatorDetails = currentContent.mcpServers["macos-automator"]
        entries.append(MCPServerEntry(
            id: "macos-automator", 
            name: "macOS Automator", 
            enabled: automatorDetails != nil,
            path: automatorDetails?.path // Automator might not use a path in mcp.json
        ))

        // Example for XcodeBuildMCP
        let xcodeDetails = currentContent.mcpServers["XcodeBuildMCP"]
        entries.append(MCPServerEntry(
            id: "XcodeBuildMCP", 
            name: "Xcode Build Service", 
            enabled: xcodeDetails != nil,
            version: xcodeDetails?.version,
            environment: xcodeDetails?.environment
        ))
        
        return entries
    }

    public func updateMCPServer(
        id: String,
        nameForNew: String,
        enabled: Bool,
        details: MCPServerDetailsCodable?
    ) async throws {
        var currentContent = try await readMCPFile()

        if enabled {
            guard let detailsToSet = details else {
                let errorMsg = "Details must be provided to enable MCP server: \(id)"
                logger.error(errorMsg)
                throw NSError(domain: "MCPConfigManager", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            currentContent.mcpServers[id] = detailsToSet
            logger.info("Enabled/updated MCP server '\(id)' in mcp.json config.")
        } else {
            currentContent.mcpServers.removeValue(forKey: id)
            logger.info("Disabled MCP server '\(id)' by removing from mcp.json config.")
        }
        
        try await writeMCPFile(currentContent)
    }
}
