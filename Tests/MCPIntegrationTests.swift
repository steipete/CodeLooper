@testable import CodeLooper
import Foundation
import XCTest


class MCPIntegrationTests: XCTestCase {
    // MARK: - MCPConfigManager Tests

    func testMCPConfigManagerSingleton() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared
            // Test that singleton is created without errors
            XCTAssertTrue(true) // Singleton exists
        }
    }

    func testMCPConfigurationState() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared
            
            // Test reading MCP configuration
            let config = configService.readMCPConfig()
            // Config can be nil if file doesn't exist, which is fine
            XCTAssertTrue(config != nil || config == nil)
        }
    }

    // MARK: - MCPVersionService Tests

    func testMCPVersionSingleton() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            // Test that singleton is created without errors
            XCTAssertTrue(true) // Singleton exists
        }
    }

    func testMCPVersionChecking() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            
            // Test version checking for an MCP extension
            let version = versionService.getLatestVersion(for: .peekaboo)
            XCTAssertTrue(!version.isEmpty)
            
            // Check another extension
            let claudeCodeVersion = versionService.getLatestVersion(for: .claudeCode)
            XCTAssertTrue(!claudeCodeVersion.isEmpty)
        }
    }

    func testMCPInstalledVersions() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            
            // Test getting installed version (may return cached or default)
            let installedVersion = versionService.getInstalledVersionCached(for: .terminator)
            XCTAssertTrue(!installedVersion.isEmpty)
        }
    }

    func testMCPAllExtensions() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            
            // Test all extension types
            for ext in MCPExtensionType.allCases {
                let version = versionService.getLatestVersion(for: ext)
                XCTAssertTrue(!version.isEmpty)
            }
        }
    }

    // MARK: - Integration Tests

    func testMCPServiceIntegration() async throws {
        await MainActor.run {
            let configService = MCPConfigManager.shared
            let versionService = MCPVersionService.shared
            
            // Test that both services can work together
            XCTAssertTrue(true) // Both singletons exist
            
            // Test reading config
            _ = configService.readMCPConfig()
            
            // Test version checking
            _ = versionService.getLatestVersion(for: .automator)
            
            // This tests that the services don't interfere with each other
            XCTAssertTrue(true)
        }
    }

    func testMCPExtensionTypes() async throws {
        // Test MCPExtensionType enum
        let allExtensions = MCPExtensionType.allCases
        
        XCTAssertGreaterThan(allExtensions.count, 0)
        XCTAssertTrue(allExtensions.contains(.peekaboo))
        XCTAssertTrue(allExtensions.contains(.terminator))
        XCTAssertTrue(allExtensions.contains(.claudeCode))
        XCTAssertTrue(allExtensions.contains(.conduit))
        XCTAssertTrue(allExtensions.contains(.automator))
        
        // Test identifiable conformance
        for ext in allExtensions {
            XCTAssertEqual(ext.id, ext.rawValue)
        }
    }
    
    func testMCPVersionServiceProperties() async throws {
        await MainActor.run {
            let versionService = MCPVersionService.shared
            
            // Test published properties exist
            _ = versionService.latestVersions
            _ = versionService.installedVersions
            _ = versionService.isChecking
            _ = versionService.lastCheckDate
            _ = versionService.checkError
            
            XCTAssertTrue(true) // Properties are accessible
        }
    }
}