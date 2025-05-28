import Foundation
import AppKit
import Defaults
import Security
@preconcurrency import ScreenCaptureKit

@MainActor
public final class CursorScreenshotAnalyzer: ObservableObject {
    @Published public private(set) var isAnalyzing = false
    @Published public var lastAnalysis: ImageAnalysisResponse?
    @Published public var lastError: Error?
    
    private let aiManager: AIServiceManager
    private let imageScaleFactor: CGFloat = 0.5
    
    public init() {
        self.aiManager = AIServiceManager()
        configureAIManager()
    }
    
    public func analyzeCursorWindow() async throws -> ImageAnalysisResponse {
        isAnalyzing = true
        lastError = nil
        
        defer { isAnalyzing = false }
        
        guard let screenshot = try await captureCursorWindow() else {
            throw AIServiceError.invalidImage
        }
        
        let model = Defaults[.aiModel]
        let prompt = """
        Analyze this screenshot of a Cursor IDE window and provide a detailed description of:
        1. What code or file is currently being edited
        2. What the user appears to be working on
        3. Any visible errors, warnings, or issues
        4. The current state of the application (editing, debugging, etc.)
        5. Any AI assistance or code generation that might be happening
        
        Be specific and concise in your analysis.
        """
        
        let request = ImageAnalysisRequest(
            image: screenshot,
            prompt: prompt,
            model: model
        )
        
        let response = try await aiManager.analyzeImage(request)
        lastAnalysis = response
        return response
    }
    
    public func analyzeWithCustomPrompt(_ prompt: String) async throws -> ImageAnalysisResponse {
        isAnalyzing = true
        lastError = nil
        
        defer { isAnalyzing = false }
        
        guard let screenshot = try await captureCursorWindow() else {
            throw AIServiceError.invalidImage
        }
        
        let model = Defaults[.aiModel]
        let request = ImageAnalysisRequest(
            image: screenshot,
            prompt: prompt,
            model: model
        )
        
        let response = try await aiManager.analyzeImage(request)
        lastAnalysis = response
        return response
    }
    
    private func configureAIManager() {
        let provider = Defaults[.aiProvider]
        
        switch provider {
        case .openAI:
            let apiKey = loadAPIKeyFromKeychain()
            if !apiKey.isEmpty {
                aiManager.configure(provider: .openAI, apiKey: apiKey)
            }
        case .ollama:
            let baseURLString = Defaults[.ollamaBaseURL]
            if let url = URL(string: baseURLString) {
                aiManager.configure(provider: .ollama, baseURL: url)
            } else {
                aiManager.configure(provider: .ollama)
            }
        }
    }
    
    private func loadAPIKeyFromKeychain() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CODELOOPER_OPENAI_API_KEY",
            kSecAttrAccount as String: "api-key",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }
        
        return ""
    }
    
    private func captureCursorWindow() async throws -> NSImage? {
        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Find Cursor windows
        let cursorWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == "com.todesktop.230313mzl4w4u92" ||
            window.owningApplication?.applicationName == "Cursor"
        }
        
        guard let targetWindow = cursorWindows.first else {
            return nil
        }
        
        // Calculate scaled dimensions
        let scaledWidth = Int(targetWindow.frame.width * imageScaleFactor)
        let scaledHeight = Int(targetWindow.frame.height * imageScaleFactor)
        
        // Configure the screenshot to capture at scaled dimensions
        let configuration = SCStreamConfiguration()
        configuration.width = scaledWidth
        configuration.height = scaledHeight
        configuration.scalesToFit = true // Ensure scaling is enabled
        configuration.showsCursor = false
        
        // Create content filter for single window
        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        
        // Capture the image
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        
        // Convert CGImage to NSImage using scaled dimensions
        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: scaledWidth,
            height: scaledHeight
        ))
        
        return nsImage
    }
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
    }
}