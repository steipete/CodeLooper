#!/usr/bin/env swift

import Foundation
import Darwin

// sysctl constants for getting process arguments
private let CTL_KERN: Int32 = 1
private let KERN_PROCARGS2: Int32 = 49

print("🔍 Testing Claude Detection Logic")
print("================================")

var pids = [pid_t](repeating: 0, count: 4096)
let size = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))

guard size > 0 else {
    print("❌ Failed to get process list")
    exit(1)
}

let totalProcesses = size / Int32(MemoryLayout<pid_t>.size)
print("📊 Total processes: \(totalProcesses)")

var nodeProcessCount = 0
var claudeInstances: [Int32] = []

for i in 0..<totalProcesses {
    let pid = pids[Int(i)]
    var info = proc_bsdinfo()
    
    if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) <= 0 {
        continue
    }
    
    let cmd = withUnsafePointer(to: &info.pbi_comm) {
        $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { String(cString: $0) }
    }
    
    // Check for node processes
    guard cmd == "node" || cmd.lowercased() == "node" else { continue }
    
    nodeProcessCount += 1
    print("\n🟦 Found Node process: PID=\(pid)")
    
    // Get process arguments to check if it's Claude
    var argsMax = 0
    var argsPtr: UnsafeMutablePointer<CChar>?
    
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    if sysctl(&mib, 3, nil, &argsMax, nil, 0) == -1 { 
        print("   ❌ Failed to get args size for PID \(pid)")
        continue 
    }
    
    guard argsMax > 0 else { 
        print("   ❌ No args for PID \(pid)")
        continue 
    }
    
    argsPtr = UnsafeMutablePointer<CChar>.allocate(capacity: argsMax)
    defer { argsPtr?.deallocate() }
    
    if sysctl(&mib, 3, argsPtr, &argsMax, nil, 0) == -1 { 
        print("   ❌ Failed to get args for PID \(pid)")
        continue 
    }
    
    // Parse the arguments
    guard let args = argsPtr else { 
        print("   ❌ Null args pointer for PID \(pid)")
        continue 
    }
    
    let argsData = Data(bytes: args, count: argsMax)
    let argsString = String(data: argsData, encoding: .utf8) ?? ""
    
    // Show first 200 characters of arguments for debugging
    print("   📝 Args: \(String(argsString.prefix(200)))")
    if argsString.count > 200 {
        print("        ... (truncated)")
    }
    
    // Check if this is a Claude process
    let isClaude = argsString.contains("/.claude/local/node_modules/.bin/claude") ||
                   argsString.contains("\\.claude\\local\\node_modules\\.bin\\claude") ||
                   argsString.lowercased().contains("anthropic") ||
                   (argsString.contains("node_modules") && argsString.contains("claude"))
    
    if isClaude {
        claudeInstances.append(pid)
        print("   ✅ CLAUDE DETECTED!")
        
        // Try to get working directory
        var vinfo = proc_vnodepathinfo()
        let vinfoSize = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vinfo, Int32(MemoryLayout<proc_vnodepathinfo>.size))
        
        if vinfoSize > 0 {
            let workingDir = withUnsafePointer(to: &vinfo.pvi_cdir.vip_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            let folderName = URL(fileURLWithPath: workingDir).lastPathComponent
            print("   📁 Working dir: \(workingDir)")
            print("   📂 Folder name: \(folderName)")
        }
    } else {
        print("   ❌ Not Claude")
    }
}

print("\n📈 Summary")
print("==========")
print("Node processes found: \(nodeProcessCount)")
print("Claude instances detected: \(claudeInstances.count)")

if !claudeInstances.isEmpty {
    print("Claude PIDs: \(claudeInstances)")
    print("✅ Detection logic appears to be working!")
} else {
    print("❌ No Claude instances detected - there may be an issue with the detection logic")
}

print("\n🔍 Expected Claude processes from ps aux:")
let task = Process()
task.launchPath = "/bin/bash"
task.arguments = ["-c", "ps aux | grep 'claude.*node' | grep -v grep"]
task.launch()
task.waitUntilExit()