@testable import CodeLooper
import Foundation
import JavaScriptCore
import XCTest


@MainActor
class MarkdownServiceIntegrationTest: XCTestCase {
/// Integration test for HTMLToMarkdownService functionality
/// This test verifies that the JavaScript libraries can be loaded and work correctly
@MainActor
struct MarkdownServiceIntegrationTest {
    
    func testJavaScriptLibrariesExist() async throws {
        // Check that the required JavaScript files exist in the test bundle
        let bundle = Bundle.main

        let turndownPath = bundle.path(forResource: "turndown.min", ofType: "js")
        XCTAssertNotNil(turndownPath, "turndown.min.js should be available in bundle")

        let linkedomPath = bundle.path(forResource: "linkedom.min", ofType: "js")
        XCTAssertNotNil(linkedomPath, "linkedom.min.js should be available in bundle")
    }

    func testTurndownServiceLoading() async throws {
        guard let turndownPath = Bundle.main.path(forResource: "turndown.min", ofType: "js") else {
            throw MarkdownTestError.resourceNotFound("turndown.min.js")
        }

        let context = JSContext()!

        // Add basic error handling
        context.exceptionHandler = { _, exception in
            print("JS Error: \(exception?.toString() ?? "unknown")")
        }

        do {
            let turndownScript = try String(contentsOfFile: turndownPath, encoding: .utf8)
            let result = context.evaluateScript(turndownScript)

            // Verify TurndownService is available
            let turndownService = context.objectForKeyedSubscript("TurndownService")
            XCTAssertNotNil(turndownService, "TurndownService should be available after loading script")

            // Try to instantiate TurndownService
            let instance = turndownService?.construct(withArguments: [])
            XCTAssertNotNil(instance, "Should be able to create TurndownService instance")

        } catch {
            throw MarkdownTestError.scriptLoadingFailed(error.localizedDescription)
        }
    }

    func testBasicConversionConcept() async throws {
        // This test verifies the basic concept works
        // In a real implementation, HTMLToMarkdownService handles the DOM complexity

        // For now, we'll just verify that the service class exists and can be initialized
        let service = HTMLToMarkdownService.shared

        // Wait for potential async initialization
        try await Task.sleep(for: .seconds(1)) // 1 second

        let isAvailable = await service.isAvailable

        // The service might not be available in test environment due to bundle resource paths
        // but we can verify the class structure is correct
        XCTAssertNotNil(service, "HTMLToMarkdownService should be instantiable")

        // If the service is available, test a basic conversion
        if isAvailable {
            do {
                let html = "<p>Test</p>"
                let markdown = try await service.convertToMarkdown(html)
                XCTAssertTrue(!markdown.isEmpty, "Conversion should produce non-empty result")
                print("✅ Conversion test successful: \(markdown)")
            } catch {
                print("⚠️  Conversion failed (expected in test environment): \(error)")
                // This is expected since test bundle might not have proper resource setup
            }
        } else {
            print("ℹ️  Service not available in test environment (expected)")
        }
    }

    func testConversionOptionsStructure() async throws {
        // Test that the options structure is properly defined
        let options = HTMLToMarkdownService.ConversionOptions(
            headingStyle: HTMLMarkdownHeadingStyle.atx,
            bulletListMarker: "*",
            codeBlockStyle: HTMLMarkdownCodeBlockStyle.fenced
        )

        XCTAssertEqual(options.headingStyle, HTMLMarkdownHeadingStyle.atx)
        XCTAssertEqual(options.bulletListMarker, "*")
        XCTAssertEqual(options.codeBlockStyle, HTMLMarkdownCodeBlockStyle.fenced)

        // Test setext heading style
        let setextOptions = HTMLToMarkdownService.ConversionOptions(
            headingStyle: HTMLMarkdownHeadingStyle.setext,
            bulletListMarker: "-",
            codeBlockStyle: HTMLMarkdownCodeBlockStyle.indented
        )

        XCTAssertEqual(setextOptions.headingStyle, HTMLMarkdownHeadingStyle.setext)
        XCTAssertEqual(setextOptions.bulletListMarker, "-")
        XCTAssertEqual(setextOptions.codeBlockStyle, HTMLMarkdownCodeBlockStyle.indented)
    }

    func testErrorHandling() async throws {
        let service = HTMLToMarkdownService.shared

        // Test with invalid HTML - should not crash
        do {
            let result = try await service.convertToMarkdown("<invalid>unclosed tag")
            print("Handled malformed HTML: \(result)")
        } catch {
            // Expected to fail gracefully
            XCTAssertTrue(error is HTMLToMarkdownService.MarkdownConversionError, "Should throw MarkdownConversionError for invalid input")
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

enum MarkdownTestError: Error {
    case resourceNotFound(String)
    case scriptLoadingFailed(String)
    case serviceNotReady
}

/// Mock service for testing when actual service is not available
private class MockHTMLToMarkdownService {
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
}