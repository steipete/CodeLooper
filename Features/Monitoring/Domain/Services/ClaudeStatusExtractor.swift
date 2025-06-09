import Foundation
import AppKit
import Vision
@preconcurrency import ScreenCaptureKit
import CoreImage
import Diagnostics

// MARK: - Claude Status Extraction Service

/// Dedicated service for extracting live Claude status from terminal windows
/// using accessibility APIs and OCR fallback with modern ScreenCaptureKit
@MainActor
final class ClaudeStatusExtractor: ObservableObject, Loggable {
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let maxRetries = 2
        static let ocrConfidenceThreshold: Float = 0.7
        static let maxTextLength = 150
        static let supportedTerminals = ["ghostty", "terminal", "iterm", "warp"]
    }
    
    // MARK: - Public API
    
    /// Extract Claude status for a specific instance using multiple methods
    func extractStatus(for instance: ClaudeInstance) async -> ClaudeActivity {
        logger.debug("Extracting Claude status for PID \(instance.pid) in \(instance.folderName)")
        
        // Method 1: Try accessibility API first (fastest and most reliable)
        if let statusText = await extractViaAccessibility(instance: instance) {
            let activity = ClaudeActivity(text: statusText)
            logger.info("Extracted status via accessibility for \(instance.folderName): '\(activity.text)' (type: \(activity.type))")
            return activity
        }
        
        // Method 2: Try modern ScreenCaptureKit with OCR fallback
        if let statusText = await extractViaScreenCapture(instance: instance) {
            let activity = ClaudeActivity(text: statusText)
            logger.info("Extracted status via OCR for \(instance.folderName): '\(activity.text)' (type: \(activity.type))")
            return activity
        }
        
        // Fallback: Return idle state
        logger.debug("No status extracted for \(instance.folderName), returning idle")
        return .idle
    }
    
    // MARK: - Accessibility-based Extraction
    
    private nonisolated func extractViaAccessibility(instance: ClaudeInstance) async -> String? {
        logger.debug("Attempting accessibility extraction for \(instance.folderName)")
        
        let workspace = NSWorkspace.shared
        let terminalApps = workspace.runningApplications.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return Configuration.supportedTerminals.contains { terminal in
                bundleId.lowercased().contains(terminal)
            }
        }
        
        for terminalApp in terminalApps {
            if let content = getTerminalContent(terminalPID: terminalApp.processIdentifier, instance: instance) {
                if let parsedStatus = parseClaudeStatus(from: content) {
                    return parsedStatus
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func getTerminalContent(terminalPID: pid_t, instance: ClaudeInstance) -> String? {
        let app = AXUIElementCreateApplication(terminalPID)
        
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success,
              let windowsArray = windowsRef as? [AXUIElement] else {
            return nil
        }
        
        // Try to find the window that matches this specific Claude instance
        for window in windowsArray {
            // Get window title to help with matching
            var titleRef: CFTypeRef?
            var windowTitle = ""
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String {
                windowTitle = title
            }
            
            // Check if this window matches our instance
            if windowMatchesInstance(title: windowTitle, instance: instance) {
                if let content = extractTextFromWindow(window),
                   content.contains("esc to interrupt") {
                    logger.debug("Found matching window for instance \(instance.folderName) by title")
                    return content
                }
            }
            
            // Also check window content for matching
            if let content = extractTextFromWindow(window),
               windowContainsInstance(content: content, instance: instance),
               content.contains("esc to interrupt") {
                logger.debug("Found matching window for instance \(instance.folderName) by content")
                return content
            }
        }
        
        return nil
    }
    
    private nonisolated func extractTextFromWindow(_ window: AXUIElement) -> String? {
        let textAttributes = [
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXTitleAttribute as CFString,
            "AXDocument" as CFString,
            "AXText" as CFString
        ]
        
        for attribute in textAttributes {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, attribute, &valueRef) == .success,
               let text = valueRef as? String,
               !text.isEmpty,
               (text.contains("esc to interrupt") || text.contains("Claude")) {
                return text
            }
        }
        
        // Try recursive search in children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            
            for child in children {
                if let text = extractTextFromElementRecursive(child, maxDepth: 3) {
                    return text
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func extractTextFromElementRecursive(_ element: AXUIElement, maxDepth: Int) -> String? {
        guard maxDepth > 0 else { return nil }
        
        // Try to get text from current element
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
           let text = valueRef as? String,
           !text.isEmpty,
           (text.contains("esc to interrupt") || text.contains("Claude")) {
            return text
        }
        
        // Recursively check children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            
            for child in children {
                if let text = extractTextFromElementRecursive(child, maxDepth: maxDepth - 1) {
                    return text
                }
            }
        }
        
        return nil
    }
    
    // MARK: - ScreenCaptureKit-based Extraction
    
    private nonisolated func extractViaScreenCapture(instance: ClaudeInstance) async -> String? {
        logger.debug("Attempting ScreenCaptureKit extraction for \(instance.folderName) with TTY: \(instance.ttyPath)")
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Sort windows by how well they match the instance
            let matchingWindows = content.windows.compactMap { window -> (window: SCWindow, score: Int)? in
                guard let windowTitle = window.title,
                      let appName = window.owningApplication?.applicationName,
                      isTerminalApp(appName) else {
                    return nil
                }
                
                var score = 0
                
                // TTY match is most specific (highest score)
                if !instance.ttyPath.isEmpty {
                    let ttyName = URL(fileURLWithPath: instance.ttyPath).lastPathComponent
                    if windowTitle.contains(ttyName) {
                        score += 100
                    }
                }
                
                // Full working directory match
                if windowTitle.contains(instance.workingDirectory) {
                    score += 50
                }
                
                // Folder name match (less specific)
                if instance.folderName.count > 3 && windowTitle.contains(instance.folderName) {
                    score += 10
                }
                
                return score > 0 ? (window, score) : nil
            }.sorted { $0.score > $1.score }
            
            // Try the best matching window first
            for (window, score) in matchingWindows {
                logger.debug("Trying window '\(window.title ?? "")' with match score \(score) for instance \(instance.folderName)")
                
                guard let windowTitle = window.title else {
                    continue
                }
                
                logger.debug("Found matching terminal window: '\(windowTitle)' for \(instance.folderName)")
                
                if let statusText = await captureAndExtractText(from: window) {
                    return statusText
                }
            }
            
            return nil
        } catch {
            logger.error("ScreenCaptureKit extraction failed: \(error)")
            return nil
        }
    }
    
    private nonisolated func captureAndExtractText(from window: SCWindow) async -> String? {
        do {
            let configuration = SCStreamConfiguration()
            configuration.width = Int(window.frame.width)
            configuration.height = Int(window.frame.height)
            configuration.scalesToFit = true
            configuration.showsCursor = false
            
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            
            return await extractTextFromImage(image)
        } catch {
            logger.error("Window capture failed: \(error)")
            return nil
        }
    }
    
    private nonisolated func extractTextFromImage(_ image: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                // Preprocess image for better OCR
                guard let processedImage = self.preprocessImage(image) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.minimumTextHeight = 0.02
                
                let handler = VNImageRequestHandler(cgImage: processedImage, options: [:])
                
                do {
                    try handler.perform([request])
                    
                    guard let observations = request.results else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let recognizedStrings = observations.compactMap { observation -> String? in
                        guard observation.confidence > Configuration.ocrConfidenceThreshold else { return nil }
                        return observation.topCandidates(1).first?.string
                    }
                    
                    let fullText = recognizedStrings.joined(separator: "\n")
                    
                    if fullText.contains("esc to interrupt") || fullText.contains("interrupt") {
                        let status = self.parseClaudeStatus(from: fullText)
                        continuation.resume(returning: status)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    self.logger.debug("OCR failed: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private nonisolated func preprocessImage(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        
        // Enhance contrast and brightness while preserving colors
        guard let colorFilter = CIFilter(name: "CIColorControls") else { return nil }
        colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
        colorFilter.setValue(1.4, forKey: kCIInputContrastKey)
        colorFilter.setValue(0.1, forKey: kCIInputBrightnessKey)
        
        guard let colorOutput = colorFilter.outputImage else { return nil }
        
        // Apply sharpening
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return nil }
        sharpenFilter.setValue(colorOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.2, forKey: kCIInputSharpnessKey)
        
        guard let sharpOutput = sharpenFilter.outputImage else { return nil }
        
        let context = CIContext(options: nil)
        return context.createCGImage(sharpOutput, from: sharpOutput.extent)
    }
    
    // MARK: - Parsing and Matching Helpers
    
    private nonisolated func parseClaudeStatus(from text: String) -> String? {
        let cleanedText = text.replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Advanced status patterns with better flexibility
        let statusPatterns = [
            #"([A-Z]\w+[.…]*)\s*\((\d+)s[^)]*tokens[^)]*\)"#,  // Full pattern with activity name
            #"([A-Z]\w+[.…]*)\s*\((\d+)s[^)]*\d+k[^)]*\)"#,     // With "k" but no "tokens"
            #"([A-Z]\w+[.…]*)\s*\((\d+)s[^)]*\)"#               // Just activity with time
        ]
        
        for pattern in statusPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleanedText, options: [], range: NSRange(cleanedText.startIndex..., in: cleanedText)) {
                
                let nsString = cleanedText as NSString
                let fullMatch = nsString.substring(with: match.range)
                
                // Validate length and content
                if fullMatch.count <= Configuration.maxTextLength,
                   fullMatch.contains("("), fullMatch.contains("s") {
                    return fullMatch
                }
            }
        }
        
        // Fallback: look for any text with activity indicators
        let fallbackPatterns = [
            #"(Resolving|Syncing|Generating|Thinking|Branching|Compacting)[^(]*\([^)]*\)"#,
            #"\w+[.…]+[^(]*\([^)]*tokens[^)]*\)"#
        ]
        
        for pattern in fallbackPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleanedText, options: [], range: NSRange(cleanedText.startIndex..., in: cleanedText)) {
                
                let nsString = cleanedText as NSString
                let result = nsString.substring(with: match.range)
                
                if result.count <= Configuration.maxTextLength {
                    return result
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func windowContainsInstance(content: String, instance: ClaudeInstance) -> Bool {
        // First check if TTY is mentioned in the content
        if !instance.ttyPath.isEmpty {
            let ttyName = URL(fileURLWithPath: instance.ttyPath).lastPathComponent
            if content.contains(ttyName) {
                logger.debug("Window content matches instance by TTY: \(ttyName)")
                return true
            }
        }
        
        // Then check for specific working directory (more specific than just folder name)
        if content.contains(instance.workingDirectory) {
            logger.debug("Window content matches instance by working directory: \(instance.workingDirectory)")
            return true
        }
        
        // Last resort: check folder name, but only if it's reasonably unique
        if instance.folderName.count > 3 && instance.folderName != "/" && 
           content.contains(instance.folderName) {
            logger.debug("Window content matches instance by folder name: \(instance.folderName)")
            return true
        }
        
        return false
    }
    
    private nonisolated func windowMatchesInstance(title: String, instance: ClaudeInstance) -> Bool {
        // First check if TTY is in the title (most specific)
        if !instance.ttyPath.isEmpty {
            let ttyName = URL(fileURLWithPath: instance.ttyPath).lastPathComponent
            if title.contains(ttyName) {
                logger.debug("Window title matches instance by TTY: \(ttyName)")
                return true
            }
        }
        
        // Check for full working directory path in title
        if title.contains(instance.workingDirectory) {
            logger.debug("Window title matches instance by working directory: \(instance.workingDirectory)")
            return true
        }
        
        // Check folder name only if it's specific enough
        if instance.folderName.count > 3 && instance.folderName != "/" &&
           title.contains(instance.folderName) {
            // Make sure it's not just a partial match
            let components = title.components(separatedBy: "/")
            if components.contains(instance.folderName) {
                logger.debug("Window title matches instance by folder name: \(instance.folderName)")
                return true
            }
        }
        
        return false
    }
    
    private nonisolated func isTerminalApp(_ appName: String) -> Bool {
        Configuration.supportedTerminals.contains { terminal in
            appName.lowercased().contains(terminal)
        }
    }
}