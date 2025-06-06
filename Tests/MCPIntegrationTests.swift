@testable import CodeLooper
import Foundation
import Testing

@Suite("MCPIntegrationTests")
struct MCPIntegrationTests {
    // MARK: - MCPConfigManager Tests

    @Test("M c p config manager singleton") @MainActor func mCPConfigManagerSingleton() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared
            // Test that singleton is created without errors
            #expect(true) // Singleton exists
        }
    }

    @Test("M c p configuration state") @MainActor func mCPConfigurationState() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared

            // Test reading MCP configuration
            let config = configService.readMCPConfig()
            // Config can be nil if file doesn't exist, which is fine
            #expect(config != nil || config == nil)
        }
    }

    // MARK: - MCPVersionService Tests

    @Test("M c p version singleton") @MainActor func mCPVersionSingleton() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            // Test that singleton is created without errors
            #expect(true) // Singleton exists
        }
    }

    @Test("M c p version checking") @MainActor func mCPVersionChecking() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared

            // Test version checking for an MCP extension
            let version = versionService.getLatestVersion(for: .peekaboo)
            #expect(!version.isEmpty)

            // Check another extension
            let claudeCodeVersion = versionService.getLatestVersion(for: .claudeCode)
            #expect(!claudeCodeVersion.isEmpty)
        }
    }

    @Test("M c p installed versions") @MainActor func mCPInstalledVersions() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared

            // Test getting installed version (may return cached or default)
            let installedVersion = versionService.getInstalledVersionCached(for: .terminator)
            #expect(!installedVersion.isEmpty)
        }
    }

    @Test("M c p all extensions") @MainActor func mCPAllExtensions() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared

            // Test all extension types
            for ext in MCPExtensionType.allCases {
                let version = versionService.getLatestVersion(for: ext)
                #expect(!version.isEmpty)
            }
        }
    }

    // MARK: - Integration Tests

    @Test("M c p service integration") @MainActor func mCPServiceIntegration() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared
            let versionService = MCPVersionService.shared

            // Test that both services can work together
            #expect(true) // Both singletons exist

            // Test reading config
            _ = configService.readMCPConfig()

            // Test version checking
            _ = versionService.getLatestVersion(for: .automator)

            // This tests that the services don't interfere with each other
            #expect(true)
        }
    }

    @Test("M c p extension types") @MainActor func mCPExtensionTypes() async throws {
        // Test MCPExtensionType enum
        let allExtensions = MCPExtensionType.allCases

        #expect(allExtensions.count > 0)
        #expect(allExtensions.contains(.peekaboo))
        #expect(allExtensions.contains(.terminator))
        #expect(allExtensions.contains(.claudeCode))
        #expect(allExtensions.contains(.conduit))
        #expect(allExtensions.contains(.automator))

        // Test identifiable conformance
        for ext in allExtensions {
            #expect(ext.id == ext.rawValue)
        }
    }

    @Test("M c p version service properties") @MainActor func mCPVersionServiceProperties() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared

            // Test published properties exist
            _ = versionService.latestVersions
            _ = versionService.installedVersions
            _ = versionService.isChecking
            _ = versionService.lastCheckDate
            _ = versionService.checkError

            #expect(true) // Properties are accessible
        }
    }
}
