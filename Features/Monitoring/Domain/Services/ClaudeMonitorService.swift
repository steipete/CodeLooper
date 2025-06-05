import Foundation
import Diagnostics

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
    private let processQueue = DispatchQueue(label: "com.codelooper.claude-monitor", qos: .background)
    
    private init() {}
    
    public func startMonitoring(enableTitleOverride: Bool = true) {
        guard !isMonitoring else { return }
        
        logger.info("Starting Claude monitoring")
        isMonitoring = true
        state = .monitoring
        
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
        // For now, we'll log that title proxy would be started
        // In a real implementation, this would either:
        // 1. Embed the title proxy logic directly here
        // 2. Compile and bundle a separate executable
        // 3. Use a different approach for title modification
        logger.info("Claude title proxy feature enabled (implementation pending)")
    }
    
    private func stopTitleProxy() {
        titleProxyProcess?.terminate()
        titleProxyProcess = nil
    }
    
    private func scanForClaudeInstances() async {
        await withCheckedContinuation { continuation in
            processQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                var newInstances: [ClaudeInstance] = []
                
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
                    // Claude CLI typically has "claude" in the command line arguments
                    let lowerArgs = argsString.lowercased()
                    let isClaude = lowerArgs.contains("claude") || 
                                   lowerArgs.contains("claude-cli") ||
                                   lowerArgs.contains("@anthropic") ||
                                   lowerArgs.contains("anthropic") ||
                                   argsString.contains("/claude/") ||
                                   argsString.contains("\\claude\\")
                    
                    if cmd == "node" && !isClaude {
                        // Log first part of args for debugging (only in debug mode)
                        #if DEBUG
                        let preview = String(argsString.prefix(200)).replacingOccurrences(of: "\n", with: " ")
                        logger.debug("Node process PID=\(pid) args preview: \(preview)")
                        #endif
                    }
                    
                    guard isClaude else { continue }
                    
                    logger.info("Found potential Claude process: PID=\(pid)")
                    
                    // Get process's current working directory
                    var vinfo = proc_vnodepathinfo()
                    let vinfoSize = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vinfo, Int32(MemoryLayout<proc_vnodepathinfo>.size))
                    
                    if vinfoSize > 0 {
                        let workingDir = withUnsafePointer(to: &vinfo.pvi_cdir.vip_path) {
                            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
                        }
                        let folderName = URL(fileURLWithPath: workingDir).lastPathComponent
                        
                        // Find TTY
                        var ttyPath: String?
                        var dev = stat()
                        for n in 0...999 {
                            let p = String(format: "/dev/ttys%03d", n)
                            if stat(p, &dev) == 0, dev.st_rdev == info.e_tdev {
                                ttyPath = p
                                break
                            }
                        }
                        
                        if let tty = ttyPath {
                            // Extract more info from args if possible
                            var status: String? = nil
                            if argsString.contains("claude code") {
                                status = "Claude Code"
                            } else if argsString.contains("claude chat") {
                                status = "Claude Chat"
                            }
                            
                            let instance = ClaudeInstance(
                                pid: pid,
                                ttyPath: tty,
                                workingDirectory: workingDir,
                                folderName: folderName,
                                status: status
                            )
                            newInstances.append(instance)
                            
                            logger.info("Found Claude instance: PID=\(pid), workingDir=\(workingDir), tty=\(tty)")
                        }
                    }
                }
                
                Task { @MainActor [weak self] in
                    self?.instances = newInstances
                }
                
                continuation.resume()
            }
        }
    }
}