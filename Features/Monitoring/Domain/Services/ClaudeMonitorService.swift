import Foundation
import Diagnostics
import Defaults
import AppKit
import Vision
@preconcurrency import ScreenCaptureKit
import Darwin
import CoreImage

private let logger = Logger(category: .supervision)

// sysctl constants for getting process arguments
private let CTL_KERN: Int32 = 1
private let KERN_PROCARGS2: Int32 = 49

@MainActor
public final class ClaudeMonitorService: ObservableObject, Sendable {
    public static let shared = ClaudeMonitorService()
    
    @Published public private(set) var instances: [ClaudeInstance] = []
    @Published public private(set) var state: ClaudeMonitoringState = .idle
    @Published public private(set) var isMonitoring = false
    
    private var monitoringTask: Task<Void, Never>?
    private var titleProxyProcess: Process?
    private var titleOverrideEnabled = false
    private let processQueue = DispatchQueue(label: "com.codelooper.claude-monitor", qos: .background)
    
    private init() {
        logger.info("ClaudeMonitorService initialized")
    }
    
    /// Synchronize monitoring state with user preferences
    public func syncWithUserDefaults() {
        let shouldMonitor = Defaults[.enableClaudeMonitoring]
        let shouldOverrideTitles = Defaults[.enableClaudeTitleOverride]
        
        logger.info("Syncing Claude monitoring state: shouldMonitor=\(shouldMonitor), isCurrentlyMonitoring=\(isMonitoring)")
        
        if shouldMonitor && !isMonitoring {
            logger.info("Starting Claude monitoring to match user preferences")
            startMonitoring(enableTitleOverride: shouldOverrideTitles)
        } else if !shouldMonitor && isMonitoring {
            logger.info("Stopping Claude monitoring to match user preferences")
            stopMonitoring()
        } else if shouldMonitor && isMonitoring {
            // Already monitoring, but check if title override setting changed
            if titleOverrideEnabled != shouldOverrideTitles {
                logger.info("Restarting Claude monitoring to update title override setting")
                stopMonitoring()
                startMonitoring(enableTitleOverride: shouldOverrideTitles)
            }
        }
    }
    
    public func startMonitoring(enableTitleOverride: Bool = true) {
        guard !isMonitoring else { return }
        
        logger.info("Starting Claude monitoring (titleOverride: \(enableTitleOverride))")
        isMonitoring = true
        state = .monitoring
        titleOverrideEnabled = enableTitleOverride
        
        if enableTitleOverride {
            startTitleProxy()
        }
        
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scanForClaudeInstances()
                try? await Task.sleep(for: .seconds(5)) // Match other monitoring intervals
            }
        }
    }
    
    public func stopMonitoring() {
        logger.info("Stopping Claude monitoring")
        isMonitoring = false
        state = .idle
        monitoringTask?.cancel()
        monitoringTask = nil
        stopTitleProxy()
        instances.removeAll()
    }
    
    private func startTitleProxy() {
        logger.info("Starting Claude title override functionality")
        // Title overriding is now handled per-instance in updateTitles()
    }
    
    private func stopTitleProxy() {
        titleProxyProcess?.terminate()
        titleProxyProcess = nil
    }
    
    private func scanForClaudeInstances() async {
        logger.info("Starting Claude instance scan...")
        await withCheckedContinuation { continuation in
            processQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                var newInstances: [ClaudeInstance] = []
                var nodeProcessCount = 0
                
                var pids = [pid_t](repeating: 0, count: 4096)
                let size = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
                
                guard size > 0 else {
                    continuation.resume()
                    return
                }
                
                for i in 0..<size/Int32(MemoryLayout<pid_t>.size) {
                    let pid = pids[Int(i)]
                    var info = proc_bsdinfo()
                    
                    if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) <= 0 {
                        continue
                    }
                    
                    let cmd = withUnsafePointer(to: &info.pbi_comm) {
                        $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { String(cString: $0) }
                    }
                    
                    // Check for node processes (also check for "node" in lowercase)
                    guard cmd == "node" || cmd.lowercased() == "node" else { continue }
                    
                    nodeProcessCount += 1
                    
                    // Get process arguments to check if it's Claude
                    var argsMax = 0
                    var argsPtr: UnsafeMutablePointer<CChar>?
                    
                    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
                    if sysctl(&mib, 3, nil, &argsMax, nil, 0) == -1 { continue }
                    
                    guard argsMax > 0 else { continue }
                    argsPtr = UnsafeMutablePointer<CChar>.allocate(capacity: argsMax)
                    defer { argsPtr?.deallocate() }
                    
                    if sysctl(&mib, 3, argsPtr, &argsMax, nil, 0) == -1 { continue }
                    
                    // Parse the arguments
                    guard let args = argsPtr else { continue }
                    let argsData = Data(bytes: args, count: argsMax)
                    let argsString = String(data: argsData, encoding: .utf8) ?? ""
                    
                    // Check if this is a Claude process
                    // Look for the specific Claude installation path pattern
                    let isClaude = argsString.contains("/.claude/local/node_modules/.bin/claude") ||
                                   argsString.contains("\\.claude\\local\\node_modules\\.bin\\claude") ||
                                   argsString.lowercased().contains("anthropic") ||
                                   (argsString.contains("node_modules") && argsString.contains("claude"))
                    
                    guard isClaude else { 
                        logger.debug("Node process PID=\(pid) not Claude: \(String(argsString.prefix(100)))")
                        continue 
                    }
                    
                    logger.info("Found potential Claude process: PID=\(pid)")
                    
                    // Get process's current working directory
                    var vinfo = proc_vnodepathinfo()
                    let vinfoSize = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vinfo, Int32(MemoryLayout<proc_vnodepathinfo>.size))
                    
                    if vinfoSize > 0 {
                        let workingDir = withUnsafePointer(to: &vinfo.pvi_cdir.vip_path) {
                            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
                        }
                        let folderName = URL(fileURLWithPath: workingDir).lastPathComponent
                        
                        // Extract more info from args if possible
                        var status: String? = nil
                        if argsString.contains("claude code") || argsString.contains("--dangerously-skip-permissions") {
                            status = "Claude Code"
                        } else if argsString.contains("claude chat") {
                            status = "Claude Chat"
                        } else {
                            status = "Claude CLI"
                        }
                        
                        // Find TTY if available (optional)
                        var ttyPath = ""
                        var dev = stat()
                        for n in 0...999 {
                            let p = String(format: "/dev/ttys%03d", n)
                            if stat(p, &dev) == 0, dev.st_rdev == info.e_tdev {
                                ttyPath = p
                                logger.debug("Found TTY for PID \(pid): \(ttyPath)")
                                break
                            }
                        }
                        
                        if ttyPath.isEmpty {
                            logger.debug("No TTY found for PID \(pid)")
                        }
                        
                        // Try to get current activity status synchronously first
                        var currentActivity = extractClaudeStatusSync(ttyPath: ttyPath, pid: pid)
                        
                        // If no activity detected, mark as idle
                        if currentActivity == nil || currentActivity?.isEmpty == true {
                            currentActivity = "idle"
                        }
                        
                        let instance = ClaudeInstance(
                            pid: pid,
                            ttyPath: ttyPath,
                            workingDirectory: workingDir,
                            folderName: folderName,
                            status: status,
                            currentActivity: currentActivity
                        )
                        newInstances.append(instance)
                        
                        logger.info("Found Claude instance: PID=\(pid), workingDir=\(workingDir), status=\(status ?? "unknown")")
                    }
                }
                
                logger.info("Scan complete: found \(nodeProcessCount) Node processes, \(newInstances.count) Claude instances")
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // Update instances with fresh activity status
                    var updatedInstances: [ClaudeInstance] = []
                    
                    for instance in newInstances {
                        // Get the latest activity status asynchronously for better accuracy
                        let latestActivity = await self.extractClaudeStatusForSpecificInstance(instance)
                        let finalActivity = latestActivity?.isEmpty == false ? latestActivity! : "idle"
                        
                        // Create updated instance with fresh activity
                        let updatedInstance = ClaudeInstance(
                            pid: instance.pid,
                            ttyPath: instance.ttyPath,
                            workingDirectory: instance.workingDirectory,
                            folderName: instance.folderName,
                            status: instance.status,
                            currentActivity: finalActivity,
                            lastUpdated: Date()
                        )
                        updatedInstances.append(updatedInstance)
                        
                        logger.debug("Updated instance \(instance.folderName) with activity: '\(finalActivity)'")
                    }
                    
                    self.instances = updatedInstances
                    
                    // Update terminal titles if title override is enabled
                    if self.isMonitoring && self.titleOverrideEnabled {
                        Task {
                            await self.updateTerminalTitles(for: updatedInstances)
                        }
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    private func updateTerminalTitles(for instances: [ClaudeInstance]) async {
        logger.info("Updating terminal titles for \(instances.count) Claude instances")
        
        for instance in instances {
            guard !instance.ttyPath.isEmpty else {
                logger.debug("Skipping title update for PID \(instance.pid) - no TTY")
                continue
            }
            
            await updateTitle(for: instance)
        }
    }
    
    private func updateTitle(for instance: ClaudeInstance) async {
        await withCheckedContinuation { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Get current Claude status from terminal that specifically contains this instance
                let claudeStatus = await self.extractClaudeStatusForSpecificInstance(instance)
                
                logger.debug("Extracted Claude status for PID \(instance.pid): '\(claudeStatus ?? "nil")'")
                
                // Create dynamic title with loop emoji to show CodeLooper is working
                // If we have Claude status (e.g., "✶ Branching… (1604s · ⚒ 9.0k tokens)"), use it
                // Otherwise fall back to "idle"
                let displayStatus = claudeStatus?.isEmpty == false ? claudeStatus! : "idle"
                let title = "🔄 \(instance.folderName) — \(displayStatus)"
                
                logger.info("Using title for PID \(instance.pid): '\(title)'")
                if claudeStatus?.isEmpty == false {
                    logger.info("Status source: dynamic Claude status")
                } else {
                    logger.info("Status source: fallback to 'idle'")
                }
                
                // Debug: Show exactly what we're trying to write
                logger.info("DEBUG: Preparing to write title for PID \(instance.pid)")
                logger.info("DEBUG: TTY path: '\(instance.ttyPath)'")
                logger.info("DEBUG: Title to set: '\(title)'")
                
                // Skip title update if no TTY
                guard !instance.ttyPath.isEmpty else {
                    logger.warning("No TTY path for PID \(instance.pid) - cannot update title")
                    return
                }
                
                // Terminal escape sequence to set window title
                let esc = "\u{001B}]2;"
                let bel = "\u{0007}"
                let titleCommand = esc + title + bel
                
                logger.debug("DEBUG: Full escape sequence: '\\033]2;\(title)\\007'")
                
                // Check if TTY exists and is writable
                let ttyExists = FileManager.default.fileExists(atPath: instance.ttyPath)
                logger.debug("DEBUG: TTY exists: \(ttyExists)")
                
                if ttyExists {
                    var isWritable = false
                    let fd = open(instance.ttyPath, O_WRONLY | O_NONBLOCK)
                    if fd >= 0 {
                        isWritable = true
                        defer { close(fd) }
                        
                        let data = titleCommand.data(using: .utf8) ?? Data()
                        let bytesWritten = data.withUnsafeBytes { bytes in
                            write(fd, bytes.baseAddress, bytes.count)
                        }
                        
                        logger.debug("DEBUG: Bytes written: \(bytesWritten) (expected: \(data.count))")
                        
                        if bytesWritten > 0 {
                            logger.info("✅ Successfully updated terminal title for \(instance.folderName) (PID: \(instance.pid))")
                            logger.info("✅ Title: '\(title)'")
                        } else {
                            let error = String(cString: strerror(errno))
                            logger.error("❌ Failed to write title to TTY \(instance.ttyPath): \(error)")
                        }
                    } else {
                        let error = String(cString: strerror(errno))
                        logger.error("❌ Could not open TTY \(instance.ttyPath): \(error)")
                    }
                    
                    logger.debug("DEBUG: TTY writable: \(isWritable)")
                } else {
                    logger.error("❌ TTY does not exist: \(instance.ttyPath)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func extractClaudeStatusForSpecificInstance(_ instance: ClaudeInstance) async -> String? {
        logger.info("Extracting Claude status for specific instance PID \(instance.pid) in \(instance.workingDirectory)")
        
        // Method 1: Try accessibility API first, but match by working directory
        if let status = getTerminalContentViaAccessibilityForInstance(instance) {
            logger.info("Found status from accessibility API for PID \(instance.pid): '\(status)'")
            return status
        }
        
        // Method 2: Try improved OCR with preprocessing, but only capture the specific window
        if let status = await getTerminalContentViaImprovedOCRForInstance(instance) {
            logger.info("Found status from improved OCR for PID \(instance.pid): '\(status)'")
            return status
        }
        
        logger.debug("No Claude status found for PID \(instance.pid)")
        return nil
    }
    
    private func extractClaudeStatus(from instance: ClaudeInstance) async -> String? {
        logger.info("Extracting Claude status for PID \(instance.pid)")
        
        // Method 1: Try accessibility API first (most reliable and fast)
        if let status = getTerminalContentViaAccessibility(pid: instance.pid) {
            logger.info("Found status from accessibility API for PID \(instance.pid): '\(status)'")
            return status
        }
        
        // Method 2: Try improved OCR with preprocessing as fallback (now async for better performance)
        if let status = await getTerminalContentViaImprovedOCR(pid: instance.pid) {
            logger.info("Found status from improved OCR for PID \(instance.pid): '\(status)'")
            return status
        }
        
        logger.debug("No Claude status found for PID \(instance.pid)")
        return nil
    }
    
    private nonisolated func extractClaudeStatusSync(ttyPath: String, pid: Int32) -> String? {
        // Synchronous version for use during scanning
        logger.debug("Trying to extract Claude status sync for PID \(pid)")
        
        // Try accessibility API (synchronous)
        if let status = getTerminalContentViaAccessibility(pid: pid) {
            logger.info("Found sync status from accessibility API for PID \(pid): '\(status)'")
            return status
        }
        
        // Skip OCR in sync version - it's now async only to avoid blocking the scanning thread
        
        return nil
    }
    
    private nonisolated func getTerminalContentViaAccessibilityForInstance(_ instance: ClaudeInstance) -> String? {
        // Find terminal applications that might contain our Claude process
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        let terminalApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId.contains("terminal") || 
                   bundleId.contains("iterm") ||
                   bundleId.contains("ghostty") ||
                   bundleId.contains("warp") ||
                   app.localizedName?.lowercased().contains("terminal") == true
        }
        
        // Check each terminal app for windows containing our specific Claude instance
        for terminalApp in terminalApps {
            if let content = getTerminalWindowContentForInstance(terminalPID: terminalApp.processIdentifier, instance: instance) {
                // Check if this content mentions our Claude PID or contains status
                if content.contains("esc to interrupt") {
                    return parseClaudeStatusLine(content)
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func getTerminalContentViaAccessibility(pid: Int32) -> String? {
        // Find terminal applications that might contain our Claude process
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        let terminalApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId.contains("terminal") || 
                   bundleId.contains("iterm") ||
                   bundleId.contains("ghostty") ||
                   bundleId.contains("warp") ||
                   app.localizedName?.lowercased().contains("terminal") == true
        }
        
        // Check each terminal app for windows containing our Claude process
        for terminalApp in terminalApps {
            if let content = getTerminalWindowContent(terminalPID: terminalApp.processIdentifier) {
                // Check if this content mentions our Claude PID or contains status
                if content.contains("esc to interrupt") {
                    return parseClaudeStatusLine(content)
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func getTerminalWindowContentForInstance(terminalPID: pid_t, instance: ClaudeInstance) -> String? {
        // Get the terminal application for this PID
        let app = AXUIElementCreateApplication(terminalPID)
        
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success,
              let windowsArray = windowsRef as? [AXUIElement] else {
            logger.debug("Could not get windows for terminal PID \(terminalPID)")
            return nil
        }
        
        // Look through windows to find one that matches our specific Claude instance
        for window in windowsArray {
            if let content = extractTextFromWindow(window) {
                // Check if this window contains content from our specific working directory
                // Look for the folder name or full path in the content
                let containsWorkingDir = content.contains(instance.workingDirectory) || 
                                       content.contains(instance.folderName)
                
                if containsWorkingDir && (content.contains("esc to interrupt") || content.contains("Claude")) {
                    logger.debug("Found matching terminal window for \(instance.folderName)")
                    return content
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func getTerminalWindowContent(terminalPID: pid_t) -> String? {
        // Get the terminal application for this PID
        let app = AXUIElementCreateApplication(terminalPID)
        
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success,
              let windowsArray = windowsRef as? [AXUIElement] else {
            logger.debug("Could not get windows for terminal PID \(terminalPID)")
            return nil
        }
        
        // Look through windows to find one with Claude content
        for window in windowsArray {
            if let content = extractTextFromWindow(window) {
                if content.contains("esc to interrupt") || content.contains("Claude") {
                    return content
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func extractTextFromWindow(_ window: AXUIElement) -> String? {
        // Try to get the window's text content
        var valueRef: CFTypeRef?
        
        // Try different attributes that might contain text
        let textAttributes = [
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXTitleAttribute as CFString,
            kAXHelpAttribute as CFString,
            "AXDocument" as CFString, // For some terminal apps
            "AXText" as CFString      // Alternative text attribute
        ]
        
        for attribute in textAttributes {
            if AXUIElementCopyAttributeValue(window, attribute, &valueRef) == .success,
               let text = valueRef as? String,
               !text.isEmpty {
                logger.debug("Found text in \(attribute): \(String(text.prefix(100)))")
                if text.contains("esc to interrupt") || text.contains("Reticulating") || text.contains("Thinking") {
                    return text
                }
            }
        }
        
        // Try to get children and look for text elements recursively
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            
            for child in children {
                if let text = extractTextFromElement(child, maxDepth: 5) {
                    if text.contains("esc to interrupt") || text.contains("Reticulating") || text.contains("Thinking") {
                        return text
                    }
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func extractTextFromElement(_ element: AXUIElement, maxDepth: Int) -> String? {
        guard maxDepth > 0 else { return nil }
        
        // Get element role to understand what type of element this is
        var roleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? "Unknown"
        
        // Try multiple text attributes for this element
        let textAttributes = [
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXTitleAttribute as CFString,
            "AXDocument" as CFString,
            "AXText" as CFString
        ]
        
        for attribute in textAttributes {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
               let text = valueRef as? String,
               !text.isEmpty {
                // Log what we found for debugging
                if text.contains("esc to interrupt") || text.contains("Reticulating") || text.contains("Thinking") {
                    logger.debug("Found Claude status in \(role) element with \(attribute): \(String(text.prefix(200)))")
                    return text
                }
            }
        }
        
        // Recursively check children, prioritizing scroll areas and text areas
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            
            // First pass: look for scroll areas and text areas specifically
            for child in children {
                var childRoleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &childRoleRef) == .success,
                   let childRole = childRoleRef as? String {
                    if childRole.contains("ScrollArea") || childRole.contains("TextArea") || childRole.contains("Text") {
                        if let text = extractTextFromElement(child, maxDepth: maxDepth - 1) {
                            return text
                        }
                    }
                }
            }
            
            // Second pass: check all other children
            for child in children {
                if let text = extractTextFromElement(child, maxDepth: maxDepth - 1) {
                    return text
                }
            }
        }
        
        return nil
    }
    
    private nonisolated func getTerminalContentViaImprovedOCRForInstance(_ instance: ClaudeInstance) async -> String? {
        logger.info("Attempting improved OCR for Claude instance PID \(instance.pid) in \(instance.folderName)")
        
        do {
            // Use ScreenCaptureKit to get available windows
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Look for terminal windows that match our specific instance
            for window in content.windows {
                guard let windowTitle = window.title,
                      let appName = window.owningApplication?.applicationName else { continue }
                
                // Check if this looks like a terminal window
                let isTerminal = appName.lowercased().contains("ghostty") ||
                               appName.lowercased().contains("terminal") ||
                               appName.lowercased().contains("iterm") ||
                               appName.lowercased().contains("warp")
                
                // Check if this window might contain our specific Claude instance
                // Look for folder name or working directory in the window title
                let matchesInstance = windowTitle.contains(instance.folderName) ||
                                    windowTitle.contains(instance.workingDirectory) ||
                                    windowTitle.contains("Claude") // Generic fallback
                
                if isTerminal && matchesInstance {
                    logger.info("Found matching terminal window: '\(windowTitle)' (\(appName)) for \(instance.folderName)")
                    
                    // Capture window using modern ScreenCaptureKit API
                    if let status = await captureWindowAndExtractTextModern(window: window) {
                        return status
                    }
                }
            }
            
            logger.debug("No matching terminal windows found for instance \(instance.folderName)")
            return nil
        } catch {
            logger.error("Failed to get window content via ScreenCaptureKit: \(error)")
            return nil
        }
    }
    
    private nonisolated func getTerminalContentViaImprovedOCR(pid: Int32) async -> String? {
        logger.info("Attempting improved OCR for Claude PID \(pid)")
        
        do {
            // Use ScreenCaptureKit to get available windows
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Look for terminal windows
            for window in content.windows {
                guard let windowTitle = window.title,
                      let appName = window.owningApplication?.applicationName else { continue }
                
                // Check if this looks like a terminal window
                let isTerminal = appName.lowercased().contains("ghostty") ||
                               appName.lowercased().contains("terminal") ||
                               appName.lowercased().contains("iterm") ||
                               appName.lowercased().contains("warp")
                
                if isTerminal {
                    logger.info("Found terminal window: '\(windowTitle)' (\(appName))")
                    
                    // Capture window using modern ScreenCaptureKit API
                    if let status = await captureWindowAndExtractTextModern(window: window) {
                        return status
                    }
                }
            }
            
            logger.debug("No terminal windows found for screen capture")
            return nil
        } catch {
            logger.error("Failed to get window content via ScreenCaptureKit: \(error)")
            return nil
        }
    }
    
    private nonisolated func captureWindowAndExtractTextModern(window: SCWindow) async -> String? {
        do {
            // Configure capture settings
            let configuration = SCStreamConfiguration()
            configuration.width = Int(window.frame.width)
            configuration.height = Int(window.frame.height)
            configuration.scalesToFit = true
            configuration.showsCursor = false
            
            // Create content filter for the specific window
            let filter = SCContentFilter(desktopIndependentWindow: window)
            
            // Capture the window using modern ScreenCaptureKit API
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            
            logger.debug("Captured window '\(window.title ?? "unknown")' using ScreenCaptureKit, size: \(image.width)x\(image.height)")
            
            // Preprocess the image for better OCR results
            guard let preprocessedImage = preprocessImageForOCR(image) else {
                logger.debug("Failed to preprocess image")
                return nil
            }
            
            // Convert to NSImage for Vision framework
            let nsImage = NSImage(cgImage: preprocessedImage, size: NSSize(width: preprocessedImage.width, height: preprocessedImage.height))
            
            // Use Vision framework with improved settings
            return extractTextFromImageWithImprovedSettings(nsImage)
        } catch {
            logger.error("Failed to capture window using ScreenCaptureKit: \(error)")
            return nil
        }
    }
    
    private nonisolated func preprocessImageForOCR(_ image: CGImage) -> CGImage? {
        // Create CIImage from CGImage
        let ciImage = CIImage(cgImage: image)
        
        // Skip grayscale conversion to preserve colored text
        // Terminal status text (like "Syncing") might be in orange/yellow
        guard let colorFilter = CIFilter(name: "CIColorControls") else { return nil }
        colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Increase contrast and brightness without desaturating
        colorFilter.setValue(1.4, forKey: kCIInputContrastKey) // Higher contrast
        colorFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Slight brightness boost
        // Keep saturation at default (1.0) to preserve colors
        
        // Get the color-preserved result
        guard let colorOutput = colorFilter.outputImage else { return nil }
        
        // Apply sharpening filter
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return nil }
        sharpenFilter.setValue(colorOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.2, forKey: kCIInputSharpnessKey) // More aggressive sharpening
        
        guard let sharpOutput = sharpenFilter.outputImage else { return nil }
        
        // Create context and render
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(sharpOutput, from: sharpOutput.extent) else { return nil }
        
        return cgImage
    }
    
    private nonisolated func extractTextFromImageWithImprovedSettings(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            logger.debug("Failed to convert image for OCR")
            return nil
        }
        
        let request = VNRecognizeTextRequest()
        
        // Use improved settings based on ChatGPT suggestions
        request.recognitionLevel = .accurate // Use accurate, not fast
        request.usesLanguageCorrection = false // Disable language correction for terminal text
        request.minimumTextHeight = 0.02 // Filter out tiny text (2% of image height)
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results else {
                logger.debug("No OCR results from image")
                return nil
            }
            
            // Combine all recognized text with confidence filtering
            let recognizedStrings = observations.compactMap { observation -> String? in
                // Only include text with high confidence
                guard observation.confidence > 0.7 else { return nil }
                return observation.topCandidates(1).first?.string
            }
            
            let fullText = recognizedStrings.joined(separator: "\n")
            logger.debug("OCR extracted text (\(recognizedStrings.count) lines): '\(String(fullText.prefix(200)))'")
            
            // Look for Claude status in the extracted text
            if fullText.contains("esc to interrupt") || fullText.contains("interrupt") {
                logger.info("Found 'esc to interrupt' in improved OCR text")
                return parseClaudeStatusLine(fullText)
            }
            
            // Also look for partial matches in case OCR missed some characters
            if fullText.contains("Reticulating") || fullText.contains("Thinking") || fullText.contains("Generating") {
                logger.info("Found Claude activity keywords in OCR text")
                // Try to find the full line containing these keywords
                for line in recognizedStrings {
                    if line.contains("Reticulating") || line.contains("Thinking") || line.contains("Generating") {
                        return line
                    }
                }
            }
            
        } catch {
            logger.debug("OCR failed: \(error)")
        }
        
        return nil
    }
    
    private nonisolated func parseClaudeStatusLine(_ text: String) -> String? {
        // Simple parsing: find "esc to interrupt" and extract everything before it
        // Example: "Syncing… (326s · × 1.5k tokens · esc to interrupt)" → "Syncing… (326s · × 1.5k tokens)"
        
        logger.debug("Parsing Claude status from text: '\(String(text.prefix(300)))'")
        
        // Clean up line breaks - OCR often adds them between words
        let cleanedText = text.replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.debug("Cleaned text: '\(cleanedText)'")
        
        // Be very lenient - Claude status usually has tokens and time info
        // Look for patterns like: "Resolving... (2210s • x 5.6k tokens"
        
        // First try to find any status with time and tokens (most reliable)
        // Make this more flexible for partial OCR
        let statusPatterns = [
            "\\w+[.…]*\\s*\\(\\d+s.*?tokens[^)]*\\)",  // Full pattern with closing paren
            "\\w+[.…]*\\s*\\(\\d+s.*?tokens",         // Without closing paren
            "\\w+[.…]*\\s*\\(\\d+s.*?k\\s*tokens",    // With "k tokens"
            "\\w+[.…]*\\s*\\(\\d+s.*?\\d+k",          // Just time and "Xk" (tokens may be cut off)
            "[A-Z]\\w+[.…]+\\s*\\(\\d+s",             // Just action word with time (very lenient)
        ]
        
        for statusPattern in statusPatterns {
            if let regex = try? NSRegularExpression(pattern: statusPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleanedText, options: [], range: NSRange(cleanedText.startIndex..., in: cleanedText)) {
                
                let nsString = cleanedText as NSString
                var status = nsString.substring(with: match.range)
                
                // Add closing parenthesis if needed and pattern doesn't already have it
                if status.contains("(") && !status.contains(")") {
                    status += ")"
                }
                
                logger.info("Found Claude status via pattern matching ('\(statusPattern)'): '\(status)'")
                return status
            }
        }
        
        // Fallback: look for any interrupt-related text or just look for lines ending abruptly
        let patterns = [
            "esc\\s+to\\s+interrupt",  // Full pattern (preferred)
            "esc to interrupt",        // Full pattern with normal spacing
            "to\\s+interrupt",         // Missing "esc"
            "interrupt\\)",            // Just "interrupt)" - OCR often cuts text
            "interrupt",               // Very lenient - just "interrupt"
            "\\)\\s*$",                // Line ending with ) - very common
            "tokens\\s*$",             // Line ending with "tokens" (cut off before interrupt)
            "k\\s+tokens\\s*$",        // Line ending with "k tokens"
            "\\d+k\\s*$"               // Line ending with just "Xk" (very cut off)
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleanedText, options: [], range: NSRange(cleanedText.startIndex..., in: cleanedText)) {
                
                // Get text before the match
                let beforeText = String(cleanedText[..<cleanedText.index(cleanedText.startIndex, offsetBy: match.range.location)])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                logger.debug("Found '\(pattern)' match in text")
                logger.debug("Text before match (first 200 chars): '\(String(beforeText.prefix(200)))'")
                logger.debug("Text before match (last 200 chars): '\(String(beforeText.suffix(200)))'")
                
                // Look backwards for the status line
                // It should contain parentheses with time/tokens info
                let components = beforeText.components(separatedBy: "•").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                // Find the last component that looks like a status
                for component in components.reversed() {
                    // Status lines typically have:
                    // 1. An action word (often ending in "ing" or with "…")
                    // 2. Parentheses with time/token info
                    // 3. Should be relatively short (< 100 characters)
                    if component.contains("(") && 
                       (component.contains("s ") || component.contains("tokens")) &&
                       (component.contains("…") || component.contains("ing")) &&
                       component.count < 100 { // Add length constraint
                        
                        var status = component
                        
                        // Clean up trailing separators (including the • from your text)
                        while status.hasSuffix("·") || status.hasSuffix("・") || 
                              status.hasSuffix("-") || status.hasSuffix("×") || 
                              status.hasSuffix("•") || status.hasSuffix("x") {
                            status = String(status.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        // Balance parentheses
                        let openCount = status.filter { $0 == "(" }.count
                        let closeCount = status.filter { $0 == ")" }.count
                        if openCount > closeCount {
                            status += ")"
                        }
                        
                        logger.info("Extracted Claude status: '\(status)'")
                        return status
                    }
                }
                
                // Fallback: Find any text with parentheses before the match
                if let lastParen = beforeText.lastIndex(of: "(") {
                    // Find where this status line starts
                    let beforeParen = beforeText[..<lastParen]
                    var startIndex = beforeParen.startIndex
                    
                    // Look for start of status (after bullet points or newlines)
                    if let bulletIndex = beforeParen.lastIndex(of: "•") {
                        startIndex = beforeParen.index(after: bulletIndex)
                    }
                    
                    var status = String(beforeText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Clean up
                    while status.hasSuffix("·") || status.hasSuffix("・") || 
                          status.hasSuffix("-") || status.hasSuffix("×") {
                        status = String(status.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Balance parentheses
                    if status.contains("(") && !status.contains(")") {
                        status += ")"
                    }
                    
                    // Only return if it's a reasonable length and looks like a status
                    if status.count > 5 && status.count < 150 && 
                       (status.contains("…") || status.contains("ing") || status.contains("tokens")) {
                        logger.info("Extracted Claude status (fallback): '\(status)'")
                        return status
                    } else {
                        logger.debug("Rejected fallback status (too long or doesn't look like status): '\(String(status.prefix(100)))'")
                    }
                }
            }
        }
        
        logger.debug("No Claude status found in text")
        return nil
    }
}
