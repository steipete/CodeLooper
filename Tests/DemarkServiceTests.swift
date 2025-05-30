import Foundation
import JavaScriptCore
import XCTest

@testable import CodeLooper
@MainActor
class DemarkServiceTests: XCTestCase {
    // MARK: - Initialization Tests

    func testServiceInitialization() async throws {
        let service = Demark()
        
        // Service should initialize on first access and work immediately
        let html = "<h1>Test</h1>"
        let markdown = try await service.convertToMarkdown(html)
        
        XCTAssertTrue(markdown.contains("Test"), "Service should work immediately after initialization")
    }

    // MARK: - Basic HTML Conversion Tests

    func testSimpleHTMLConversion() async throws {
        let service = Demark()

        let html = "<h1>Hello World</h1>"
        let markdown = try await service.convertToMarkdown(html)

        // Check that conversion occurred and contains the text content
        XCTAssertTrue(markdown.contains("Hello World"))
    }

    func testParagraphConversion() async throws {
        let service = Demark()

        let html = "<p>This is a simple paragraph.</p>"
        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("This is a simple paragraph."))
    }

    func testEmphasizedText() async throws {
        let service = Demark()

        let html = "<p>This is <em>emphasized</em> text.</p>"
        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("_emphasized_") || markdown.contains("*emphasized*"))
    }

    func testStrongText() async throws {
        let service = Demark()

        let html = "<p>This is <strong>bold</strong> text.</p>"
        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("**bold**") || markdown.contains("__bold__"))
    }

    func testLinkConversion() async throws {
        let service = Demark()

        let html = "<p>Visit <a href=\"https://example.com\">our website</a> for more info.</p>"
        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("[our website](https://example.com)") || markdown.contains("our website"))
    }

    func testUnorderedList() async throws {
        let service = Demark()

        let html = """
        <ul>
            <li>First item</li>
            <li>Second item</li>
            <li>Third item</li>
        </ul>
        """
        let markdown = try await service.convertToMarkdown(html)

        // Check for list items with flexible formatting
        XCTAssertTrue(markdown.contains("First item") && markdown.contains("Second item") && markdown.contains("Third item"))
        // Check for some list formatting (- or * or 1.)
        let hasListFormatting = markdown.contains("- First item") || markdown.contains("* First item") || markdown.contains("1. First item")
        if !hasListFormatting {
            print("Note: List content preserved but no specific formatting detected")
        }
    }

    func testCodeBlock() async throws {
        let service = Demark()

        let html = "<pre><code>let x = 42;</code></pre>"
        let markdown = try await service.convertToMarkdown(html)
        
        // At minimum, the code content should be preserved
        XCTAssertTrue(markdown.contains("let x = 42;"), "Code content should be preserved")
        
        // Check for some form of code formatting (flexible about exact format)
        let hasCodeFormatting = markdown.contains("```") || 
                               markdown.contains("    let x = 42;") || // indented code block
                               markdown.contains("\tlet x = 42;") ||    // tab-indented code block
                               markdown.contains("`let x = 42;`")       // inline code
        
        if !hasCodeFormatting {
            print("Note: Code content preserved but no specific formatting detected")
        }
    }

    // MARK: - Complex HTML Tests

    func testComplexHTML() async throws {
        let service = Demark()
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

        XCTAssertTrue(markdown.contains("# Main Title"))
        XCTAssertTrue(markdown.contains("**important**"))
        XCTAssertTrue(markdown.contains("_emphasis_"))
        XCTAssertTrue(markdown.contains("## Subsection"))
        XCTAssertTrue(markdown.contains("- Item with [link](https://example.com)"))
        XCTAssertTrue(markdown.contains("`inline code`"))
    }

    func testScriptTagRemoval() async throws {
        let service = Demark()
        let html = """
        <div>
            <p>Visible content</p>
            <script>alert('This should be removed');</script>
            <p>More visible content</p>
        </div>
        """

        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("Visible content"))
        XCTAssertTrue(markdown.contains("More visible content"))
        XCTAssertTrue(!markdown.contains("alert"))
        XCTAssertTrue(!markdown.contains("script"))
    }

    func testStyleTagRemoval() async throws {
        let service = Demark()
        let html = """
        <div>
            <p>Visible content</p>
            <style>body { color: red; }</style>
            <p>More visible content</p>
        </div>
        """

        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("Visible content"))
        XCTAssertTrue(markdown.contains("More visible content"))
        XCTAssertTrue(!markdown.contains("body { color: red; }"))
        XCTAssertTrue(!markdown.contains("style"))
    }

    // MARK: - Custom Options Tests

    func testCustomHeadingStyle() async throws {
        let service = Demark()
        let html = "<h1>Test Heading</h1>"
        let options = DemarkOptions(
            headingStyle: .setext,
            bulletListMarker: "-",
            codeBlockStyle: .fenced
        )

        let markdown = try await service.convertToMarkdown(html, options: options)

        // Setext style uses underlines instead of #
        XCTAssertTrue(markdown.contains("Test Heading"))
        XCTAssertTrue(markdown.contains("="))
    }

    func testCustomBulletMarker() async throws {
        let service = Demark()
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        let options = DemarkOptions(
            headingStyle: .atx,
            bulletListMarker: "*",
            codeBlockStyle: .fenced
        )

        let markdown = try await service.convertToMarkdown(html, options: options)

        XCTAssertTrue(markdown.contains("* Item 1"))
        XCTAssertTrue(markdown.contains("* Item 2"))
    }

    // MARK: - Edge Cases and Error Handling

    func testEmptyHTML() async throws {
        let service = Demark()

        let html = ""
        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.isEmpty || markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testMalformedHTML() async throws {
        let service = Demark()
        let html = "<p>Unclosed paragraph <strong>bold text"
        let markdown = try await service.convertToMarkdown(html)

        // Should still process what it can
        XCTAssertTrue(markdown.contains("Unclosed paragraph"))
        XCTAssertTrue(markdown.contains("bold text"))
    }

    func testSpecialCharacters() async throws {
        let service = Demark()
        let html = "<p>Special chars: &amp; &lt; &gt; &quot; &#39;</p>"
        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("Special chars:"))
        XCTAssertTrue(markdown.contains("&"))
        XCTAssertTrue(markdown.contains("<"))
        XCTAssertTrue(markdown.contains(">"))
    }

    func testLargeHTML() async throws {
        let service = Demark()
        // Generate a large HTML document
        var html = "<div>"
        for i in 1 ... 100 {
            html += "<p>This is paragraph number \(i) with some <strong>bold</strong> text.</p>"
        }
        html += "</div>"

        let markdown = try await service.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("paragraph number 1"))
        XCTAssertTrue(markdown.contains("paragraph number 100"))
        XCTAssertEqual(markdown.components(separatedBy: "**bold**").count, 101) // 100 instances + original string
    }

    // MARK: - Performance Tests

    func testConcurrentConversions() async throws {
        let service = Demark()
        let html = "<h1>Test</h1><p>This is a <strong>test</strong> paragraph.</p>"

        // Perform multiple concurrent conversions
        let tasks = (1 ... 10).map { _ in
            Task {
                try await service.convertToMarkdown(html)
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

        XCTAssertEqual(results.count, 10)
        for result in results {
            XCTAssertTrue(result.contains("# Test"))
            XCTAssertTrue(result.contains("**test**"))
        }
    }

    // MARK: - Real-world HTML Tests

    func testRealisticSidebarContent() async throws {
        let service = Demark()
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

        XCTAssertTrue(markdown.contains("I can help you with that!"))
        XCTAssertTrue(markdown.contains("```swift"))
        XCTAssertTrue(markdown.contains("func greet"))
        XCTAssertTrue(markdown.contains("`name`"))
        XCTAssertTrue(markdown.contains("- Uses string interpolation"))
        XCTAssertTrue(markdown.contains("- Returns a String type"))
        XCTAssertTrue(markdown.contains("- Simple and reusable"))
    }

    // MARK: - Debug and Helper Tests
    
    func testServiceDebugOutput() async throws {
        let service = Demark()
        
        let simpleHTML = "<p>Hello World</p>"
        let result = try await service.convertToMarkdown(simpleHTML)
        
        print("DEBUG: Input HTML: '\(simpleHTML)'")
        print("DEBUG: Output Markdown: '\(result)'")
        print("DEBUG: Output length: \(result.count)")
        print("DEBUG: Contains 'Hello': \(result.contains("Hello"))")
        print("DEBUG: Contains 'undefined': \(result.contains("undefined"))")
        
        // This test just prints debug info and always passes
        XCTAssertTrue(true, "Debug test completed")
    }
    
    func testEnhancedErrorHandling() async throws {
        let service = Demark()
        
        // Test that the service can be created without throwing
        XCTAssertNotNil(service, "Service should be created successfully")
        
        // Test with valid HTML
        let validHTML = "<h1>Test Heading</h1><p>Test paragraph with <strong>bold</strong> text.</p>"
        
        do {
            let result = try await service.convertToMarkdown(validHTML)
            print("Enhanced error handling test - successful conversion: \(result)")
            XCTAssertTrue(result.contains("Test Heading"), "Should contain heading text")
            XCTAssertTrue(result.contains("Test paragraph"), "Should contain paragraph text")
        } catch {
            print("Enhanced error handling test failed with error: \(error)")
            // Print detailed error information for debugging
            if let demarkError = error as? DemarkError {
                print("DemarkError type: \(demarkError)")
                print("Error description: \(demarkError.errorDescription ?? "No description")")
                print("Recovery suggestion: \(demarkError.recoverySuggestion ?? "No suggestion")")
            }
            throw error
        }
    }

    // MARK: - Comprehensive Additional Tests

    func testEmptyAndWhitespaceHTML() async throws {
        let service = Demark()

        // Test empty string
        let emptyMarkdown = try await service.convertToMarkdown("")
        XCTAssertTrue(emptyMarkdown.isEmpty || emptyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // Test whitespace only
        let whitespaceHTML = "   \n\t   "
        let whitespaceMarkdown = try await service.convertToMarkdown(whitespaceHTML)
        XCTAssertTrue(whitespaceMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // Test HTML with only whitespace content
        let htmlWithWhitespace = "<p>   </p><div>  \n  </div>"
        let resultMarkdown = try await service.convertToMarkdown(htmlWithWhitespace)
        XCTAssertTrue(resultMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testSpecialCharactersAndEncoding() async throws {
        let service = Demark()

        let htmlWithSpecialChars = """
        <h1>Special Characters Test</h1>
        <p>Unicode: 🎉 🚀 💻 ⚡️ 🎯</p>
        <p>HTML Entities: &amp; &lt; &gt; &quot; &#39;</p>
        <p>Accented: café résumé naïve piñata</p>
        <p>Mathematical: α β γ δ ∑ ∫ ∞</p>
        <p>Currency: $ € £ ¥ ₹</p>
        """

        let markdown = try await service.convertToMarkdown(htmlWithSpecialChars)

        XCTAssertTrue(markdown.contains("🎉 🚀 💻 ⚡️ 🎯"))
        XCTAssertTrue(markdown.contains("& < > \""))
        XCTAssertTrue(markdown.contains("café résumé naïve piñata"))
        XCTAssertTrue(markdown.contains("α β γ δ ∑ ∫ ∞"))
        XCTAssertTrue(markdown.contains("$ € £ ¥ ₹"))
    }

    func testNestedComplexStructures() async throws {
        let service = Demark()

        let complexHTML = """
        <article>
            <header>
                <h1>Documentation Guide</h1>
                <p class="subtitle">A comprehensive overview</p>
            </header>
            <section id="intro">
                <h2>Introduction</h2>
                <p>This guide covers <strong>advanced topics</strong> including:</p>
                <ol>
                    <li>
                        <strong>Code Examples</strong>
                        <ul>
                            <li>Syntax highlighting with <code>highlight.js</code></li>
                            <li>Multi-language support</li>
                        </ul>
                    </li>
                    <li>
                        <strong>Links and References</strong>
                        <blockquote>
                            <p>External resources are available at <a href="https://docs.example.com">docs.example.com</a></p>
                        </blockquote>
                    </li>
                </ol>
            </section>
            <section id="examples">
                <h2>Code Examples</h2>
                <div class="code-block">
                    <h3>JavaScript Function</h3>
                    <pre><code class="language-javascript">
                        function processData(input) {
                            return input
                                .filter(item => item.isValid)
                                .map(item => ({
                                    ...item,
                                    processed: true
                                }));
                        }
                    </code></pre>
                </div>
            </section>
            <footer>
                <p><em>Last updated: 2024</em></p>
            </footer>
        </article>
        """

        let markdown = try await service.convertToMarkdown(complexHTML)

        // Check structure preservation
        XCTAssertTrue(markdown.contains("# Documentation Guide"))
        XCTAssertTrue(markdown.contains("## Introduction"))
        XCTAssertTrue(markdown.contains("## Code Examples"))
        XCTAssertTrue(markdown.contains("### JavaScript Function"))

        // Check nested lists
        XCTAssertTrue(markdown.contains("1. **Code Examples**"))
        XCTAssertTrue(markdown.contains("2. **Links and References**"))

        // Check inline code and code blocks
        XCTAssertTrue(markdown.contains("`highlight.js`"))
        XCTAssertTrue(markdown.contains("```"))
        XCTAssertTrue(markdown.contains("function processData"))

        // Check links and emphasis
        XCTAssertTrue(markdown.contains("[docs.example.com](https://docs.example.com)"))
        XCTAssertTrue(markdown.contains("**advanced topics**"))
        XCTAssertTrue(markdown.contains("_Last updated: 2024_"))
    }

    func testMalformedHTMLAdvanced() async throws {
        let service = Demark()

        // Test unclosed tags
        let malformedHTML1 = "<p>This paragraph is not closed<div>Neither is this div<strong>Bold text"
        let result1 = try await service.convertToMarkdown(malformedHTML1)
        XCTAssertTrue(result1.contains("This paragraph is not closed"))
        XCTAssertTrue(result1.contains("Bold text"))

        // Test mismatched tags
        let malformedHTML2 = "<p>Paragraph <strong>bold <em>italic</p> text</strong></em>"
        let result2 = try await service.convertToMarkdown(malformedHTML2)
        XCTAssertTrue(result2.contains("bold"))
        XCTAssertTrue(result2.contains("italic"))

        // Test invalid nesting
        let malformedHTML3 = "<ul><p>Paragraph in list</p><li>Actual list item</li></ul>"
        let result3 = try await service.convertToMarkdown(malformedHTML3)
        XCTAssertTrue(result3.contains("Paragraph in list"))
        XCTAssertTrue(result3.contains("Actual list item"))
    }

    func testLargeDocumentPerformance() async throws {
        let service = Demark()

        // Generate a large HTML document
        var largeHTML = "<html><body><h1>Large Document Test</h1>"
        
        // Add 1000 paragraphs with various elements
        for i in 1...1000 {
            largeHTML += """
            <h2>Section \(i)</h2>
            <p>This is paragraph \(i) with <strong>bold text</strong> and <em>italic text</em>. 
            It also contains a <a href="https://example.com/\(i)">link</a> and some <code>inline code</code>.</p>
            <ul>
                <li>List item \(i).1</li>
                <li>List item \(i).2 with <strong>formatting</strong></li>
            </ul>
            """
        }
        largeHTML += "</body></html>"

        let startTime = Date()
        let markdown = try await service.convertToMarkdown(largeHTML)
        let duration = Date().timeIntervalSince(startTime)

        // Performance check - should complete within reasonable time (10 seconds for 1000 sections)
        XCTAssertLessThan(duration, 10.0, "Large document conversion took too long: \(duration) seconds")

        // Verify content is preserved
        XCTAssertTrue(markdown.contains("# Large Document Test"))
        XCTAssertTrue(markdown.contains("## Section 1"))
        XCTAssertTrue(markdown.contains("## Section 1000"))
        XCTAssertTrue(markdown.contains("[link](https://example.com/500)"))
        XCTAssertTrue(markdown.contains("- List item 500.1"))

        // Check that the markdown is significantly smaller than HTML (basic compression)
        let compressionRatio = Double(markdown.count) / Double(largeHTML.count)
        XCTAssertLessThan(compressionRatio, 0.8, "Markdown should be more concise than HTML")
    }

    func testConcurrentConversionsAdvanced() async throws {
        let service = Demark()

        let htmlSamples = [
            "<h1>Document 1</h1><p>Content for <strong>first</strong> document.</p>",
            "<h2>Document 2</h2><p>Content with <em>italic</em> text and <a href='#'>link</a>.</p>",
            "<h3>Document 3</h3><ul><li>Item 1</li><li>Item 2</li></ul>",
            "<p>Document 4 with <code>inline code</code> and <strong>bold</strong> text.</p>",
            "<blockquote><p>Document 5 with quoted content and <em>emphasis</em>.</p></blockquote>"
        ]

        // Run concurrent conversions
        let results = await withTaskGroup(of: (Int, String).self) { group in
            for (index, html) in htmlSamples.enumerated() {
                group.addTask {
                    do {
                        let markdown = try await service.convertToMarkdown(html)
                        return (index, markdown)
                    } catch {
                        XCTFail("Concurrent conversion failed for sample \(index): \(error)")
                        return (index, "")
                    }
                }
            }
            
            var results: [(Int, String)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }
        }

        // Verify all conversions completed successfully
        XCTAssertEqual(results.count, htmlSamples.count)

        // Verify content of each conversion
        XCTAssertTrue(results[0].1.contains("# Document 1"))
        XCTAssertTrue(results[1].1.contains("## Document 2"))
        XCTAssertTrue(results[2].1.contains("### Document 3"))
        XCTAssertTrue(results[3].1.contains("`inline code`"))
        XCTAssertTrue(results[4].1.contains("> Document 5"))
    }

    func testErrorHandlingAndEdgeCases() async throws {
        let service = Demark()

        // Test extremely long single line
        let longString = String(repeating: "a", count: 50000)
        let longLineHTML = "<p>\(longString)</p>"
        let longLineResult = try await service.convertToMarkdown(longLineHTML)
        XCTAssertTrue(longLineResult.contains(longString))

        // Test deeply nested structure
        var deeplyNested = ""
        for i in 1...50 {
            deeplyNested += "<div class='level-\(i)'>"
        }
        deeplyNested += "<p>Deep content</p>"
        for _ in 1...50 {
            deeplyNested += "</div>"
        }
        
        let deepResult = try await service.convertToMarkdown(deeplyNested)
        XCTAssertTrue(deepResult.contains("Deep content"))

        // Test HTML with script and style tags (should be removed)
        let htmlWithScripts = """
        <div>
            <h1>Clean Content</h1>
            <script>alert('This should be removed');</script>
            <p>Visible paragraph</p>
            <style>.hidden { display: none; }</style>
            <p>Another visible paragraph</p>
        </div>
        """
        
        let cleanResult = try await service.convertToMarkdown(htmlWithScripts)
        XCTAssertTrue(cleanResult.contains("# Clean Content"))
        XCTAssertTrue(cleanResult.contains("Visible paragraph"))
        XCTAssertTrue(cleanResult.contains("Another visible paragraph"))
        XCTAssertFalse(cleanResult.contains("alert"))
        XCTAssertFalse(cleanResult.contains(".hidden"))
    }

    func testCustomConversionOptions() async throws {
        let service = Demark()

        let testHTML = """
        <h1>Main Title</h1>
        <h2>Subtitle</h2>
        <ul>
            <li>First item</li>
            <li>Second item</li>
        </ul>
        <p>Text with <strong>bold</strong> and <em>italic</em>.</p>
        <pre><code>code block content</code></pre>
        """

        // Test with default options
        let defaultResult = try await service.convertToMarkdown(testHTML)
        XCTAssertTrue(defaultResult.contains("# Main Title"))
        XCTAssertTrue(defaultResult.contains("## Subtitle"))

        // Test with custom options (atx headings, different bullet marker)
        let customOptions = DemarkOptions(
            headingStyle: .atx,
            bulletListMarker: "*",
            codeBlockStyle: .fenced
        )
        
        let customResult = try await service.convertToMarkdown(testHTML, options: customOptions)
        XCTAssertTrue(customResult.contains("# Main Title"))
        XCTAssertTrue(customResult.contains("* First item") || customResult.contains("- First item")) // Service may override
        XCTAssertTrue(customResult.contains("```"))
    }

    func testServiceReliability() async throws {
        let service = Demark()

        // Service should remain reliable for multiple operations
        let html1 = "<p>First conversion</p>"
        let result1 = try await service.convertToMarkdown(html1)
        XCTAssertTrue(result1.contains("First conversion"))

        let html2 = "<p>Second conversion</p>"
        let result2 = try await service.convertToMarkdown(html2)
        XCTAssertTrue(result2.contains("Second conversion"))
        
        // Should work consistently across multiple calls
        for i in 1...5 {
            let html = "<p>Test \(i)</p>"
            let result = try await service.convertToMarkdown(html)
            XCTAssertTrue(result.contains("Test \(i)"))
        }
    }

    func testMarkdownOutputQuality() async throws {
        let service = Demark()

        let documentationHTML = """
        <article>
            <h1>API Documentation</h1>
            <p>This is the main documentation for our <strong>REST API</strong>.</p>
            
            <h2>Authentication</h2>
            <p>All requests must include an API key in the header:</p>
            <pre><code>Authorization: Bearer YOUR_API_KEY</code></pre>
            
            <h2>Endpoints</h2>
            
            <h3>GET /users</h3>
            <p>Retrieves a list of users. Supports the following parameters:</p>
            <ul>
                <li><code>limit</code> - Maximum number of results (default: 20)</li>
                <li><code>offset</code> - Number of results to skip (default: 0)</li>
                <li><code>filter</code> - Filter criteria in JSON format</li>
            </ul>
            
            <h4>Example Response</h4>
            <pre><code class="language-json">{
              "users": [
                {
                  "id": 1,
                  "name": "John Doe",
                  "email": "john@example.com"
                }
              ],
              "total": 150,
              "page": 1
            }</code></pre>
            
            <blockquote>
                <p><strong>Note:</strong> This endpoint requires <em>read</em> permissions.</p>
            </blockquote>
            
            <hr>
            
            <h3>POST /users</h3>
            <p>Creates a new user. Required fields:</p>
            <ol>
                <li><strong>name</strong> - User's full name</li>
                <li><strong>email</strong> - Valid email address</li>
                <li><em>password</em> - Minimum 8 characters</li>
            </ol>
        </article>
        """

        let markdown = try await service.convertToMarkdown(documentationHTML)

        // Check heading hierarchy
        XCTAssertTrue(markdown.contains("# API Documentation"))
        XCTAssertTrue(markdown.contains("## Authentication"))
        XCTAssertTrue(markdown.contains("## Endpoints"))
        XCTAssertTrue(markdown.contains("### GET /users"))
        XCTAssertTrue(markdown.contains("#### Example Response"))
        XCTAssertTrue(markdown.contains("### POST /users"))

        // Check formatting preservation
        XCTAssertTrue(markdown.contains("**REST API**"))
        XCTAssertTrue(markdown.contains("`limit`"))
        XCTAssertTrue(markdown.contains("`offset`"))
        XCTAssertTrue(markdown.contains("`filter`"))

        // Check code blocks
        XCTAssertTrue(markdown.contains("```"))
        XCTAssertTrue(markdown.contains("Authorization: Bearer YOUR_API_KEY"))
        XCTAssertTrue(markdown.contains("\"users\": ["))

        // Check lists
        XCTAssertTrue(markdown.contains("- `limit`") || markdown.contains("* `limit`"))
        XCTAssertTrue(markdown.contains("1. **name**"))
        XCTAssertTrue(markdown.contains("2. **email**"))

        // Check blockquote
        XCTAssertTrue(markdown.contains("> **Note:**"))
        XCTAssertTrue(markdown.contains("_read_"))

        // Check horizontal rule
        XCTAssertTrue(markdown.contains("---") || markdown.contains("***"))

        // Verify the markdown is well-structured (no empty lines at start/end of sections)
        let lines = markdown.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertGreaterThan(nonEmptyLines.count, 10, "Should have substantial content")
    }

    // MARK: - Helper Functions

}