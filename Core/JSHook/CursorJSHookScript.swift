import Diagnostics
import Foundation

/// Errors that can occur when working with JSHook scripts
public enum CursorJSHookError: Error, LocalizedError {
    case scriptNotFound

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            "JavaScript hook script not found in bundle or development path"
        }
    }
}

/// Manages the JavaScript hook script resource
public enum CursorJSHookScript {
    /// Current version of the JavaScript hook
    public static let version = "1.2.2"

    /// Load the JavaScript hook template from resources
    public static func loadTemplate() throws -> String {
        let logger = Logger(category: .jshook)

        // Try to load from bundle first
        if let bundlePath = Bundle.main.path(forResource: "cursor-hook", ofType: "js", inDirectory: "JavaScript"),
           let content = try? String(contentsOfFile: bundlePath)
        {
            logger.debug("📦 Loaded JS hook script from bundle: \(bundlePath)")
            return content
        }

        // Try development path
        let devPath = FileManager.default.currentDirectoryPath + "/Resources/JavaScript/cursor-hook.js"
        if let content = try? String(contentsOfFile: devPath) {
            logger.debug("🛠️ Loaded JS hook script from development path: \(devPath)")
            return content
        }

        // No fallback - script must be loaded from file
        throw CursorJSHookError.scriptNotFound
    }

    /// Generate the JavaScript hook with the specified port
    /// - Parameter port: The WebSocket port to connect to
    /// - Returns: The complete JavaScript code ready for injection
    public static func generate(port: UInt16) throws -> String {
        let logger = Logger(category: .jshook)
        logger.debug("🔧 Generating JS hook script for port \(port)")

        // Get CodeLooper version from bundle
        let codeLooperVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        let template = try loadTemplate()
        let withPort = template.replacingOccurrences(of: "__CODELOOPER_PORT_PLACEHOLDER__", with: String(port))
        let generated = withPort.replacingOccurrences(of: "__CODELOOPER_VERSION_PLACEHOLDER__", with: codeLooperVersion)

        logger.info("✅ Generated JS hook script v\(version) for port \(port) (CodeLooper v\(codeLooperVersion))")
        logger
            .debug(
                "📊 Script stats: \(generated.count) chars, \(generated.components(separatedBy: .newlines).count) lines"
            )

        return generated
    }
}
