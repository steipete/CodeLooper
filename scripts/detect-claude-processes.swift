#!/usr/bin/env swift

import Foundation

// sysctl constants
let CTL_KERN: Int32 = 1
let KERN_PROCARGS2: Int32 = 49

func getProcessList() {
    var pids = [pid_t](repeating: 0, count: 4096)
    let size = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
    
    guard size > 0 else {
        print("Failed to get process list")
        return
    }
    
    let processCount = Int(size) / MemoryLayout<pid_t>.size
    print("Found \(processCount) processes")
    print("Looking for Node processes and potential Claude instances...\n")
    
    for i in 0..<processCount {
        let pid = pids[i]
        guard pid > 0 else { continue }
        
        var info = proc_bsdinfo()
        if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) <= 0 {
            continue
        }
        
        let cmd = withUnsafePointer(to: &info.pbi_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { String(cString: $0) }
        }
        
        // Look for node processes or any process that might be Claude
        if cmd == "node" || cmd.lowercased().contains("node") || 
           cmd.lowercased().contains("claude") || 
           cmd.lowercased().contains("anthropic") {
            
            print("=== Found potential process ===")
            print("PID: \(pid)")
            print("Command: \(cmd)")
            
            // Get process path
            var pathBuf = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            if pathLen > 0 {
                let processPath = String(decoding: pathBuf[0..<Int(pathLen)], as: UTF8.self)
                print("Executable Path: \(processPath)")
            }
            
            // Get process arguments
            var argsMax = 0
            var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
            
            if sysctl(&mib, 3, nil, &argsMax, nil, 0) == 0 && argsMax > 0 {
                let argsPtr = UnsafeMutablePointer<CChar>.allocate(capacity: argsMax)
                defer { argsPtr.deallocate() }
                
                if sysctl(&mib, 3, argsPtr, &argsMax, nil, 0) == 0 {
                    // Parse the arguments
                    let argsData = Data(bytes: argsPtr, count: argsMax)
                    
                    // Find the start of arguments (skip past the executable path)
                    var offset = 0
                    var foundNull = false
                    for i in 0..<argsMax {
                        if argsPtr[i] == 0 {
                            if foundNull {
                                offset = i + 1
                                break
                            }
                            foundNull = true
                        } else {
                            foundNull = false
                        }
                    }
                    
                    // Extract arguments
                    var args: [String] = []
                    var currentArg = ""
                    for i in offset..<argsMax {
                        if argsPtr[i] == 0 {
                            if !currentArg.isEmpty {
                                args.append(currentArg)
                                currentArg = ""
                            }
                        } else {
                            currentArg.append(Character(UnicodeScalar(UInt8(argsPtr[i]))))
                        }
                    }
                    
                    print("Arguments:")
                    for (index, arg) in args.enumerated() {
                        print("  [\(index)]: \(arg)")
                        // Check if this argument contains Claude-related keywords
                        let lowerArg = arg.lowercased()
                        if lowerArg.contains("claude") || 
                           lowerArg.contains("anthropic") ||
                           lowerArg.contains("@anthropic") {
                            print("  ^^^ This looks like a Claude-related argument!")
                        }
                    }
                    
                    // Also print full command line for reference
                    let fullCommand = String(data: argsData, encoding: .utf8) ?? ""
                    let preview = fullCommand.prefix(500).replacingOccurrences(of: "\0", with: " ")
                    print("Command line preview: \(preview)")
                }
            }
            
            // Get working directory
            var vinfo = proc_vnodepathinfo()
            let vinfoSize = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vinfo, Int32(MemoryLayout<proc_vnodepathinfo>.size))
            
            if vinfoSize > 0 {
                let workingDir = withUnsafePointer(to: &vinfo.pvi_cdir.vip_path) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
                }
                print("Working Directory: \(workingDir)")
            }
            
            print("")
        }
    }
    
    print("\nTo find Claude processes, please:")
    print("1. Open a terminal")
    print("2. Run 'claude' or 'claude code'")
    print("3. Run this script again while Claude is running")
}

// Run the detection
getProcessList()