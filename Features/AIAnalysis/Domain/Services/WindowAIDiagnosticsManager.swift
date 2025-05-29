import AXorcist
import Combine
import Defaults
import Diagnostics
import Foundation
@preconcurrency import ScreenCaptureKit
import SwiftUI // For ObservableObject

/// Manages AI-powered diagnostics and analysis of Cursor windows for intelligent interventions.
///
/// WindowAIDiagnosticsManager provides:
/// - Screenshot capture of Cursor windows for AI analysis
/// - Integration with AI providers (OpenAI, Ollama) for visual understanding
/// - Context enrichment with file paths and git repository information
/// - Intelligent error detection and solution suggestions
/// - Coordination with the intervention system for automated fixes
///
/// The manager uses computer vision and LLM capabilities to understand
/// what's happening in Cursor windows, detect errors that might not be
/// accessible through standard APIs, and suggest appropriate interventions.
/// This enables handling of complex scenarios that require visual context.
@MainActor
class WindowAIDiagnosticsManager: ObservableObject, Loggable {
    // MARK: Lifecycle

    private init() { // Make init private for singleton
        self.documentPathTracker = DocumentPathTracker(gitRepositoryMonitor: gitRepositoryMonitor)
        logger.info("WindowAIDiagnosticsManager initialized")
        // Observe CursorMonitor's apps
        CursorMonitor.shared.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                self?.updateMonitoredWindows(apps)
            }
            .store(in: &cancellables)

        // Add observer for AI service configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAIServiceConfigured),
            name: .AIServiceConfigured,
            object: nil
        )
    }

    // MARK: Public

    /// Check if a document path exists on disk
    public func documentPathExists(_ path: String) -> Bool {
        documentPathTracker.documentPathExists(path)
    }

    // MARK: Internal

    static let shared = WindowAIDiagnosticsManager() // <<< ADDED shared instance

    @Published var windowStates: [String: MonitoredWindowInfo] = [:] // Keyed by MonitoredWindowInfo.id

    func toggleLiveWatching(for windowId: String) {
        guard var windowInfo = windowStates[windowId] else { return }
        windowInfo.isLiveWatchingEnabled.toggle()
        windowInfo.saveAISettings() // Persist change

        if windowInfo.isLiveWatchingEnabled {
            windowInfo.lastAIAnalysisStatus = .pending // Set to pending to trigger analysis
            // Clear previous screenshot to ensure fresh analysis when re-enabled
            previousScreenshots.removeValue(forKey: windowId)
        } else {
            windowInfo.lastAIAnalysisStatus = .off
            // Clear previous screenshot when disabled
            previousScreenshots.removeValue(forKey: windowId)
        }

        windowStates[windowId] = windowInfo
        setupTimer(for: windowInfo) // Re-setup timer which will start/stop it
        objectWillChange.send()
    }

    func enableLiveWatchingForAllWindows() {
        for windowId in windowStates.keys {
            guard var windowInfo = windowStates[windowId] else { continue }
            if !windowInfo.isLiveWatchingEnabled {
                windowInfo.isLiveWatchingEnabled = true
                windowInfo.saveAISettings()
                windowInfo.lastAIAnalysisStatus = .pending
                previousScreenshots.removeValue(forKey: windowId)
                windowStates[windowId] = windowInfo
                setupTimer(for: windowInfo)
            }
        }
        objectWillChange.send()
    }

    func disableLiveWatchingForAllWindows() {
        for windowId in windowStates.keys {
            guard var windowInfo = windowStates[windowId] else { continue }
            if windowInfo.isLiveWatchingEnabled {
                windowInfo.isLiveWatchingEnabled = false
                windowInfo.saveAISettings()
                windowInfo.lastAIAnalysisStatus = .off
                previousScreenshots.removeValue(forKey: windowId)
                windowStates[windowId] = windowInfo
                setupTimer(for: windowInfo)
            }
        }
        objectWillChange.send()
    }

    // Cleanup method that must be called from MainActor context
    func cleanup() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        previousScreenshots.removeAll()
    }

    // MARK: Private

    private var timers: [String: Timer] = [:]
    private let screenshotAnalyzer = CursorScreenshotAnalyzer()
    private let gitRepositoryMonitor = GitRepositoryMonitor()
    private let documentPathTracker: DocumentPathTracker
    private var cancellables = Set<AnyCancellable>()
    private var previousScreenshots: [String: Data] = [:] // Store previous screenshot data for comparison

    // Notification handler
    @objc private func handleAIServiceConfigured() {
        logger.info("Received AIServiceConfigured notification. Re-checking windows with API key errors.")
        Task {
            await MainActor.run {
                for (id, windowInfo) in windowStates where windowInfo.isLiveWatchingEnabled {
                    if windowInfo.lastAIAnalysisStatus == .error,
                       let message = windowInfo.lastAIAnalysisResponseMessage,
                       message.lowercased().contains("api key") || message.lowercased()
                       .contains("configure it in settings")
                    {
                        logger
                            .info(
                                "Window \(id) previously had API key error. Resetting to pending and re-triggering analysis."
                            )
                        var mutableWindowInfo = windowInfo // Create mutable copy
                        mutableWindowInfo.lastAIAnalysisStatus = .pending
                        mutableWindowInfo.lastAIAnalysisResponseMessage = "Retrying after API key update..."
                        windowStates[id] = mutableWindowInfo

                        // Invalidate existing timer and schedule immediate analysis
                        timers[id]?.invalidate()
                        Task { await performAIAnalysis(for: id) } // Trigger immediately
                        // Restart periodic timer with global interval
                        self.setupTimer(for: mutableWindowInfo)
                    }
                }
            }
        }
    }

    private func updateMonitoredWindows(_ apps: [MonitoredAppInfo]) {
        var newWindowStates: [String: MonitoredWindowInfo] = [:]
        var activeWindowIDs = Set<String>()

        for app in apps {
            for window in app.windows { // window is a MonitoredWindowInfo, already initialized with Defaults
                activeWindowIDs.insert(window.id)

                // Get existing state or use the new window info (which has loaded its persisted settings)
                var currentWindowInfo = self.windowStates[window.id] ?? window

                // The MonitoredWindowInfo 'window' from CursorMonitor already loaded its persisted settings.
                // If we have an existing currentWindowInfo in self.windowStates, we should ensure its
                // core properties (title, axElement, documentPath) are updated from the fresh 'window' object,
                // while preserving its AI-related state if it makes sense or re-evaluating.
                // For simplicity and to ensure fresh data from CursorMonitor is primary for non-AI state:
                if self.windowStates[window.id] != nil { // If we had a previous state for this ID
                    // Preserve AI settings from existing state, update other details from new scan
                    let previousAIState = self.windowStates[window.id]!
                    currentWindowInfo.windowTitle = window.windowTitle
                    currentWindowInfo.windowAXElement = window.windowAXElement
                    currentWindowInfo.documentPath = window.documentPath
                    currentWindowInfo.isPaused = window.isPaused // from CursorMonitor
                    // Update window state properties (minimized, hidden, etc.)
                    currentWindowInfo.updateWindowState()
                    // Persisted AI settings (isLiveWatchingEnabled, aiAnalysisIntervalSeconds) are loaded by
                    // MonitoredWindowInfo init.
                    // Runtime AI state (lastAIAnalysisStatus, etc.) from previousAIState should be kept.
                    currentWindowInfo.lastAIAnalysisStatus = previousAIState.lastAIAnalysisStatus
                    currentWindowInfo.lastAIAnalysisTimestamp = previousAIState.lastAIAnalysisTimestamp
                    currentWindowInfo.lastAIAnalysisResponseMessage = previousAIState.lastAIAnalysisResponseMessage
                    // Ensure isLiveWatchingEnabled and aiAnalysisIntervalSeconds reflect the latest persisted values
                    // (which should be the case as MonitoredWindowInfo loaded them, but re-assigning from potentially
                    // more up-to-date 'window' object which was just created by CursorMonitor is safer)
                    currentWindowInfo.isLiveWatchingEnabled = window.isLiveWatchingEnabled
                    currentWindowInfo.aiAnalysisIntervalSeconds = window.aiAnalysisIntervalSeconds
                } // else, currentWindowInfo is just 'window', which is correctly initialized.

                // Adjust initial status if live watching is enabled but current status is .off
                if currentWindowInfo.isLiveWatchingEnabled && currentWindowInfo.lastAIAnalysisStatus == .off {
                    currentWindowInfo.lastAIAnalysisStatus = .pending
                } else if !currentWindowInfo.isLiveWatchingEnabled {
                    currentWindowInfo.lastAIAnalysisStatus = .off
                }

                newWindowStates[window.id] = currentWindowInfo

                // Only setup timer if this is a new window or if monitoring state changed
                let existingWindow = windowStates[window.id]
                let shouldSetupTimer = existingWindow == nil ||
                    existingWindow?.isLiveWatchingEnabled != currentWindowInfo.isLiveWatchingEnabled

                if shouldSetupTimer {
                    setupTimer(for: currentWindowInfo)
                }

                // Track document path and fetch Git repository info for this window
                if let documentPath = currentWindowInfo.documentPath {
                    Task {
                        // Record this document access for this specific window
                        await self.documentPathTracker.recordDocumentAccess(documentPath, forWindow: window.id)

                        // Get repository for this window (with per-window fallback heuristic)
                        if let gitRepo = await self.documentPathTracker.getRepositoryForDocument(documentPath, forWindow: window.id) {
                            DispatchQueue.main.async {
                                if var updatedWindowInfo = self.windowStates[window.id] {
                                    updatedWindowInfo.gitRepository = gitRepo
                                    self.windowStates[window.id] = updatedWindowInfo
                                    self.objectWillChange.send()
                                }
                            }
                        }
                    }
                } else {
                    // For windows without document paths, try to get the most frequent repository for this window
                    Task {
                        if let gitRepo = await self.documentPathTracker.getMostFrequentRepository(forWindow: window.id) {
                            DispatchQueue.main.async {
                                if var updatedWindowInfo = self.windowStates[window.id] {
                                    updatedWindowInfo.gitRepository = gitRepo
                                    self.windowStates[window.id] = updatedWindowInfo
                                    self.objectWillChange.send()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Remove states and timers for windows that no longer exist
        let windowsToRemove = Set(self.windowStates.keys).subtracting(activeWindowIDs)
        for windowID in windowsToRemove {
            timers[windowID]?.invalidate()
            timers.removeValue(forKey: windowID)
            previousScreenshots.removeValue(forKey: windowID)
            // Clear per-window tracking data
            documentPathTracker.clearTracking(forWindow: windowID)
            // No need to remove from windowStates here, as newWindowStates will become self.windowStates
        }

        // Update the window states
        self.windowStates = newWindowStates
        objectWillChange.send()
    }

    private func setupTimer(for windowInfo: MonitoredWindowInfo) {
        timers[windowInfo.id]?.invalidate() // Invalidate existing timer
        let globalInterval = TimeInterval(Defaults[.aiGlobalAnalysisIntervalSeconds])

        if windowInfo.isLiveWatchingEnabled, Defaults[.isGlobalMonitoringEnabled] {
            logger
                .info(
                    "Setting up AI analysis timer for window: \(windowInfo.windowTitle ?? windowInfo.id) with global interval \(globalInterval)s"
                )
            timers[windowInfo.id] = Timer
                .scheduledTimer(withTimeInterval: globalInterval, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let self,
                              Defaults[.isGlobalMonitoringEnabled],
                              var currentInfo = self.windowStates[windowInfo.id],
                              currentInfo.isLiveWatchingEnabled
                        else {
                            self?.timers[windowInfo.id]?.invalidate()
                            return
                        }
                        // Update status to pending before analysis
                        currentInfo.lastAIAnalysisStatus = .pending
                        currentInfo.lastAIAnalysisTimestamp = Date()
                        self.windowStates[windowInfo.id] = currentInfo
                        self.objectWillChange.send()

                        await self.performAIAnalysis(for: windowInfo.id)
                    }
                }
            // Perform initial analysis immediately if status is pending and no recent analysis
            if windowInfo.lastAIAnalysisStatus == .pending,
               windowInfo.lastAIAnalysisTimestamp == nil || windowInfo.lastAIAnalysisTimestamp!
               .addingTimeInterval(globalInterval * 2) < Date()
            {
                Task {
                    await self.performAIAnalysis(for: windowInfo.id)
                }
            }
        } else {
            logger.info("Live watching disabled for window: \(windowInfo.windowTitle ?? windowInfo.id). Timer stopped.")
            if var currentInfo = self.windowStates[windowInfo.id] {
                currentInfo.lastAIAnalysisStatus = .off
                self.windowStates[windowInfo.id] = currentInfo
                self.objectWillChange.send()
            }
        }
        objectWillChange.send()
    }

    private func performAIAnalysis(for windowId: String) async {
        guard Defaults[.isGlobalMonitoringEnabled] else {
            logger.info("Global monitoring disabled, AI Analysis skipped for window \(windowId).")
            if var windowInfo = windowStates[windowId], windowInfo.lastAIAnalysisStatus == .pending {
                windowInfo.lastAIAnalysisStatus = .off
                windowStates[windowId] = windowInfo
                objectWillChange.send()
            }
            return
        }

        guard var windowInfo = windowStates[windowId], windowInfo.isLiveWatchingEnabled else {
            logger.info("AI Analysis skipped for window \(windowId): Live watching disabled or window not found.")
            return
        }

        logger.info("Checking for screenshot changes for window: \(windowInfo.windowTitle ?? windowId)")

        // Skip screenshot capture for minimized or hidden windows
        if windowInfo.isMinimized {
            logger.info("Skipping AI analysis for minimized window: \(windowInfo.windowTitle ?? windowId)")
            windowInfo.lastAIAnalysisStatus = .off
            windowInfo.lastAIAnalysisResponseMessage = "Window is minimized"
            windowStates[windowId] = windowInfo
            objectWillChange.send()
            return
        }

        if windowInfo.isHidden {
            logger.info("Skipping AI analysis for hidden window: \(windowInfo.windowTitle ?? windowId)")
            windowInfo.lastAIAnalysisStatus = .off
            windowInfo.lastAIAnalysisResponseMessage = "Window is hidden"
            windowStates[windowId] = windowInfo
            objectWillChange.send()
            return
        }

        var targetSCWindow: SCWindow?

        if let axWindowElement = windowInfo.windowAXElement {
            // Attempt to get CGWindowID from the AXElement
            // kAXWindowIDAttribute is of type CFNumberRef, which bridges to NSNumber, then UInt32 for CGWindowID
            if let windowNumberID = axWindowElement.attribute(Attribute<NSNumber>("AXWindowNumber")) {
                let cgWindowID = CGWindowID(windowNumberID.uint32Value)
                logger
                    .debug(
                        "Attempting to find SCWindow with CGWindowID: \(cgWindowID) for AXElement: \(axWindowElement.briefDescription())"
                    )
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    targetSCWindow = content.windows.first { $0.windowID == cgWindowID }
                    if targetSCWindow == nil {
                        logger
                            .warning(
                                "Could not find SCWindow matching CGWindowID \(cgWindowID) for window '\(windowInfo.windowTitle ?? windowId)'. Will attempt capture of first Cursor window."
                            )
                    } else {
                        logger
                            .info(
                                "Successfully found SCWindow with ID \(cgWindowID) for targeted analysis of window '\(windowInfo.windowTitle ?? windowId)'."
                            )
                    }
                } catch {
                    ErrorHandlingUtility.handleAndLog(
                        error,
                        logger: logger,
                        context: "Failed to get SCShareableContent for targeted window analysis"
                    )
                }
            } else {
                logger
                    .warning(
                        "Could not retrieve kAXWindowIDAttribute for window '\(windowInfo.windowTitle ?? windowId)'. Will attempt capture of first Cursor window."
                    )
            }
        } else {
            logger
                .warning(
                    "No AXElement available for window '\(windowInfo.windowTitle ?? windowId)' to get specific CGWindowID. Will attempt capture of first Cursor window."
                )
        }

        // Capture screenshot first to check if it has changed
        do {
            guard let screenshot = try await screenshotAnalyzer.captureCursorWindow(targetSCWindow: targetSCWindow)
            else {
                logger.warning("No screenshot captured for window \(windowId)")
                windowInfo.lastAIAnalysisStatus = .error
                windowInfo.lastAIAnalysisResponseMessage = "Failed to capture screenshot"
                windowStates[windowId] = windowInfo
                objectWillChange.send()
                return
            }

            // Convert screenshot to data for comparison
            guard let tiffData = screenshot.tiffRepresentation else {
                logger.error("Failed to get TIFF representation for screenshot comparison")
                windowInfo.lastAIAnalysisStatus = .error
                windowInfo.lastAIAnalysisResponseMessage = "Failed to process screenshot"
                windowStates[windowId] = windowInfo
                objectWillChange.send()
                return
            }

            // Check if screenshot has changed
            if let previousData = previousScreenshots[windowId], previousData == tiffData {
                logger.info("No changes detected in screenshot for window \(windowId). Skipping AI analysis.")
                // Keep the current status as is (don't change to pending or error)
                return
            }

            // Screenshot has changed or is new, store it and proceed with analysis
            previousScreenshots[windowId] = tiffData
            logger
                .info(
                    "Screenshot changes detected for window: \(windowInfo.windowTitle ?? windowId). Proceeding with AI analysis using 'working' prompt."
                )

            // Also update Git repository info when screenshot changes
            if let documentPath = windowInfo.documentPath {
                if let gitRepo = await gitRepositoryMonitor.findRepository(for: documentPath) {
                    windowInfo.gitRepository = gitRepo
                }
            }

            windowInfo.lastAIAnalysisTimestamp = Date()
            windowInfo.lastAIAnalysisStatus = .pending
            windowStates[windowId] = windowInfo
            objectWillChange.send()

            // Use the predefined prompt from CursorScreenshotAnalyzer
            let prompt = CursorScreenshotAnalyzer.AnalysisPrompts.working

            // Analyze using the already captured screenshot
            let request = ImageAnalysisRequest(
                image: screenshot,
                prompt: prompt,
                model: Defaults[.aiModel]
            )

            let response = try await AIServiceManager.shared.analyzeImage(request)

            // Parse the JSON response
            _ = Data(response.text.utf8)
            let decoder = JSONDecoder()

            struct AIResponse: Codable {
                let status: String
                let reason: String?
            }

            logger.debug("Attempting to parse AI response for window \(windowId). Raw text: '\(response.text)'")

            // Attempt to extract JSON from the response text
            guard let jsonData = extractJsonData(from: response.text) else {
                logger
                    .error(
                        "Could not extract valid JSON from AI response for window \(windowId). Raw response still: '\(response.text)'"
                    )
                windowInfo.lastAIAnalysisStatus = .error
                windowInfo.lastAIAnalysisResponseMessage = "AI response invalid JSON format (extraction failed)."
                windowStates[windowId] = windowInfo
                objectWillChange.send()
                return
            }

            do {
                let aiResult = try decoder.decode(AIResponse.self, from: jsonData)
                let statusString = aiResult.status.lowercased()

                logger
                    .info(
                        "Successfully parsed AI JSON response for window \(windowId). Status: '\(statusString)', Reason: '\(aiResult.reason ?? "N/A")'"
                    )

                switch statusString {
                case "working":
                    windowInfo.lastAIAnalysisStatus = .working
                case "not_working":
                    windowInfo.lastAIAnalysisStatus = .notWorking
                case "unknown":
                    windowInfo.lastAIAnalysisStatus = .unknown
                default:
                    logger
                        .warning(
                            "Unexpected AI analysis status value in JSON response for window \(windowId): '\(statusString)'. Expected 'working', 'not_working', or 'unknown'."
                        )
                    windowInfo.lastAIAnalysisStatus = .error
                }
                windowInfo.lastAIAnalysisResponseMessage = aiResult.reason ?? "No reason provided."

            } catch {
                logger
                    .error(
                        "Failed to decode extracted AI JSON for window \(windowId): \(error.localizedDescription). Extracted data (string): '\(String(data: jsonData, encoding: .utf8) ?? "Invalid UTF-8 Data")'. Original raw response: '\(response.text)'"
                    )
                windowInfo.lastAIAnalysisStatus = .error
                windowInfo.lastAIAnalysisResponseMessage = "AI response JSON parsing error (after extraction)."
            }

        } catch let aiError as AIServiceError {
            let context = "AI analysis failed for window \(windowId)"
            ErrorHandlingUtility.handleAndLog(
                aiError,
                logger: logger,
                context: context
            )
            
            windowInfo.lastAIAnalysisStatus = .error
            windowInfo.lastAIAnalysisResponseMessage = aiError.localizedDescription
        } catch {
            let context = "AI analysis failed for window \(windowId)"
            ErrorHandlingUtility.handleAndLog(
                error,
                logger: logger,
                context: context
            )
            
            windowInfo.lastAIAnalysisStatus = .error
            windowInfo.lastAIAnalysisResponseMessage = error.localizedDescription
        }

        windowStates[windowId] = windowInfo
        objectWillChange.send()
    }

    // Helper function to extract JSON object from a string that might contain other text or code block markers
    private func extractJsonData(from text: String) -> Data? {
        logger.debug("Attempting to extract JSON data from text: '\(text)'")

        // Patterns to capture content within markdown code blocks.
        // NSRegularExpression.Options.dotMatchesLineSeparators will make '.' match newlines.
        let patterns = [
            "```json\\s*(.*?)\\s*```", // Explicit json block, allows optional whitespace around content
            "```\\s*(.*?)\\s*```", // Generic code block, allows optional whitespace around content
        ]

        for patternString in patterns {
            do {
                let regex = try NSRegularExpression(pattern: patternString, options: .dotMatchesLineSeparators)
                let nsRange = NSRange(text.startIndex ..< text.endIndex, in: text)

                if let match = regex.firstMatch(in: text, options: [], range: nsRange) {
                    if match.numberOfRanges > 1 { // Ensure there's a capture group (group 0 is whole match)
                        let jsonContentRange = match.range(at: 1) // Capture group 1 is the desired content
                        if let swiftRange = Range(jsonContentRange, in: text) {
                            let jsonString = String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            logger
                                .debug(
                                    "Extracted potential JSON content using pattern '\(patternString)': '\(jsonString)'"
                                )

                            // Basic validation for JSON object or array
                            if (jsonString.hasPrefix("{") && jsonString.hasSuffix("}")) ||
                                (jsonString.hasPrefix("[") && jsonString.hasSuffix("]"))
                            {
                                if let data = jsonString.data(using: String.Encoding.utf8) {
                                    logger
                                        .info(
                                            "Successfully extracted and validated JSON data using pattern '\(patternString)'."
                                        )
                                    return data
                                }
                            } else {
                                logger
                                    .warning(
                                        "Content extracted with pattern '\(patternString)' ('\(jsonString)') does not appear to be valid JSON (prefix/suffix check failed)."
                                    )
                            }
                        }
                    }
                }
            } catch {
                logger
                    .error(
                        "Failed to initialize NSRegularExpression with pattern '\(patternString)': \(error.localizedDescription)"
                    )
            }
        }

        // Fallback: If not in a code block, try to parse the whole string directly after trimming.
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmedText.hasPrefix("{") && trimmedText.hasSuffix("}")) ||
            (trimmedText.hasPrefix("[") && trimmedText.hasSuffix("]"))
        {
            logger.debug("No code block matched. Trying trimmed full text as JSON: '\(trimmedText)'")
            if let data = trimmedText.data(using: String.Encoding.utf8) {
                logger.info("Successfully validated trimmed full text as JSON.")
                return data
            }
        }

        logger.warning("No extractable JSON found in text after trying all patterns and direct parsing: '\(text)'")
        return nil
    }
}
