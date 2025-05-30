import Diagnostics
import Foundation
import WebKit

// MARK: - Supporting Types

enum DemarkHeadingStyle: String {
    case setext
    case atx
}

enum DemarkCodeBlockStyle: String {
    case indented
    case fenced
}

/// Conversion options for HTML to Markdown transformation using Turndown.js
///
/// This struct provides configuration options that control how HTML elements are converted to Markdown.
/// These options map directly to Turndown.js configuration options for consistent behavior.
///
/// ## Basic Options
///
/// - `headingStyle`: Controls how headings (`<h1>`, `<h2>`, etc.) are converted
/// - `bulletListMarker`: Sets the character used for unordered list items
/// - `codeBlockStyle`: Determines how code blocks are formatted
///
/// ## Example Usage
///
/// ```swift
/// // Use default options
/// let defaultOptions = DemarkOptions()
///
/// // Custom configuration
/// let customOptions = DemarkOptions(
///     headingStyle: .setext,
///     bulletListMarker: "*",
///     codeBlockStyle: .indented
/// )
///
/// let markdown = try await demark.convertToMarkdown(html, options: customOptions)
/// ```
///
/// ## Turndown.js Compatibility
///
/// These options correspond to Turndown.js options:
/// - `headingStyle` → `headingStyle` (setext or atx)
/// - `bulletListMarker` → `bulletListMarker` (-, +, or *)
/// - `codeBlockStyle` → `codeBlockStyle` (indented or fenced)
///
/// For additional Turndown.js options not yet exposed, the underlying JavaScript
/// environment can be extended through the conversion runtime.
struct DemarkOptions {
    /// Controls how HTML headings are converted to Markdown
    ///
    /// - `.atx`: Uses `#` prefix style (e.g., `# Heading 1`, `## Heading 2`)
    /// - `.setext`: Uses underline style for H1/H2 (e.g., `Heading\n=======`)
    ///
    /// **Default:** `.atx`
    ///
    /// **Turndown.js equivalent:** `headingStyle`
    var headingStyle: DemarkHeadingStyle = .atx
    
    /// Character used for unordered list items
    ///
    /// Valid values: `"-"`, `"+"`, or `"*"`
    ///
    /// **Default:** `"-"`
    ///
    /// **Turndown.js equivalent:** `bulletListMarker`
    ///
    /// ## Examples
    /// - `"-"` produces: `- List item`
    /// - `"*"` produces: `* List item`
    /// - `"+"` produces: `+ List item`
    var bulletListMarker: String = "-"
    
    /// Controls how code blocks are formatted in Markdown
    ///
    /// - `.fenced`: Uses triple backticks (```) for code blocks
    /// - `.indented`: Uses 4-space indentation for code blocks
    ///
    /// **Default:** `.fenced`
    ///
    /// **Turndown.js equivalent:** `codeBlockStyle`
    ///
    /// ## Examples
    /// - `.fenced`: 
    ///   ```
    ///   ```javascript
    ///   console.log('hello');
    ///   ```
    ///   ```
    /// - `.indented`:
    ///   ```
    ///       console.log('hello');
    ///   ```
    var codeBlockStyle: DemarkCodeBlockStyle = .fenced
    
    /// Default configuration with commonly used settings
    ///
    /// Provides a sensible default configuration:
    /// - ATX-style headings (`# Heading`)
    /// - Dash bullets (`- Item`)
    /// - Fenced code blocks (```)
    static let `default` = DemarkOptions()
}

/// WKWebView-based HTML to Markdown conversion.
///
/// This implementation uses WKWebView for proper DOM support:
/// - Real browser DOM environment
/// - Native HTML parsing
/// - Turndown.js with full DOM support
/// - Main thread execution required for WKWebView
@MainActor
final class ConversionRuntime {
    // MARK: Lifecycle
    
    init() {
        logger = Logger(category: .utilities)
    }
    
    // MARK: Internal
    
    /// Convert HTML to Markdown with optional configuration
    func htmlToMarkdown(_ html: String, options: DemarkOptions = .default) async throws -> String {
        logger.info("Starting HTML to Markdown conversion (input length: \(html.count))")
        
        // Ensure initialization
        if !isInitialized {
            logger.info("WKWebView environment not initialized, initializing now...")
            try await initializeJavaScriptEnvironment()
        }
        
        guard isInitialized else {
            logger.error("JavaScript environment failed to initialize")
            throw DemarkError.jsEnvironmentInitializationFailed
        }
        
        guard let webView = webView else {
            logger.error("WKWebView not available")
            throw DemarkError.webViewInitializationFailed
        }
        
        // Create JavaScript code to perform the conversion
        let optionsDict: [String: Any] = [
            "headingStyle": options.headingStyle.rawValue,
            "hr": "---",
            "bulletListMarker": options.bulletListMarker,
            "codeBlockStyle": options.codeBlockStyle.rawValue,
            "fence": "```",
            "emDelimiter": "_",
            "strongDelimiter": "**",
            "linkStyle": "inlined",
            "linkReferenceStyle": "full"
        ]
        
        // Escape the HTML for JavaScript
        let escapedHTML = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        // Convert options to JSON string
        let optionsData = try JSONSerialization.data(withJSONObject: optionsDict)
        guard let optionsString = String(data: optionsData, encoding: .utf8) else {
            throw DemarkError.invalidInput("Failed to serialize options")
        }
        
        let jsCode = """
        (function() {
            try {
                // Create TurndownService with options
                var turndownService = new TurndownService(\(optionsString));
                
                // Configure service
                turndownService.keep(['del', 'ins', 'sup', 'sub']);
                turndownService.remove(['script', 'style']);
                
                // Convert HTML to Markdown
                var markdown = turndownService.turndown("\(escapedHTML)");
                
                // Return result
                return markdown;
            } catch (error) {
                throw new Error('Conversion failed: ' + error.message);
            }
        })();
        """
        
        logger.debug("Executing conversion JavaScript...")
        
        do {
            let result = try await webView.evaluateJavaScript(jsCode)
            
            guard let markdown = result as? String else {
                logger.error("JavaScript result is not a string: \(type(of: result))")
                throw DemarkError.conversionFailed
            }
            
            logger.info("Conversion completed (output length: \(markdown.count))")
            
            // More nuanced handling of empty results
            if markdown.isEmpty && !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logger.debug("Conversion resulted in empty markdown for non-empty HTML input.")
                throw DemarkError.emptyResult
            }
            
            logger.debug("Conversion successful, returning result")
            return markdown
            
        } catch {
            logger.error("JavaScript exception during conversion: \(error)")
            throw DemarkError.jsException(error.localizedDescription)
        }
    }
    
    // MARK: Private
    
    private let logger: Logger
    private var isInitialized = false
    
    // WKWebView components
    private var webView: WKWebView?
    
    private func initializeJavaScriptEnvironment() async throws {
        logger.info("Initializing WKWebView environment for HTML to Markdown conversion")
        
        // Create WKWebView configuration
        let config = WKWebViewConfiguration()
        config.userContentController = WKUserContentController()
        
        // Create WKWebView
        webView = WKWebView(frame: .zero, configuration: config)
        guard webView != nil else {
            logger.error("Failed to create WKWebView")
            throw DemarkError.webViewInitializationFailed
        }
        logger.info("Successfully created WKWebView")
        
        // Load JavaScript libraries
        try await loadJavaScriptLibraries()
    }
    
    private func loadJavaScriptLibraries() async throws {
        logger.info("Loading JavaScript libraries into WKWebView")
        
        guard let webView = webView else {
            throw DemarkError.webViewInitializationFailed
        }
        
        // Find Turndown library - try different bundle access methods
        var possibleBundles = [
            Bundle.main,
            Bundle(for: Demark.self)
        ]
        
        // Also try the module bundle if available
        #if canImport(Foundation)
        possibleBundles.append(Bundle.module)
        #endif
        
        var turndownPath: String?
        
        for bundle in possibleBundles {
            if turndownPath == nil {
                turndownPath = bundle.path(forResource: "turndown.min", ofType: "js")
                if turndownPath != nil {
                    logger.info("Found turndown.min.js in bundle: \(bundle.bundleIdentifier ?? "unknown")")
                    break
                } else {
                    // Try in Resources/JavaScript subdirectory
                    if let resourcesPath = bundle.path(forResource: "Resources/JavaScript/turndown.min", ofType: "js") {
                        turndownPath = resourcesPath
                        logger.info("Found turndown.min.js in Resources/JavaScript subdirectory")
                        break
                    }
                }
            }
        }
        
        guard let turndownPath = turndownPath else {
            logger.error("turndown.min.js not found in any bundle")
            throw DemarkError.turndownLibraryNotFound
        }
        
        do {
            // Load a blank page first
            webView.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)
            
            // Wait for page to load
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Load Turndown library
            logger.info("Loading Turndown from: \(turndownPath)")
            let turndownScript = try String(contentsOfFile: turndownPath, encoding: .utf8)
            logger.info("Successfully read Turndown (\(turndownScript.count) characters)")
            
            _ = try await webView.evaluateJavaScript(turndownScript)
            logger.info("Successfully loaded Turndown JavaScript library")
            
            // Verify TurndownService is available
            let turndownCheck = try await webView.evaluateJavaScript("typeof TurndownService")
            guard let checkResult = turndownCheck as? String, checkResult == "function" else {
                logger.error("TurndownService was not properly loaded")
                throw DemarkError.libraryLoadingFailed("TurndownService not available")
            }
            
            isInitialized = true
            logger.info("WKWebView runtime ready 🎉")
            
        } catch let error as DemarkError {
            throw error
        } catch {
            logger.error("Failed to load JavaScript libraries: \(error)")
            throw DemarkError.libraryLoadingFailed(error.localizedDescription)
        }
    }
}

/// Service for converting HTML content to Markdown format.
///
/// Demark provides:
/// - Main-thread HTML to Markdown conversion using WKWebView
/// - Real browser DOM environment for Turndown.js
/// - Native HTML parsing support
/// - Async/await interface
@MainActor
final class Demark: Sendable {
    init() {
        conversionRuntime = ConversionRuntime()
    }
    
    /// Convert HTML content to Markdown format using Turndown.js
    ///
    /// This method provides a high-level interface for HTML to Markdown conversion,
    /// powered by the Turndown.js library running in a WKWebView environment.
    ///
    /// ## Features
    ///
    /// - **Real DOM Environment**: Uses WKWebView for proper HTML parsing and DOM manipulation
    /// - **Turndown.js Integration**: Leverages the industry-standard Turndown library
    /// - **Configurable Output**: Supports extensive formatting options via `DemarkOptions`
    /// - **CommonMark Compliance**: Generates standard Markdown that works across platforms
    /// - **Async/Await**: Modern Swift concurrency for non-blocking conversion
    ///
    /// ## Parameters
    ///
    /// - Parameter html: The HTML content to convert. Can include:
    ///   - Complete HTML documents with `<html>`, `<head>`, `<body>` tags
    ///   - HTML fragments (e.g., `<div><p>Content</p></div>`)
    ///   - Simple HTML snippets (e.g., `<strong>Bold text</strong>`)
    ///   - Complex nested structures with tables, lists, and formatting
    ///
    /// - Parameter options: Configuration options controlling the conversion behavior.
    ///   See `DemarkOptions` for available settings. Uses sensible defaults if not specified.
    ///
    /// ## Returns
    ///
    /// A `String` containing the converted Markdown content, formatted according to the specified options.
    ///
    /// ## Throws
    ///
    /// - `DemarkError.libraryLoadingFailed`: When Turndown.js fails to load or initialize
    /// - `DemarkError.conversionError`: When HTML parsing or conversion fails
    /// - `DemarkError.invalidInput`: When the provided HTML is malformed beyond recovery
    /// - `DemarkError.webViewError`: When WKWebView encounters an unrecoverable error
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let demark = Demark()
    /// 
    /// // Basic conversion with default options
    /// let html = "<h1>Title</h1><p>This is <strong>bold</strong> text.</p>"
    /// let markdown = try await demark.convertToMarkdown(html)
    /// // Result: "# Title\n\nThis is **bold** text."
    /// 
    /// // Custom conversion options
    /// let options = DemarkOptions(
    ///     headingStyle: .setext,
    ///     bulletListMarker: "*",
    ///     codeBlockStyle: .fenced
    /// )
    /// let customMarkdown = try await demark.convertToMarkdown(html, options: options)
    /// 
    /// // Complex HTML with tables and lists
    /// let complexHtml = """
    /// <div>
    ///     <h2>Features</h2>
    ///     <ul>
    ///         <li>Item 1</li>
    ///         <li>Item 2</li>
    ///     </ul>
    ///     <table>
    ///         <tr><th>Name</th><th>Value</th></tr>
    ///         <tr><td>Test</td><td>123</td></tr>
    ///     </table>
    /// </div>
    /// """
    /// let result = try await demark.convertToMarkdown(complexHtml)
    /// ```
    ///
    /// ## Performance Considerations
    ///
    /// - **Main Thread**: Must be called from the main thread due to WKWebView requirements
    /// - **Async Execution**: Non-blocking operation suitable for UI applications
    /// - **Memory Efficient**: Reuses WKWebView instance across multiple conversions
    /// - **Initialization Cost**: First conversion includes one-time setup overhead
    ///
    /// ## HTML Support
    ///
    /// Supports all standard HTML elements that Turndown.js can process:
    /// - Headings: `<h1>` through `<h6>`
    /// - Text formatting: `<strong>`, `<em>`, `<code>`, `<del>`, etc.
    /// - Lists: `<ul>`, `<ol>`, `<li>` with proper nesting
    /// - Links and images: `<a>`, `<img>` with attributes
    /// - Code blocks: `<pre>`, `<code>` with language detection
    /// - Tables: `<table>`, `<tr>`, `<td>`, `<th>` (basic support)
    /// - Block elements: `<div>`, `<p>`, `<blockquote>`, `<hr>`
    ///
    /// ## Thread Safety
    ///
    /// This method is marked with `@MainActor` and must be called from the main thread.
    /// The underlying WKWebView requires main thread access for proper DOM manipulation.
    ///
    /// ## Related
    ///
    /// - `DemarkOptions`: Configuration options for customizing conversion behavior
    /// - `DemarkError`: Error types that can be thrown during conversion
    /// - Turndown.js documentation: https://github.com/mixmark-io/turndown
    func convertToMarkdown(_ html: String, options: DemarkOptions = DemarkOptions()) async throws -> String {
        try await conversionRuntime.htmlToMarkdown(html, options: options)
    }
    
    // MARK: Private
    
    private let conversionRuntime: ConversionRuntime
}

// MARK: - Error Types

enum DemarkError: LocalizedError {
    case jsEnvironmentInitializationFailed
    case turndownLibraryNotFound
    case libraryLoadingFailed(String)
    case jsContextCreationFailed
    case turndownServiceCreationFailed
    case conversionFailed
    case emptyResult
    case invalidInput(String)
    case jsException(String)
    case bundleResourceMissing(String)
    case webViewInitializationFailed
    
    var errorDescription: String? {
        switch self {
        case .jsEnvironmentInitializationFailed:
            "Failed to initialize JavaScript environment"
        case .turndownLibraryNotFound:
            "turndown.min.js library not found in bundle"
        case .libraryLoadingFailed(let details):
            "Failed to load JavaScript libraries: \(details)"
        case .jsContextCreationFailed:
            "Failed to create JavaScript context"
        case .turndownServiceCreationFailed:
            "Failed to create TurndownService instance"
        case .conversionFailed:
            "Failed to convert HTML to Markdown"
        case .emptyResult:
            "Conversion produced empty result"
        case .invalidInput(let details):
            "Invalid input provided: \(details)"
        case .jsException(let details):
            "JavaScript execution error: \(details)"
        case .bundleResourceMissing(let resource):
            "Required bundle resource missing: \(resource)"
        case .webViewInitializationFailed:
            "Failed to initialize WebView"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .turndownLibraryNotFound:
            "Ensure the JavaScript libraries are included in the app bundle's Resources folder"
        case .jsEnvironmentInitializationFailed:
            "Check JavaScript library compatibility and availability"
        case .turndownServiceCreationFailed:
            "Verify TurndownService library is loaded correctly"
        case .conversionFailed:
            "Check HTML input format and JavaScript environment"
        case .emptyResult:
            "Verify HTML input contains convertible content"
        case .invalidInput:
            "Provide valid HTML string input"
        case .jsException:
            "Check JavaScript console logs for detailed error information"
        case .bundleResourceMissing:
            "Rebuild the project and ensure all resources are properly bundled"
        default:
            nil
        }
    }
}
