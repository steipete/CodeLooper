import Foundation

/// Service for checking latest versions of MCP extensions from npm
@MainActor
final class MCPVersionService: ObservableObject {
    // MARK: Lifecycle

    private init() {}

    // MARK: Internal

    // MARK: - Singleton

    static let shared = MCPVersionService()

    // MARK: - Published Properties

    @Published var latestVersions: [MCPExtensionType: String] = [:]
    @Published var installedVersions: [MCPExtensionType: String] = [:]
    @Published var isChecking = false
    @Published var lastCheckDate: Date?
    @Published var checkError: Error?

    // MARK: - Public Methods

    /// Check versions for all known MCP extensions
    func checkAllVersions() async {
        guard !isChecking else { return }

        isChecking = true
        checkError = nil

        do {
            var latestVersionsMap: [MCPExtensionType: String] = [:]
            var installedVersionsMap: [MCPExtensionType: String] = [:]

            // Check latest versions from npm concurrently
            await withTaskGroup(of: (MCPExtensionType, String?).self) { group in
                for mcpExtension in MCPExtensionType.allCases {
                    group.addTask {
                        let version = try? await self.checkVersion(for: mcpExtension)
                        return (mcpExtension, version)
                    }
                }

                for await (mcpExtension, version) in group {
                    if let version {
                        latestVersionsMap[mcpExtension] = version
                    }
                }
            }
            
            // Check installed versions
            for mcpExtension in MCPExtensionType.allCases {
                if let installedVersion = self.getInstalledVersion(for: mcpExtension) {
                    installedVersionsMap[mcpExtension] = installedVersion
                }
            }

            self.latestVersions = latestVersionsMap
            self.installedVersions = installedVersionsMap
            self.lastCheckDate = Date()

        } catch {
            self.checkError = error
        }

        isChecking = false
    }

    /// Get cached latest version for an extension, or return current version if not available
    func getLatestVersion(for mcpExtension: MCPExtensionType) -> String {
        return latestVersions[mcpExtension] ?? getInstalledVersion(for: mcpExtension) ?? mcpExtension.currentVersion
    }
    
    /// Get installed version for an extension
    func getInstalledVersionCached(for mcpExtension: MCPExtensionType) -> String {
        return installedVersions[mcpExtension] ?? mcpExtension.currentVersion
    }

    /// Check if cached version is newer than current version
    func hasUpdate(for mcpExtension: MCPExtensionType) -> Bool {
        guard let latestVersion = latestVersions[mcpExtension] else { return false }
        let installedVersion = installedVersions[mcpExtension] ?? mcpExtension.currentVersion
        return compareVersions(current: installedVersion, latest: latestVersion) == .needsUpdate
    }
    
    /// Get the installed version for an MCP extension from mcp.json or package.json
    func getInstalledVersion(for mcpExtension: MCPExtensionType) -> String? {
        // Try to get version from MCP configuration first
        if let mcpVersion = getVersionFromMCPConfig(for: mcpExtension) {
            return mcpVersion
        }
        
        // Try to get version from local package.json if it exists
        if let packageVersion = getVersionFromPackageJSON(for: mcpExtension) {
            return packageVersion
        }
        
        return nil
    }

    // MARK: Private

    // MARK: - Private Properties

    private let npmAPIBaseURL = "https://registry.npmjs.org"
    private let urlSession = URLSession.shared

    /// Check version for a specific MCP extension
    private func checkVersion(for mcpExtension: MCPExtensionType) async throws -> String {
        let packageName = mcpExtension.npmPackageName
        let url = URL(string: "\(npmAPIBaseURL)/\(packageName)")!

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw MCPVersionError.networkError
        }

        let packageInfo = try JSONDecoder().decode(NPMPackageInfo.self, from: data)
        return packageInfo.distTags.latest
    }

    // MARK: - Private Methods

    private func compareVersions(current: String, latest: String) -> VersionComparison {
        // Normalize versions by removing "v" prefix if present
        let normalizedCurrent = current.hasPrefix("v") ? String(current.dropFirst()) : current
        let normalizedLatest = latest.hasPrefix("v") ? String(latest.dropFirst()) : latest
        
        // Simple version comparison - this could be enhanced with proper semantic versioning
        if normalizedCurrent == normalizedLatest {
            return .upToDate
        }

        // Basic comparison - in a production app, you'd want proper semver parsing
        let currentComponents = normalizedCurrent.split(separator: ".").compactMap { Int($0) }
        let latestComponents = normalizedLatest.split(separator: ".").compactMap { Int($0) }

        for i in 0 ..< min(currentComponents.count, latestComponents.count) {
            if currentComponents[i] < latestComponents[i] {
                return .needsUpdate
            } else if currentComponents[i] > latestComponents[i] {
                return .upToDate
            }
        }

        // If we get here, the versions are the same up to the shortest length
        if latestComponents.count > currentComponents.count {
            return .needsUpdate
        }

        return .upToDate
    }
    
    /// Get version from MCP configuration
    private func getVersionFromMCPConfig(for mcpExtension: MCPExtensionType) -> String? {
        let mcpIdentifier = mcpExtension.mcpIdentifier
        let status = MCPConfigManager.shared.getMCPStatus(mcpIdentifier: mcpIdentifier)
        return status.version
    }
    
    /// Get version from package.json file for installed npm packages
    private func getVersionFromPackageJSON(for mcpExtension: MCPExtensionType) -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let packagePath = homeDir.appendingPathComponent("node_modules/\(mcpExtension.npmPackageName)/package.json")
        
        guard FileManager.default.fileExists(atPath: packagePath.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: packagePath)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["version"] as? String
        } catch {
            return nil
        }
    }
}

// MARK: - Supporting Types

enum MCPExtensionType: String, CaseIterable, Identifiable {
    case peekaboo = "Peekaboo"
    case terminator = "Terminator"
    case claudeCode = "Claude Code"
    case conduit = "Conduit"
    case automator = "Automator"

    // MARK: Internal

    var id: String { rawValue }

    var npmPackageName: String {
        switch self {
        case .peekaboo:
            return "@steipete/peekaboo-mcp"
        case .terminator:
            return "@steipete/terminator-mcp"
        case .claudeCode:
            return "@steipete/claude-code-mcp"
        case .conduit:
            return "@steipete/conduit-mcp"
        case .automator:
            return "@steipete/macos-automator-mcp"
        }
    }

    var currentVersion: String {
        // Default to v1.0.0 - actual version will be fetched separately
        return "v1.0.0"
    }

    var displayName: String {
        return rawValue
    }
    
    var mcpIdentifier: String {
        switch self {
        case .peekaboo:
            return "peekaboo"
        case .terminator:
            return "terminator"
        case .claudeCode:
            return "claude-code"
        case .conduit:
            return "conduit"
        case .automator:
            return "automator"
        }
    }

    var iconName: String {
        switch self {
        case .peekaboo:
            return "camera"
        case .terminator:
            return "terminal"
        case .claudeCode:
            return "brain"
        case .conduit:
            return "pipe.and.drop"
        case .automator:
            return "gear"
        }
    }
}

enum VersionComparison {
    case upToDate
    case needsUpdate
}

enum MCPVersionError: Error, LocalizedError {
    case networkError
    case parseError

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Failed to fetch version information from npm registry"
        case .parseError:
            return "Failed to parse version information"
        }
    }
}

// MARK: - NPM API Response Models

private struct NPMPackageInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case distTags = "dist-tags"
    }

    let distTags: DistTags
}

private struct DistTags: Codable {
    let latest: String
}
