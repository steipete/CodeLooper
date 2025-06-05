import Foundation
import Diagnostics

private let logger = Logger(category: .supervision)

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
                    
                    guard cmd.hasPrefix("claude") else { continue }
                    
                    // Get process path
                    var pathBuf = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
                    let pathLen = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
                    
                    if pathLen > 0 {
                        let processPath = String(decoding: pathBuf[0..<Int(pathLen)], as: UTF8.self)
                        let workingDir = URL(fileURLWithPath: processPath).deletingLastPathComponent().path
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
                            let instance = ClaudeInstance(
                                pid: pid,
                                ttyPath: tty,
                                workingDirectory: workingDir,
                                folderName: folderName,
                                status: nil // Will be updated by title proxy
                            )
                            newInstances.append(instance)
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