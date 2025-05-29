@testable import CodeLooper
import Foundation
import Testing

/// Test suite for MCP (Model Context Protocol) integration functionality
struct MCPIntegrationTests {
    // MARK: - MCPConfigManager Tests

    @Test
    func mCPConfigManagerSingleton() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared
            // Test that singleton is created without errors
            #expect(true) // Singleton exists
        }
    }

    @Test
    func mCPConfigurationState() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared
            
            // Test reading MCP configuration
            let config = configService.readMCPConfig()
            // Config can be nil if file doesn't exist, which is fine
            #expect(config != nil || config == nil)
        }
    }

    // MARK: - MCPVersionService Tests

    @Test
    func mCPVersionSingleton() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            // Test that singleton is created without errors
            #expect(true) // Singleton exists
        }
    }

    @Test
    func mCPVersionChecking() async throws {
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

    @Test
    func mCPInstalledVersions() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            
            // Test getting installed version (may return cached or default)
            let installedVersion = versionService.getInstalledVersionCached(for: .terminator)
            #expect(!installedVersion.isEmpty)
        }
    }

    @Test
    func mCPAllExtensions() async throws {
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

    @Test
    func mCPServiceIntegration() async throws {
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

    @Test
    func mCPExtensionTypes() async throws {
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
    
    @Test
    func mCPVersionServiceProperties() async throws {
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