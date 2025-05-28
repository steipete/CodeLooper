import Foundation
import Combine
import SwiftUI // For ObservableObject
import Defaults
import Diagnostics
import AXorcist
@preconcurrency import ScreenCaptureKit

@MainActor
class WindowAIDiagnosticsManager: ObservableObject {
    static let shared = WindowAIDiagnosticsManager() // <<< ADDED shared instance

    @Published var windowStates: [String: MonitoredWindowInfo] = [:] // Keyed by MonitoredWindowInfo.id

    private var timers: [String: Timer] = [:]
    private let screenshotAnalyzer = CursorScreenshotAnalyzer()
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(category: .supervision)

    init() {
        // Observe CursorMonitor's apps
        CursorMonitor.shared.$monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                self?.updateMonitoredWindows(apps)
            }
            .store(in: &cancellables)
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
                    // Persisted AI settings (isLiveWatchingEnabled, aiAnalysisIntervalSeconds) are loaded by MonitoredWindowInfo init.
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
                setupTimer(for: currentWindowInfo)
            }
        }
        
        // Remove states and timers for windows that no longer exist
        let windowsToRemove = Set(self.windowStates.keys).subtracting(activeWindowIDs)
        for windowID in windowsToRemove {
            timers[windowID]?.invalidate()
            timers.removeValue(forKey: windowID)
            // No need to remove from windowStates here, as newWindowStates will become self.windowStates
        }
        
        // Update the window states
        self.windowStates = newWindowStates
        objectWillChange.send()
    }

    private func setupTimer(for windowInfo: MonitoredWindowInfo) {
        timers[windowInfo.id]?.invalidate() // Invalidate existing timer

        if windowInfo.isLiveWatchingEnabled {
            logger.info("Setting up AI analysis timer for window: \(windowInfo.windowTitle ?? windowInfo.id) with interval \(windowInfo.aiAnalysisIntervalSeconds)s")
            timers[windowInfo.id] = Timer.scheduledTimer(withTimeInterval: TimeInterval(windowInfo.aiAnalysisIntervalSeconds), repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, var currentInfo = self.windowStates[windowInfo.id], currentInfo.isLiveWatchingEnabled else {
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
            if windowInfo.lastAIAnalysisStatus == .pending && (windowInfo.lastAIAnalysisTimestamp == nil || windowInfo.lastAIAnalysisTimestamp!.addingTimeInterval(TimeInterval(windowInfo.aiAnalysisIntervalSeconds * 2)) < Date()) {
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
    }

    private func performAIAnalysis(for windowId: String) async {
        guard var windowInfo = windowStates[windowId], windowInfo.isLiveWatchingEnabled else {
            logger.info("AI Analysis skipped for window \(windowId): Live watching disabled or window not found.")
            return
        }

        logger.info("Performing AI analysis for window: \(windowInfo.windowTitle ?? windowId) using 'working' prompt.")
        windowInfo.lastAIAnalysisTimestamp = Date()
        windowInfo.lastAIAnalysisStatus = .pending
        windowStates[windowId] = windowInfo
        objectWillChange.send()

        var targetSCWindow: SCWindow? = nil

        if let axWindowElement = windowInfo.windowAXElement {
            // Attempt to get CGWindowID from the AXElement
            // kAXWindowIDAttribute is of type CFNumberRef, which bridges to NSNumber, then UInt32 for CGWindowID
            if let windowNumberID = axWindowElement.attribute(Attribute<NSNumber>("AXWindowNumber")) {
                let cgWindowID = CGWindowID(windowNumberID.uint32Value)
                logger.debug("Attempting to find SCWindow with CGWindowID: \(cgWindowID) for AXElement: \(axWindowElement.briefDescription())")
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    targetSCWindow = content.windows.first { $0.windowID == cgWindowID }
                    if targetSCWindow == nil {
                        logger.warning("Could not find SCWindow matching CGWindowID \(cgWindowID) for window '\(windowInfo.windowTitle ?? windowId)'. Will attempt capture of first Cursor window.")
                    } else {
                        logger.info("Successfully found SCWindow with ID \(cgWindowID) for targeted analysis of window '\(windowInfo.windowTitle ?? windowId)'.")
                    }
                } catch {
                    logger.error("Failed to get SCShareableContent for targeted window analysis: \(error.localizedDescription)")
                }
            } else {
                logger.warning("Could not retrieve kAXWindowIDAttribute for window '\(windowInfo.windowTitle ?? windowId)'. Will attempt capture of first Cursor window.")
            }
        } else {
            logger.warning("No AXElement available for window '\(windowInfo.windowTitle ?? windowId)' to get specific CGWindowID. Will attempt capture of first Cursor window.")
        }

        do {
            // Use the predefined prompt from CursorScreenshotAnalyzer
            let prompt = CursorScreenshotAnalyzer.AnalysisPrompts.working
            
            let response = try await screenshotAnalyzer.analyzeSpecificWindow(targetSCWindow, customPrompt: prompt)
            
            // Parse the JSON response
            let responseData = Data(response.text.utf8)
            let decoder = JSONDecoder()
            
            struct AIResponse: Codable {
                let status: String
                let reason: String?
            }
            
            do {
                let aiResult = try decoder.decode(AIResponse.self, from: responseData)
                let statusString = aiResult.status.lowercased()
                
                switch statusString {
                case "working":
                    windowInfo.lastAIAnalysisStatus = .working
                case "not_working":
                    windowInfo.lastAIAnalysisStatus = .notWorking
                case "unknown":
                    windowInfo.lastAIAnalysisStatus = .unknown
                default:
                    logger.warning("Unexpected AI analysis status value in JSON response for window \(windowId): '\(statusString)'. Expected 'working', 'not_working', or 'unknown'.")
                    windowInfo.lastAIAnalysisStatus = .error
                }
                windowInfo.lastAIAnalysisResponseMessage = aiResult.reason ?? "No reason provided."

            } catch {
                logger.error("Failed to decode AI JSON response for window \(windowId): \(error.localizedDescription). Raw response: '\(response.text)'")
                windowInfo.lastAIAnalysisStatus = .error
                windowInfo.lastAIAnalysisResponseMessage = "AI response JSON parsing error."
            }

        } catch let error as AIServiceError {
            logger.error("AI analysis failed for window \(windowId) with AIServiceError: \(error.localizedDescription)")
            windowInfo.lastAIAnalysisStatus = .error
            var detailedMessage = error.localizedDescription
            if let recovery = error.recoverySuggestion {
                detailedMessage += " \n💡 \(recovery)"
            }
            windowInfo.lastAIAnalysisResponseMessage = detailedMessage
        } catch {
            logger.error("AI analysis failed for window \(windowId) with general error: \(error.localizedDescription)")
            windowInfo.lastAIAnalysisStatus = .error
            windowInfo.lastAIAnalysisResponseMessage = error.localizedDescription // General error, no specific recovery suggestion format
        }
        
        windowStates[windowId] = windowInfo
        objectWillChange.send()
    }

    func toggleLiveWatching(for windowId: String) {
        guard var windowInfo = windowStates[windowId] else { return }
        windowInfo.isLiveWatchingEnabled.toggle()
        windowInfo.saveAISettings() // Persist change
        
        if windowInfo.isLiveWatchingEnabled {
            windowInfo.lastAIAnalysisStatus = .pending // Set to pending to trigger analysis
        } else {
            windowInfo.lastAIAnalysisStatus = .off
        }
        
        windowStates[windowId] = windowInfo
        setupTimer(for: windowInfo) // Re-setup timer which will start/stop it
        objectWillChange.send()
    }

    func setAnalysisInterval(for windowId: String, interval: Int) {
        guard var windowInfo = windowStates[windowId], interval > 0 else { return }
        windowInfo.aiAnalysisIntervalSeconds = interval
        windowInfo.saveAISettings() // Persist change
        windowStates[windowId] = windowInfo
        if windowInfo.isLiveWatchingEnabled { // Only restart timer if it's active
            setupTimer(for: windowInfo)
        }
        objectWillChange.send()
    }
    
    // Cleanup method that must be called from MainActor context
    func cleanup() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
} 