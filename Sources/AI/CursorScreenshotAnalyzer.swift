import Foundation
import AppKit
import Defaults
import Diagnostics
@preconcurrency import ScreenCaptureKit
import Vision
import OpenAI

@MainActor
public final class CursorScreenshotAnalyzer: ObservableObject {
    @Published public private(set) var isAnalyzing = false
    @Published public var lastAnalysis: ImageAnalysisResponse?
    @Published public var lastError: Error?
    
    private let imageScaleFactor: CGFloat = 1.0
    private static let maxAnalysisRetries = 2
    private static let retryDelaySeconds: TimeInterval = 2
    
    public init() {
        // AIServiceManager.shared will be used directly. It should be configured elsewhere (e.g., AppDelegate or when settings change)
        // We still might need to trigger its initial configuration if not done by app launch.
        // For now, assume AIServiceManager.shared is configured by the time this is used.
        // Or, ensure initial configuration is called: AIServiceManager.shared.configureWithCurrentDefaults()
        // This should ideally happen once at app startup, and then upon settings changes.
    }
    
    public func analyzeSpecificWindow(_ window: SCWindow?, customPrompt: String? = nil) async throws -> ImageAnalysisResponse {
        isAnalyzing = true
        lastError = nil
        defer { isAnalyzing = false }

        var attempts = 0
        var lastCaughtError: Error? = nil

        while attempts <= CursorScreenshotAnalyzer.maxAnalysisRetries {
            attempts += 1
            do {
                guard let screenshot = try await captureCursorWindow(targetSCWindow: window) else {
                    throw AIServiceError.invalidImage
                }

                let model = Defaults[.aiModel]
                let effectivePrompt = customPrompt ?? defaultAnalysisPrompt

                let request = ImageAnalysisRequest(
                    image: screenshot,
                    prompt: effectivePrompt,
                    model: model
                )

                let response = try await AIServiceManager.shared.analyzeImage(request)
                lastAnalysis = response
                return response // Success, exit loop
            } catch let error as AIServiceError {
                lastCaughtError = error
                logger.warning("AI analysis attempt \(attempts) failed with error: \(error.localizedDescription)")
                
                // Decide if we should retry
                switch error {
                case .networkError, .serviceUnavailable, .invalidResponse: // Added .invalidResponse as potentially transient
                    if attempts > CursorScreenshotAnalyzer.maxAnalysisRetries {
                        logger.error("Max retries reached for AI analysis. Error: \(error.localizedDescription)")
                        throw error // Rethrow after max retries
                    }
                    // Wait before retrying
                    let delay = UInt64(CursorScreenshotAnalyzer.retryDelaySeconds * 1_000_000_000) // Nanoseconds
                    logger.info("Retrying AI analysis in \(CursorScreenshotAnalyzer.retryDelaySeconds) seconds...")
                    try? await Task.sleep(nanoseconds: delay)
                    continue // Next attempt
                default:
                    throw error // Non-retryable AIServiceError, rethrow immediately
                }
            } catch {
                // Catch any other non-AIServiceError
                lastCaughtError = error
                logger.error("AI analysis attempt \(attempts) failed with unexpected error: \(error.localizedDescription)")
                throw error // Rethrow immediately, typically not transient
            }
        }
        // Should not be reached if logic is correct, but as a fallback:
        throw lastCaughtError ?? AIServiceError.serviceUnavailable // Fallback error
    }
    
    public func analyzeCursorWindow() async throws -> ImageAnalysisResponse {
        return try await analyzeSpecificWindow(nil)
    }
    
    public func analyzeWithCustomPrompt(_ prompt: String) async throws -> ImageAnalysisResponse {
        return try await analyzeSpecificWindow(nil, customPrompt: prompt)
    }
    
    private var defaultAnalysisPrompt: String {
        """
        Analyze this screenshot of a Cursor IDE window and provide a detailed description of:
        1. What code or file is currently being edited
        2. What the user appears to be working on
        3. Any visible errors, warnings, or issues
        4. The current state of the application (editing, debugging, etc.)
        5. Any AI assistance or code generation that might be happening
        
        Be specific and concise in your analysis.
        """
    }
    
    private func loadAPIKeyFromKeychain() -> String {
        return APIKeyService.shared.loadOpenAIKey()
    }
    
    public func captureCursorWindow(targetSCWindow: SCWindow? = nil) async throws -> NSImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        var windowToCapture: SCWindow? = targetSCWindow

        if windowToCapture == nil {
            windowToCapture = content.windows.first { window in
                window.owningApplication?.bundleIdentifier == "com.todesktop.230313mzl4w4u92" ||
                window.owningApplication?.applicationName == "Cursor"
            }
        }

        guard let finalWindowToCapture = windowToCapture else {
            logger.info("No suitable Cursor window found for capture.")
            return nil
        }
        
        let scaledWidth = Int(finalWindowToCapture.frame.width * imageScaleFactor)
        let scaledHeight = Int(finalWindowToCapture.frame.height * imageScaleFactor)
        
        let configuration = SCStreamConfiguration()
        configuration.width = scaledWidth
        configuration.height = scaledHeight
        configuration.scalesToFit = true
        configuration.showsCursor = false
        
        let filter = SCContentFilter(desktopIndependentWindow: finalWindowToCapture)
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        
        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: scaledWidth,
            height: scaledHeight
        ))
        
        return nsImage
    }
    
    private let logger = Logger(category: .api)
}

public extension CursorScreenshotAnalyzer {
    struct AnalysisPrompts {
        public static let generalAnalysis = """
        Analyze this Cursor IDE screenshot and describe what's happening.
        """
        
        public static let errorDetection = """
        Identify any errors, warnings, or issues visible in this Cursor IDE screenshot.
        Focus on syntax errors, runtime errors, or any problem indicators.
        """
        
        public static let progressCheck = """
        Analyze the current state of work in this Cursor IDE screenshot.
        What task appears to be in progress? Is AI assistance being used?
        """
        
        public static let codeUnderstanding = """
        Explain what the code in this Cursor IDE screenshot is doing.
        Focus on the main functionality and purpose.
        """
        
        public static let working = """
You will receive a screenshot of a VS Code-like window that may include a chat sidebar.

Your task is to determine if the AI is currently "Generating" content.

1.  Scan the **entire image** carefully.
2.  Look for the exact word **"Generating"** (case-insensitive). This word might be followed by ellipses (e.g., "Generating..."). It can appear anywhere in a chat or output section.
3.  Based on your finding:
    *   If "Generating" (or "Generating...") is present, respond with the following JSON object:
        `{"status": "working", "reason": "AI is actively generating content."}`
    *   If "Generating" (or "Generating...") is **not** present, respond with the following JSON object:
        `{"status": "not_working", "reason": "AI is not currently generating content."}`
4.  **Important Rules:**
    *   Your entire response must be **only** the single JSON object specified above.
    *   Ignore all other elements in the screenshot (code, other sidebars, buttons, icons, timestamps, etc.). Your focus is solely on the "Generating" status.
    *   If you are uncertain whether "Generating" is present, default to "not_working". A false negative is preferred over a false positive.
"""
        
        public static let codeEditing = "Is the user actively editing code in this screenshot? Answer yes or no."
    }
}
