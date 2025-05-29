import AppKit
import AXorcist
import Diagnostics
import Foundation
@preconcurrency import ScreenCaptureKit
import Security

@MainActor
class AIWindowAnalyzer {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    typealias StatusUpdateHandler = (String, WindowAIStatus) -> Void

    func analyzeWindow(_ window: MonitoredWindowInfo, statusHandler: @escaping StatusUpdateHandler) async {
        let windowId = window.id
        var status = WindowAIStatus(isAnalyzing: true, lastAnalysis: Date())
        statusHandler(windowId, status)

        logger.info("Starting AI analysis for window: \(window.windowTitle ?? windowId)")

        do {
            // Capture screenshot
            guard let screenshot = await captureWindowScreenshot(window: window) else {
                throw AnalysisError.screenshotFailed
            }

            // Save screenshot temporarily
            let screenshotPath = try await saveScreenshot(screenshot)
            defer { try? FileManager.default.removeItem(atPath: screenshotPath) }

            // Analyze with AI
            let analysisResult = await analyzeScreenshotWithAI(screenshotPath: screenshotPath)

            status.isAnalyzing = false
            status.status = analysisResult
            status.error = nil
            statusHandler(windowId, status)

            logger.info("AI analysis completed for window \(windowId): \(analysisResult)")

        } catch {
            status.isAnalyzing = false
            status.error = error.localizedDescription
            statusHandler(windowId, status)

            logger.error("AI analysis failed for window \(windowId): \(error)")
        }
    }

    // MARK: Private

    private enum AnalysisError: LocalizedError {
        case screenshotFailed
        case noAPIKey
        case saveFailed

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .screenshotFailed:
                "Failed to capture window screenshot"
            case .noAPIKey:
                "No API key configured"
            case .saveFailed:
                "Failed to save screenshot"
            }
        }
    }

    private let logger = Logger(category: .supervision)

    private func captureWindowScreenshot(window: MonitoredWindowInfo) async -> NSImage? {
        guard window.windowAXElement != nil else {
            logger.error("No AXElement for window screenshot")
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

            // Find the window by matching properties
            guard let scWindow = content.windows.first(where: { scw in
                scw.owningApplication?.bundleIdentifier == "com.todesktop.230313mzl4w4u92" &&
                    scw.title == window.windowTitle
            }) else {
                logger.error("Could not find SCWindow for capturing")
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let configuration = SCStreamConfiguration()
            configuration.width = Int(scWindow.frame.width)
            configuration.height = Int(scWindow.frame.height)

            let screenshot = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            return NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))

        } catch {
            logger.error("Screenshot capture failed: \(error)")
            return nil
        }
    }

    private func saveScreenshot(_ image: NSImage) async throws -> String {
        let jpegData = try ImageProcessor.convertToJPEG(image)
        
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "cursor_window_\(UUID().uuidString).jpg"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        try jpegData.write(to: fileURL)
        return fileURL.path


    }

    private func analyzeScreenshotWithAI(screenshotPath: String) async -> String {
        // Get API key from keychain
        guard let apiKey = loadAPIKeyFromKeychain() else {
            return "Error: No API key configured"
        }

        // Prepare the AI request
        let base64Image = encodeImageToBase64(path: screenshotPath) ?? ""

        // Call OpenAI Vision API
        do {
            let response = try await callOpenAIVisionAPI(
                apiKey: apiKey,
                base64Image: base64Image,
                prompt: """
                Analyze this Cursor editor window screenshot and determine:
                1. Is the user actively working? (typing, editing code, or interacting with the AI)
                2. What is the user doing?
                3. Any errors or issues visible?

                Respond in JSON format: {"working": true/false, "activity": "description", "issues": "any issues or null"}
                """
            )

            return response
        } catch {
            return "Analysis error: \(error.localizedDescription)"
        }
    }

    private func loadAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OpenAI-APIKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let apiKey = String(data: data, encoding: .utf8)
        {
            return apiKey
        }

        return nil
    }

    private func encodeImageToBase64(path: String) -> String? {
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return ImageProcessor.convertToBase64(imageData)
    }

    private func callOpenAIVisionAPI(apiKey: String, base64Image: String, prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4-vision-preview",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64Image)"]],
                    ],
                ],
            ],
            "max_tokens": 300,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw NSError(domain: "AIAnalysis", code: -1, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String
        {
            return content
        }

        return "Failed to parse AI response"
    }
}
