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

/// Conversion options for HTML to Markdown transformation
struct DemarkOptions {
    var headingStyle: DemarkHeadingStyle = .atx
    var bulletListMarker: String = "-"
    var codeBlockStyle: DemarkCodeBlockStyle = .fenced
    
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
        guard let webView = webView else {
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
        
        // Find Turndown library
        let possibleBundles = [
            Bundle.main,
            Bundle(for: Demark.self),
            Bundle.module
        ].compactMap { $0 }
        
        var turndownPath: String?
        
        for bundle in possibleBundles {
            if turndownPath == nil {
                turndownPath = bundle.path(forResource: "turndown.min", ofType: "js")
                if turndownPath != nil {
                    logger.info("Found turndown.min.js in bundle: \(bundle.bundleIdentifier ?? "unknown")")
                    break
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
            
            let result = try await webView.evaluateJavaScript(turndownScript)
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
    // MARK: Lifecycle
    
    init() {
        conversionRuntime = ConversionRuntime()
    }
    
    // MARK: Internal
    
    /// Convert HTML to Markdown with default options
    func convertToMarkdown(_ html: String) async throws -> String {
        try await conversionRuntime.htmlToMarkdown(html)
    }
    
    /// Convert HTML to Markdown with custom options
    func convertToMarkdown(_ html: String, options: DemarkOptions) async throws -> String {
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
