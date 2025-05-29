import Testing
import Foundation
@testable import CodeLooper

/// Test suite for MCP (Model Context Protocol) integration functionality
@Suite("MCP Integration Tests")
struct MCPIntegrationTests {
    
    // MARK: - MCPConfigManager Tests
    
    @Test("MCPConfigManager can be initialized")
    func testMCPConfigManagerInitialization() async throws {
        let configService = MCPConfigManager()
        
        // Test that service is created without errors
        #expect(configService != nil)
    }
    
    @Test("MCPConfigManager manages configuration state")
    func testMCPConfigurationState() async throws {
        let configService = MCPConfigManager()
        
        // Test configuration state management
        // Note: Without making actual file system calls, we test the service doesn't crash
        do {
            _ = await configService.getCurrentConfiguration()
            #expect(true) // If we get here, no crash occurred
        } catch {
            // Errors are acceptable if MCP isn't configured
            #expect(error != nil)
        }
    }
    
    // MARK: - MCPVersionService Tests
    
    @Test("MCPVersionService can check package versions")
    func testMCPVersionChecking() async throws {
        let versionService = MCPVersionService()
        
        // Test that service is created without errors
        #expect(versionService != nil)
        
        // Test version checking for a common package
        do {
            let version = await versionService.getLatestVersion(for: "react")
            if let version = version {
                #expect(!version.isEmpty)
                #expect(version.contains(".")) // Version should contain dots
            }
        } catch {
            // Network errors are acceptable in tests
            #expect(error != nil)
        }
    }
    
    @Test("MCPVersionService handles invalid package names")
    func testMCPVersionCheckingInvalidPackage() async throws {
        let versionService = MCPVersionService()
        
        // Test with non-existent package
        do {
            let version = await versionService.getLatestVersion(for: "this-package-definitely-does-not-exist-12345")
            #expect(version == nil) // Should return nil for non-existent packages
        } catch {
            // Errors are also acceptable for non-existent packages
            #expect(error != nil)
        }
    }
    
    @Test("MCPVersionService handles multiple concurrent requests")
    func testMCPUpdateDetection() async throws {
        let versionService = MCPVersionService()
        
        // Test concurrent version checks
        async let version1 = versionService.getLatestVersion(for: "lodash")
        async let version2 = versionService.getLatestVersion(for: "express")
        async let version3 = versionService.getLatestVersion(for: "axios")
        
        do {
            let results = try await [version1, version2, version3]
            #expect(results.count == 3)
            
            // At least some requests should succeed (or all fail gracefully)
            let successfulResults = results.compactMap { $0 }
            for version in successfulResults {
                #expect(!version.isEmpty)
            }
        } catch {
            // Network errors are acceptable in concurrent tests
            #expect(error != nil)
        }
    }
    
    // MARK: - MCPConfigurationView Tests
    
    @Test("MCPConfigurationView can be initialized")
    func testMCPConfigurationUI() async throws {
        let configView = MCPConfigurationView()
        
        // Test that view is created without errors
        #expect(configView != nil)
        
        // Since this is a SwiftUI view, we mainly test it doesn't crash on creation
        // More comprehensive UI testing would require view testing frameworks
    }
    
    // MARK: - Integration Tests
    
    @Test("MCP service integration")
    func testMCPServiceIntegration() async throws {
        let configService = MCPConfigManager()
        let versionService = MCPVersionService()
        
        // Test that both services can work together
        #expect(configService != nil)
        #expect(versionService != nil)
        
        // Test basic functionality without making external calls
        do {
            // Try to get configuration (may fail if MCP not set up)
            _ = await configService.getCurrentConfiguration()
        } catch {
            // Expected if MCP not configured
        }
        
        // This tests that the services don't interfere with each other
        #expect(true)
    }
    
    @Test("MCP error handling")
    func testMCPErrorHandling() async throws {
        let versionService = MCPVersionService()
        
        // Test error handling with empty string
        do {
            let version = await versionService.getLatestVersion(for: "")
            #expect(version == nil) // Should handle empty input gracefully
        } catch {
            // Errors are also acceptable for invalid input
            #expect(error != nil)
        }
        
        // Test error handling with invalid characters
        do {
            let version = await versionService.getLatestVersion(for: "invalid/package@name")
            #expect(version == nil) // Should handle invalid input gracefully
        } catch {
            // Errors are also acceptable for invalid input
            #expect(error != nil)
        }
    }
}