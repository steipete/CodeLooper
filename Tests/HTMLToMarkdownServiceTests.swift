import Foundation
import JavaScriptCore
import Testing

@testable import CodeLooper

/// Test suite for HTMLToMarkdownService
@MainActor
struct HTMLToMarkdownServiceTests {
    
    // MARK: - Initialization Tests
    
    @Test("Service can be initialized")
    func testServiceInitialization() async throws {
        let service = HTMLToMarkdownService.shared
        let initialAvailability = await service.isAvailable
        #expect(initialAvailability == false) // Initially false until libraries are loaded
        
        // Wait a bit for async initialization
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Service should now be available
        let finalAvailability = await service.isAvailable
        #expect(finalAvailability == true)
    }
    
    // MARK: - Basic HTML Conversion Tests
    
    @Test("Convert simple HTML to Markdown")
    func testSimpleHTMLConversion() async throws {
        let service = HTMLToMarkdownService.shared
        
        // Wait for service to be ready
        var attempts = 0
        var isReady = await service.isAvailable
        while !isReady && attempts < 10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
            isReady = await service.isAvailable
        }
        
        #expect(isReady == true)
        
        let html = "<h1>Hello World</h1>"
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("# Hello World"))
    }
    
    @Test("Convert paragraph HTML to Markdown")
    func testParagraphConversion() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<p>This is a simple paragraph.</p>"
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("This is a simple paragraph."))
    }
    
    @Test("Convert emphasized text")
    func testEmphasizedText() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<p>This is <em>emphasized</em> text.</p>"
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("_emphasized_"))
    }
    
    @Test("Convert strong text")
    func testStrongText() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<p>This is <strong>bold</strong> text.</p>"
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("**bold**"))
    }
    
    @Test("Convert links")
    func testLinkConversion() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<p>Visit <a href=\"https://example.com\">our website</a> for more info.</p>"
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("[our website](https://example.com)"))
    }
    
    @Test("Convert unordered list")
    func testUnorderedList() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = """
        <ul>
            <li>First item</li>
            <li>Second item</li>
            <li>Third item</li>
        </ul>
        """
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("- First item"))
        #expect(markdown.contains("- Second item"))
        #expect(markdown.contains("- Third item"))
    }
    
    @Test("Convert code block")
    func testCodeBlock() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<pre><code>let x = 42;</code></pre>"
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("```"))
        #expect(markdown.contains("let x = 42;"))
    }
    
    // MARK: - Complex HTML Tests
    
    @Test("Convert complex nested HTML")
    func testComplexHTML() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = """
        <article>
            <h1>Main Title</h1>
            <p>This is an <strong>important</strong> paragraph with <em>emphasis</em>.</p>
            <h2>Subsection</h2>
            <ul>
                <li>Item with <a href="https://example.com">link</a></li>
                <li>Another item</li>
            </ul>
            <p>Final paragraph with <code>inline code</code>.</p>
        </article>
        """
        
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("# Main Title"))
        #expect(markdown.contains("**important**"))
        #expect(markdown.contains("_emphasis_"))
        #expect(markdown.contains("## Subsection"))
        #expect(markdown.contains("- Item with [link](https://example.com)"))
        #expect(markdown.contains("`inline code`"))
    }
    
    @Test("Handle HTML with script tags (should be removed)")
    func testScriptTagRemoval() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = """
        <div>
            <p>Visible content</p>
            <script>alert('This should be removed');</script>
            <p>More visible content</p>
        </div>
        """
        
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("Visible content"))
        #expect(markdown.contains("More visible content"))
        #expect(!markdown.contains("alert"))
        #expect(!markdown.contains("script"))
    }
    
    @Test("Handle HTML with style tags (should be removed)")
    func testStyleTagRemoval() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = """
        <div>
            <p>Visible content</p>
            <style>body { color: red; }</style>
            <p>More visible content</p>
        </div>
        """
        
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("Visible content"))
        #expect(markdown.contains("More visible content"))
        #expect(!markdown.contains("body { color: red; }"))
        #expect(!markdown.contains("style"))
    }
    
    // MARK: - Custom Options Tests
    
    @Test("Convert with custom heading style")
    func testCustomHeadingStyle() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<h1>Test Heading</h1>"
        let options = HTMLToMarkdownService.ConversionOptions(
            headingStyle: .setext,
            bulletListMarker: "-",
            codeBlockStyle: .fenced
        )
        
        let markdown = try await service.convertToMarkdown(html, options: options)
        
        // Setext style uses underlines instead of #
        #expect(markdown.contains("Test Heading"))
        #expect(markdown.contains("="))
    }
    
    @Test("Convert with custom bullet marker")
    func testCustomBulletMarker() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        let options = HTMLToMarkdownService.ConversionOptions(
            headingStyle: .atx,
            bulletListMarker: "*",
            codeBlockStyle: .fenced
        )
        
        let markdown = try await service.convertToMarkdown(html, options: options)
        
        #expect(markdown.contains("* Item 1"))
        #expect(markdown.contains("* Item 2"))
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Handle empty HTML")
    func testEmptyHTML() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = ""
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.isEmpty)
    }
    
    @Test("Handle malformed HTML")
    func testMalformedHTML() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<p>Unclosed paragraph <strong>bold text"
        let markdown = try await service.convertToMarkdown(html)
        
        // Should still process what it can
        #expect(markdown.contains("Unclosed paragraph"))
        #expect(markdown.contains("bold text"))
    }
    
    @Test("Handle HTML with special characters")
    func testSpecialCharacters() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<p>Special chars: &amp; &lt; &gt; &quot; &#39;</p>"
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("Special chars:"))
        #expect(markdown.contains("&"))
        #expect(markdown.contains("<"))
        #expect(markdown.contains(">"))
    }
    
    @Test("Handle large HTML content")
    func testLargeHTML() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        // Generate a large HTML document
        var html = "<div>"
        for i in 1...100 {
            html += "<p>This is paragraph number \(i) with some <strong>bold</strong> text.</p>"
        }
        html += "</div>"
        
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("paragraph number 1"))
        #expect(markdown.contains("paragraph number 100"))
        #expect(markdown.components(separatedBy: "**bold**").count == 101) // 100 instances + original string
    }
    
    // MARK: - Performance Tests
    
    @Test("Performance: Multiple concurrent conversions")
    func testConcurrentConversions() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        let html = "<h1>Test</h1><p>This is a <strong>test</strong> paragraph.</p>"
        
        // Perform multiple concurrent conversions
        let tasks = (1...10).map { i in
            Task {
                return try await service.convertToMarkdown(html)
            }
        }
        
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var results: [String] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        #expect(results.count == 10)
        for result in results {
            #expect(result.contains("# Test"))
            #expect(result.contains("**test**"))
        }
    }
    
    // MARK: - Real-world HTML Tests
    
    @Test("Convert realistic sidebar content")
    func testRealisticSidebarContent() async throws {
        let service = HTMLToMarkdownService.shared
        
        try await waitForService(service)
        
        // Simulate realistic Cursor sidebar content
        let html = """
        <div class="sidebar-content">
            <div class="message-container">
                <div class="message-header">
                    <span class="author">Assistant</span>
                    <span class="timestamp">2:30 PM</span>
                </div>
                <div class="message-body">
                    <p>I can help you with that! Here's a code example:</p>
                    <pre><code class="language-swift">
func greet(name: String) -> String {
    return "Hello, \\(name)!"
}
                    </code></pre>
                    <p>This function takes a <code>name</code> parameter and returns a greeting.</p>
                    <ul>
                        <li>Uses string interpolation</li>
                        <li>Returns a String type</li>
                        <li>Simple and reusable</li>
                    </ul>
                </div>
            </div>
        </div>
        """
        
        let markdown = try await service.convertToMarkdown(html)
        
        #expect(markdown.contains("I can help you with that!"))
        #expect(markdown.contains("```swift"))
        #expect(markdown.contains("func greet"))
        #expect(markdown.contains("`name`"))
        #expect(markdown.contains("- Uses string interpolation"))
        #expect(markdown.contains("- Returns a String type"))
        #expect(markdown.contains("- Simple and reusable"))
    }
}

// MARK: - Helper Functions

/// Wait for the HTMLToMarkdownService to be ready
private func waitForService(_ service: HTMLToMarkdownService, maxAttempts: Int = 20) async throws {
    var attempts = 0
    var isReady = await service.isAvailable
    while !isReady && attempts < maxAttempts {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        attempts += 1
        isReady = await service.isAvailable
    }
    
    if !isReady {
        throw TestError.serviceNotReady
    }
}

enum TestError: Error {
    case serviceNotReady
}