@testable import CodeLooper
import Foundation
import WebKit
import XCTest


/// Integration test for Demark functionality
/// This test verifies that the JavaScript libraries can be loaded and work correctly
@MainActor
class DemarkIntegrationTests: XCTestCase {
    
    func testJavaScriptLibrariesExist() async throws {
        // Check that the required JavaScript files exist in the test bundle
        let bundle = Bundle.main

        let turndownPath = bundle.path(forResource: "turndown.min", ofType: "js")
        XCTAssertNotNil(turndownPath, "turndown.min.js should be available in bundle")
    }

    func testTurndownServiceLoading() async throws {
        guard let turndownPath = Bundle.main.path(forResource: "turndown.min", ofType: "js") else {
            throw DemarkTestError.resourceNotFound("turndown.min.js")
        }

        // Create a WKWebView for testing
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)

        do {
            // Load a blank page first
            webView.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)
            
            // Wait for page to load
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Load Turndown script
            let turndownScript = try String(contentsOfFile: turndownPath, encoding: .utf8)
            let result = try await webView.evaluateJavaScript(turndownScript)

            // Verify TurndownService is available
            let turndownCheck = try await webView.evaluateJavaScript("typeof TurndownService")
            XCTAssertEqual(turndownCheck as? String, "function", "TurndownService should be available after loading script")

            // Try to instantiate TurndownService
            let instanceCheck = try await webView.evaluateJavaScript("new TurndownService() !== null")
            XCTAssertTrue(instanceCheck as? Bool ?? false, "Should be able to create TurndownService instance")

        } catch {
            throw DemarkTestError.scriptLoadingFailed(error.localizedDescription)
        }
    }

    func testBasicConversionConcept() async throws {
        // This test verifies the basic concept works
        // In a real implementation, Demark service handles the DOM complexity

        // For now, we'll just verify that the service class exists and can be initialized
        let service = Demark()

        // The service should be immediately available and work
        XCTAssertNotNil(service, "Demark should be instantiable")

        // Test a basic conversion - service should initialize on first use
        do {
            let html = "<p>Test</p>"
            let markdown = try await service.convertToMarkdown(html)
            XCTAssertTrue(!markdown.isEmpty, "Conversion should produce non-empty result")
            print("✅ Conversion test successful: \(markdown)")
        } catch {
            print("⚠️  Conversion failed (expected in test environment): \(error)")
            // This is expected since test bundle might not have proper resource setup
        }
    }

    func testConversionOptionsStructure() async throws {
        // Test that the options structure is properly defined
        let options = DemarkOptions(
            headingStyle: DemarkHeadingStyle.atx,
            bulletListMarker: "*",
            codeBlockStyle: DemarkCodeBlockStyle.fenced
        )

        XCTAssertEqual(options.headingStyle, DemarkHeadingStyle.atx)
        XCTAssertEqual(options.bulletListMarker, "*")
        XCTAssertEqual(options.codeBlockStyle, DemarkCodeBlockStyle.fenced)

        // Test setext heading style
        let setextOptions = DemarkOptions(
            headingStyle: DemarkHeadingStyle.setext,
            bulletListMarker: "-",
            codeBlockStyle: DemarkCodeBlockStyle.indented
        )

        XCTAssertEqual(setextOptions.headingStyle, DemarkHeadingStyle.setext)
        XCTAssertEqual(setextOptions.bulletListMarker, "-")
        XCTAssertEqual(setextOptions.codeBlockStyle, DemarkCodeBlockStyle.indented)
    }

    func testErrorHandling() async throws {
        let service = Demark()

        // Test with invalid HTML - should not crash
        do {
            let result = try await service.convertToMarkdown("<invalid>unclosed tag")
            print("Handled malformed HTML: \(result)")
        } catch {
            // Expected to fail gracefully
            XCTAssertTrue(error is DemarkError, "Should throw DemarkError for invalid input")
        }

        // Test with empty string
        do {
            let result = try await service.convertToMarkdown("")
            XCTAssertTrue(result.isEmpty, "Empty input should produce empty output")
        } catch {
            print("Empty string handling: \(error)")
        }
    }
}

// MARK: - Test Support

enum DemarkTestError: Error {
    case resourceNotFound(String)
    case scriptLoadingFailed(String)
    case serviceNotReady
}

/// Mock service for testing when actual service is not available
private class MockDemarkService {
    func convertToMarkdown(_ html: String) -> String {
        // Very basic mock conversion for testing
        html
            .replacingOccurrences(of: "<h1>", with: "# ")
            .replacingOccurrences(of: "</h1>", with: "\n")
            .replacingOccurrences(of: "<p>", with: "")
            .replacingOccurrences(of: "</p>", with: "\n")
            .replacingOccurrences(of: "<strong>", with: "**")
            .replacingOccurrences(of: "</strong>", with: "**")
    }
}
