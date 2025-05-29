import Diagnostics
import Foundation
import JavaScriptCore

actor HTMLToMarkdownService {
    // MARK: Lifecycle

    init() {
        initializeOnBackgroundQueue()
    }

    // MARK: Internal

    static let shared = HTMLToMarkdownService()

    /// Test if the service is properly initialized
    var isAvailable: Bool {
        isInitialized
    }

    /// Converts HTML string to Markdown asynchronously
    func convertToMarkdown(_ html: String) async throws -> String {
        // Wait for initialization if needed
        while !isInitialized {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                Task { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: MarkdownConversionError.serviceUnavailable)
                        return
                    }

                    let result = await self.performConversion(html: html)
                    switch result {
                    case let .success(markdown):
                        continuation.resume(returning: markdown)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Converts HTML with custom options
    func convertToMarkdown(_ html: String, options: ConversionOptions) async throws -> String {
        // Wait for initialization if needed
        while !isInitialized {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        guard let domParser = self.domParser,
              let turndownServiceClass = self.turndownServiceClass
        else {
            throw MarkdownConversionError.serviceUnavailable
        }

        do {
            // Parse the HTML into a DOM document using our reusable parser
            guard let document = domParser.invokeMethod("parseFromString", withArguments: [html, "text/html"]) else {
                throw MarkdownConversionError.domParsingFailed
            }

            // Create a new TurndownService instance with custom options
            guard let turndownService = turndownServiceClass.construct(withArguments: [
                [
                    "headingStyle": options.headingStyle.rawValue,
                    "hr": "---",
                    "bulletListMarker": options.bulletListMarker,
                    "codeBlockStyle": options.codeBlockStyle.rawValue,
                    "fence": "```",
                    "emDelimiter": "_",
                    "strongDelimiter": "**",
                    "linkStyle": "inlined",
                    "linkReferenceStyle": "full",
                ],
            ]) else {
                throw MarkdownConversionError.turndownNotLoaded
            }

            // Configure the service
            turndownService.invokeMethod("keep", withArguments: [["del", "ins", "sup", "sub"]])
            turndownService.invokeMethod("remove", withArguments: [["script", "style"]])

            // Convert the DOM document to Markdown
            guard let result = turndownService.invokeMethod("turndown", withArguments: [document]),
                  let markdown = result.toString()
            else {
                throw MarkdownConversionError.conversionFailed
            }

            return markdown

        } catch {
            self.logger.error("Markdown conversion with options failed: \(error)")
            throw error
        }
    }

    // MARK: Private

    // Serial queue ensures thread safety and consistent thread context for JSContext
    private let queue = DispatchQueue(label: "com.codelooper.markdown-conversion", qos: .userInitiated)
    private let logger = Logger(category: .utilities)
    private var isInitialized = false

    // These are created once and reused for all conversions
    private var jsVirtualMachine: JSVirtualMachine?
    private var jsContext: JSContext?
    private var domParser: JSValue?
    private var turndownServiceClass: JSValue?

    private nonisolated func initializeOnBackgroundQueue() {
        queue.async {
            Task { [weak self] in
                guard let self else { return }
                await self.initializeJavaScriptEnvironment()
            }
        }
    }

    private func initializeJavaScriptEnvironment() {
        // Create VM and context once on the background thread
        self.jsVirtualMachine = JSVirtualMachine()
        guard let vm = self.jsVirtualMachine else {
            self.logger.error("Failed to create JSVirtualMachine")
            return
        }

        self.jsContext = JSContext(virtualMachine: vm)
        guard let context = self.jsContext else {
            self.logger.error("Failed to create JSContext")
            return
        }

        // Set up console.log for debugging
        let consoleLog: @convention(block) (String) -> Void = { message in
            Logger(category: .utilities).debug("JS Console: \(message)")
        }
        context.setObject(unsafeBitCast(consoleLog, to: AnyObject.self),
                          forKeyedSubscript: "consoleLog" as NSString)
        context
            .evaluateScript(
                "console = { log: function() { consoleLog(Array.prototype.slice.call(arguments).join(' ')); } };"
            )

        // Load libraries and prepare reusable instances
        self.loadLibrariesAndPrepareInstances(in: context)
    }

    private func loadLibrariesAndPrepareInstances(in context: JSContext) {
        // Load linkedom first for DOM support
        guard let linkedomPath = Bundle.main.path(forResource: "linkedom.min", ofType: "js") else {
            logger.error("Failed to find linkedom.min.js in bundle")
            return
        }

        guard let turndownPath = Bundle.main.path(forResource: "turndown.min", ofType: "js") else {
            logger.error("Failed to find turndown.min.js in bundle")
            return
        }

        do {
            // Load linkedom for DOM support
            let linkedomJS = try String(contentsOfFile: linkedomPath, encoding: .utf8)
            context.evaluateScript(linkedomJS)
            logger.info("Successfully loaded linkedom.js library")

            // Load Turndown
            let turndownJS = try String(contentsOfFile: turndownPath, encoding: .utf8)
            context.evaluateScript(turndownJS)
            logger.info("Successfully loaded TurnDown.js library")

            // Configure default options
            let configScript = """
            // Make libraries available globally in this context
            if (typeof window === 'undefined') {
                var window = {};
            }
            window.TurndownService = TurndownService;
            window.linkedom = linkedom;
            """

            context.evaluateScript(configScript)

            // Create and store reusable instances
            if let linkedom = context.objectForKeyedSubscript("linkedom"),
               let domParserClass = linkedom.objectForKeyedSubscript("DOMParser"),
               let parser = domParserClass.construct(withArguments: [])
            {
                self.domParser = parser
                logger.info("Created reusable DOMParser instance")
            } else {
                logger.error("Failed to create DOMParser instance")
            }

            // Store the TurndownService class for creating instances
            if let turndownClass = context.objectForKeyedSubscript("TurndownService") {
                self.turndownServiceClass = turndownClass
                logger.info("Stored TurndownService class reference")
            } else {
                logger.error("Failed to get TurndownService class")
            }

            self.isInitialized = true

        } catch {
            logger.error("Failed to load JavaScript libraries: \(error)")
        }
    }

    private func performConversion(html: String) async -> Result<String, Error> {
        guard let domParser = self.domParser,
              let turndownServiceClass = self.turndownServiceClass
        else {
            return .failure(MarkdownConversionError.serviceUnavailable)
        }

        do {
            // Parse the HTML into a DOM document using our reusable parser
            guard let document = domParser.invokeMethod("parseFromString", withArguments: [html, "text/html"]) else {
                throw MarkdownConversionError.domParsingFailed
            }

            // Create a new TurndownService instance with default options
            guard let turndownService = turndownServiceClass.construct(withArguments: [
                [
                    "headingStyle": "atx",
                    "hr": "---",
                    "bulletListMarker": "-",
                    "codeBlockStyle": "fenced",
                    "fence": "```",
                    "emDelimiter": "_",
                    "strongDelimiter": "**",
                    "linkStyle": "inlined",
                    "linkReferenceStyle": "full",
                ],
            ]) else {
                throw MarkdownConversionError.turndownNotLoaded
            }

            // Configure the service
            turndownService.invokeMethod("keep", withArguments: [["del", "ins", "sup", "sub"]])
            turndownService.invokeMethod("remove", withArguments: [["script", "style"]])

            // Convert the DOM document to Markdown
            guard let result = turndownService.invokeMethod("turndown", withArguments: [document]),
                  let markdown = result.toString()
            else {
                throw MarkdownConversionError.conversionFailed
            }

            return .success(markdown)

        } catch {
            self.logger.error("Markdown conversion failed: \(error)")
            return .failure(error)
        }
    }
}

// MARK: - Supporting Types

extension HTMLToMarkdownService {
    enum MarkdownConversionError: LocalizedError {
        case turndownNotLoaded
        case serviceUnavailable
        case conversionFailed
        case domParserNotLoaded
        case domParsingFailed

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .turndownNotLoaded:
                "TurnDown.js library is not loaded"
            case .serviceUnavailable:
                "Markdown conversion service is unavailable"
            case .conversionFailed:
                "Failed to convert HTML to Markdown"
            case .domParserNotLoaded:
                "LinkedOM DOMParser is not loaded"
            case .domParsingFailed:
                "Failed to parse HTML with LinkedOM"
            }
        }
    }

    struct ConversionOptions {
        enum HeadingStyle: String {
            case setext
            case atx
        }

        enum CodeBlockStyle: String {
            case indented
            case fenced
        }

        var headingStyle: HeadingStyle = .atx
        var bulletListMarker: String = "-"
        var codeBlockStyle: CodeBlockStyle = .fenced
    }
}
