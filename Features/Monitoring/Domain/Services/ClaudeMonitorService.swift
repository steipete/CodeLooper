import Foundation
import Diagnostics
import Defaults
import AppKit

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
                try? await Task.sleep(for: .seconds(3))
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
                                break
                            }
                        }
                        
                        let instance = ClaudeInstance(
                            pid: pid,
                            ttyPath: ttyPath,
                            workingDirectory: workingDir,
                            folderName: folderName,
                            status: status
                        )
                        newInstances.append(instance)
                        
                        logger.info("Found Claude instance: PID=\(pid), workingDir=\(workingDir), status=\(status ?? "unknown")")
                    }
                }
                
                logger.info("Scan complete: found \(nodeProcessCount) Node processes, \(newInstances.count) Claude instances")
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.instances = newInstances
                    
                    // Update terminal titles if title override is enabled
                    if self.isMonitoring && self.titleOverrideEnabled {
                        Task {
                            await self.updateTerminalTitles(for: newInstances)
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
                
                // Get current Claude status from terminal
                let claudeStatus = self.extractClaudeStatus(from: instance)
                
                // Create dynamic title: "FolderName — Claude — Status"
                // If we have Claude status (e.g., "✶ Branching… (1604s · ⚒ 9.0k tokens)"), use it
                // Otherwise fall back to basic status (e.g., "Claude CLI")
                var title = "\(instance.folderName) — \(instance.status ?? "Claude")"
                if let status = claudeStatus, !status.isEmpty {
                    title = "\(instance.folderName) — \(status)"
                }
                
                // Terminal escape sequence to set window title
                let esc = "\u{001B}]2;"
                let bel = "\u{0007}"
                let titleCommand = esc + title + bel
                
                // Try to write to the TTY (this is safe to do from a Task)
                let fd = open(instance.ttyPath, O_WRONLY | O_NONBLOCK)
                if fd >= 0 {
                    defer { close(fd) }
                    
                    let data = titleCommand.data(using: .utf8) ?? Data()
                    let bytesWritten = data.withUnsafeBytes { bytes in
                        write(fd, bytes.baseAddress, bytes.count)
                    }
                    
                    if bytesWritten > 0 {
                        logger.info("Updated terminal title for \(instance.folderName) (PID: \(instance.pid)): \(title)")
                    } else {
                        logger.warning("Failed to write title to TTY \(instance.ttyPath) for PID \(instance.pid)")
                    }
                } else {
                    logger.warning("Could not open TTY \(instance.ttyPath) for PID \(instance.pid)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func extractClaudeStatus(from instance: ClaudeInstance) -> String? {
        // Try to read the terminal buffer to extract Claude's current status
        guard !instance.ttyPath.isEmpty else { return nil }
        
        // Method 1: Try to read recent terminal output
        if let status = readTerminalBuffer(ttyPath: instance.ttyPath) {
            return status
        }
        
        // Method 2: Try AppleScript approach for terminal apps
        if let status = getTerminalContentViaAppleScript(pid: instance.pid) {
            return status
        }
        
        // Method 3: Parse process output/stderr if available
        if let status = parseProcessOutput(pid: instance.pid) {
            return status
        }
        
        return nil
    }
    
    private func readTerminalBuffer(ttyPath: String) -> String? {
        // Try to read recent terminal output by monitoring the PTY
        // This approach tries to read from system logs or proc filesystem
        
        // Method 1: Try to read from system console logs
        if let status = readFromSystemLogs(ttyPath: ttyPath) {
            return status
        }
        
        // Method 2: Try to find the master PTY and read from it
        if let status = readFromMasterPTY(slavePath: ttyPath) {
            return status
        }
        
        return nil
    }
    
    private func readFromSystemLogs(ttyPath: String) -> String? {
        // Extract TTY number from path (e.g., "/dev/ttys003" -> "ttys003")
        let ttyName = URL(fileURLWithPath: ttyPath).lastPathComponent
        
        // Use 'last' command or system logs to get recent terminal activity
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/last")
        process.arguments = ["-t", ttyName, "-1"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Look for Claude-related patterns in the output
            if output.contains("esc to interrupt") || output.contains("Reticulating") {
                return parseClaudeStatusLine(output)
            }
        } catch {
            logger.debug("Failed to read system logs for \(ttyPath): \(error)")
        }
        
        return nil
    }
    
    private func readFromMasterPTY(slavePath: String) -> String? {
        // This is a more advanced approach that would require finding the master PTY
        // associated with the slave TTY and reading from it.
        // This is complex and may not work reliably across different terminal apps.
        
        // For now, we'll skip this implementation and rely on accessibility APIs
        return nil
    }
    
    private func getTerminalContentViaAppleScript(pid: Int32) -> String? {
        // The PID we have is for the Node.js Claude process, not the terminal
        // We need to find the terminal application that's running this process
        return findTerminalAndReadContent(claudePID: pid)
    }
    
    private func findTerminalAndReadContent(claudePID: Int32) -> String? {
        // Get list of running applications that could be terminals
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
            if let content = getTerminalContentViaAccessibility(terminalPID: terminalApp.processIdentifier) {
                // Check if this content mentions our Claude PID or working directory
                if content.contains("esc to interrupt") {
                    return parseClaudeStatusLine(content)
                }
            }
        }
        
        return nil
    }
    
    private func getTerminalContentViaAccessibility(terminalPID: pid_t) -> String? {
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
    
    private func extractTextFromWindow(_ window: AXUIElement) -> String? {
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
        
        // Try to get children and look for text elements (scroll areas, text views, etc.)
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
    
    private func extractTextFromElement(_ element: AXUIElement, maxDepth: Int) -> String? {
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
    
    private func parseProcessOutput(pid: Int32) -> String? {
        // This is a more advanced approach - we could try to attach to the process
        // and read its output, but this is complex and may require special permissions
        return nil
    }
    
    private func parseClaudeStatusLine(_ text: String) -> String? {
        // Parse the Claude status line to extract the complete status
        // Example input: "claude: ✶ Branching… (1604s · ⚒ 9.0k tokens · esc to interrupt)"
        // Desired output: "✶ Branching… (1604s · ⚒ 9.0k tokens)"
        
        let lines = text.components(separatedBy: .newlines)
        
        // Look through all lines for the one containing "esc to interrupt"
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            guard !cleanLine.isEmpty else { continue }
            
            // Look for the line with "esc to interrupt"
            if cleanLine.contains("esc to interrupt") {
                if let range = cleanLine.range(of: "esc to interrupt") {
                    let beforeEsc = cleanLine[..<range.lowerBound]
                    var status = String(beforeEsc).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove the final separator before "esc to interrupt" (like " · " or " ・ ")
                    if status.hasSuffix("·") || status.hasSuffix("・") {
                        status = String(status.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Clean up any prefix like "claude:" or bullet points if present
                    if let colonIndex = status.firstIndex(of: ":") {
                        status = String(status[status.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Remove leading bullet points or symbols but keep the actual content
                    status = status.replacingOccurrences(of: "^[●•○]\\s*", with: "", options: .regularExpression)
                    status = status.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Return the cleaned status if we have meaningful content
                    if !status.isEmpty && status.count > 1 {
                        return status
                    }
                }
            }
        }
        
        return nil
    }
}