import Foundation
import Darwin
import Diagnostics

// MARK: - Claude Process Detection Service

/// Dedicated service for detecting Claude CLI processes using system APIs
final class ClaudeProcessDetector: Loggable, @unchecked Sendable {
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let maxProcessCount = 4096
        static let claudePathPatterns = [
            "/.claude/local/node_modules/.bin/claude",
            "\\.claude\\local\\node_modules\\.bin\\claude"
        ]
        static let nodeProcessNames = ["node", "claude"]
        static let claudeIndicators = ["anthropic", "claude"]
    }
    
    // MARK: - sysctl Constants
    
    private let CTL_KERN: Int32 = 1
    private let KERN_PROCARGS2: Int32 = 49
    
    // MARK: - Public API
    
    /// Detect all running Claude CLI instances
    func detectClaudeInstances() async -> [ClaudeInstance] {
        logger.info("Starting Claude instance detection...")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                let instances = self.scanForClaudeProcesses()
                continuation.resume(returning: instances)
            }
        }
    }
    
    // MARK: - Process Scanning
    
    private func scanForClaudeProcesses() -> [ClaudeInstance] {
        var pids = [pid_t](repeating: 0, count: Configuration.maxProcessCount)
        let size = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        
        guard size > 0 else {
            logger.warning("Failed to get process list")
            return []
        }
        
        let totalProcesses = size / Int32(MemoryLayout<pid_t>.size)
        logger.debug("Scanning \(totalProcesses) processes for Claude instances")
        
        var instances: [ClaudeInstance] = []
        var nodeProcessCount = 0
        
        for i in 0..<totalProcesses {
            let pid = pids[Int(i)]
            
            guard let processInfo = getProcessInfo(pid: pid) else { continue }
            
            // Filter for Node.js processes
            guard Configuration.nodeProcessNames.contains(processInfo.command.lowercased()) else { continue }
            
            nodeProcessCount += 1
            
            guard let processArgs = getProcessArguments(pid: pid) else {
                logger.debug("Could not get arguments for Node process PID \(pid)")
                continue
            }
            
            logger.debug("Process args length for PID \(pid): \(processArgs.count)")
            logger.debug("Process args for PID \(pid): \(String(processArgs.prefix(500).replacingOccurrences(of: "\0", with: "\\0")))")
            
            // Check if this Node process is running Claude
            guard isClaudeProcess(arguments: processArgs) else {
                logger.debug("Node process PID \(pid) is not Claude")
                continue
            }
            
            // Get additional process information
            guard let workingDirectory = getWorkingDirectory(pid: pid) else {
                logger.debug("Could not get working directory for Claude process PID \(pid)")
                continue
            }
            
            let folderName = URL(fileURLWithPath: workingDirectory).lastPathComponent
            let status = determineClaudeStatus(from: processArgs)
            let ttyPath = findTTYPath(for: pid, processInfo: processInfo)
            
            let instance = ClaudeInstance(
                pid: pid,
                ttyPath: ttyPath,
                workingDirectory: workingDirectory,
                folderName: folderName,
                status: status,
                currentActivity: .idle
            )
            
            instances.append(instance)
            logger.info("Detected Claude instance: PID=\(pid), folder=\(folderName), status=\(status.displayName)")
        }
        
        logger.info("Detection complete: found \(nodeProcessCount) Node processes, \(instances.count) Claude instances")
        return instances
    }
    
    // MARK: - Helper Functions
    
    private func safeConvertToInt32<T: BinaryInteger>(_ value: T, name: String) -> Int32? {
        guard let int32Value = Int32(exactly: value) else {
            logger.warning("\(name) \(value) is too large to convert to Int32")
            return nil
        }
        return int32Value
    }
    
    // MARK: - Process Information Extraction
    
    private func getProcessInfo(pid: pid_t) -> (command: String, device: dev_t)? {
        var info = proc_bsdinfo()
        
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) > 0 else {
            return nil
        }
        
        let command = withUnsafePointer(to: &info.pbi_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { String(cString: $0) }
        }
        
        // Handle the device number - 0xFFFFFFFF (4294967295) means no TTY device
        let device: dev_t
        if info.e_tdev == 0xFFFFFFFF {
            // No TTY device - this is normal for many processes
            device = 0
        } else if let deviceInt32 = Int32(exactly: info.e_tdev) {
            device = dev_t(deviceInt32)
        } else {
            // Only log warning for actual overflow (not the special 0xFFFFFFFF value)
            logger.warning("Device \(info.e_tdev) is too large to convert to Int32")
            device = 0  // Use 0 to indicate no valid device
        }
        return (command: command, device: device)
    }
    
    private func getProcessArguments(pid: pid_t) -> String? {
        var argsMax = 0
        // Safely convert pid_t to Int32 - if it doesn't fit, return nil
        guard let pidInt32 = safeConvertToInt32(pid, name: "PID") else {
            return nil
        }
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pidInt32]
        
        // Get required buffer size
        guard sysctl(&mib, 3, nil, &argsMax, nil, 0) == 0, argsMax > 0 else {
            return nil
        }
        
        // Allocate buffer and get arguments
        let argsPtr = UnsafeMutablePointer<CChar>.allocate(capacity: argsMax)
        defer { argsPtr.deallocate() }
        
        guard sysctl(&mib, 3, argsPtr, &argsMax, nil, 0) == 0 else {
            return nil
        }
        
        // KERN_PROCARGS2 format: [argc: int32_t][executable path][args...]
        // Skip the first 4 bytes (argc) to get to the actual arguments
        guard argsMax > 4 else { return nil }
        
        let argsData = Data(bytes: argsPtr, count: argsMax)
        
        // Try to create string from the data, handling null bytes
        if let fullString = String(data: argsData, encoding: .utf8) {
            return fullString
        }
        
        // If that fails, try to extract just the executable path
        let execData = argsData.dropFirst(4)  // Skip argc
        if let execString = String(data: execData, encoding: .utf8) {
            return execString
        }
        
        return nil
    }
    
    private func getWorkingDirectory(pid: pid_t) -> String? {
        var vinfo = proc_vnodepathinfo()
        let vinfoSize = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vinfo, Int32(MemoryLayout<proc_vnodepathinfo>.size))
        
        guard vinfoSize > 0 else { return nil }
        
        return withUnsafePointer(to: &vinfo.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
    }
    
    // MARK: - Claude Detection Logic
    
    private func isClaudeProcess(arguments: String) -> Bool {
        let lowercasedArgs = arguments.lowercased()
        
        // Parse the KERN_PROCARGS2 format
        // Format: [4 bytes argc][executable path\0][padding\0s][arg0\0][arg1\0]...
        let components = arguments.split(separator: "\0", omittingEmptySubsequences: false)
        
        // Skip the first component (contains argc bytes) and look for the actual arguments
        for (index, component) in components.enumerated() {
            let componentStr = String(component).trimmingCharacters(in: .whitespaces)
            
            // Skip empty components and the executable path
            if componentStr.isEmpty || index == 0 { continue }
            
            // Check if this component is "claude" or ends with "/claude"
            if componentStr == "claude" || componentStr.hasSuffix("/claude") {
                logger.debug("Found Claude via argument: \(componentStr)")
                return true
            }
            
            // Also check the executable path itself
            if componentStr.contains("/bin/node") && index + 1 < components.count {
                // Check the next non-empty component after node
                for nextIndex in (index + 1)..<components.count {
                    let nextComponent = String(components[nextIndex]).trimmingCharacters(in: .whitespaces)
                    if !nextComponent.isEmpty {
                        if nextComponent == "claude" || nextComponent.hasSuffix("/claude") {
                            logger.debug("Found Claude as node argument: \(nextComponent)")
                            return true
                        }
                        break // Only check the first non-empty argument after node
                    }
                }
            }
        }
        
        // Check for specific Claude installation path patterns
        for pattern in Configuration.claudePathPatterns {
            if arguments.contains(pattern) {
                logger.debug("Found Claude via path pattern: \(pattern)")
                return true
            }
        }
        
        // Check for Claude indicators in combination with node_modules
        if lowercasedArgs.contains("node_modules") {
            for indicator in Configuration.claudeIndicators {
                if lowercasedArgs.contains(indicator) {
                    logger.debug("Found Claude via indicator: \(indicator)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func determineClaudeStatus(from arguments: String) -> ClaudeInstanceStatus {
        let lowercasedArgs = arguments.lowercased()
        
        if lowercasedArgs.contains("claude code") || lowercasedArgs.contains("--dangerously-skip-permissions") {
            return .claudeCode
        } else if lowercasedArgs.contains("claude chat") {
            return .claudeChat
        } else {
            return .claudeCLI
        }
    }
    
    // MARK: - TTY Detection
    
    private func findTTYPath(for pid: pid_t, processInfo: (command: String, device: dev_t)) -> String {
        // If device is 0, it means no TTY device
        guard processInfo.device != 0 else {
            return ""
        }
        
        // Try to find TTY by device number
        for ttyNumber in 0...999 {
            let ttyPath = String(format: "/dev/ttys%03d", ttyNumber)
            
            var ttyStats = stat()
            guard stat(ttyPath, &ttyStats) == 0 else { continue }
            
            if ttyStats.st_rdev == processInfo.device {
                logger.debug("Found TTY for PID \(pid): \(ttyPath)")
                return ttyPath
            }
        }
        
        logger.debug("No TTY found for PID \(pid) with device \(processInfo.device)")
        return ""
    }
}
