#!/usr/bin/env swift
//
//  ClaudeTitleProxy.swift
//  CodeLooper
//
//  This script monitors Claude processes and updates their terminal window titles
//  to show the current working directory and status.
//

import Foundation
import Dispatch

// ───── helpers ───────────────────────────────────────────────────────────

func folderName(from path: String) -> String { URL(fileURLWithPath: path).lastPathComponent }

func cleanStatus(_ raw: String) -> String? {
    guard let range = raw.range(of: "esc to interrupt") else { return nil }
    var line = String(raw[..<range.lowerBound])
    if let dot = line.firstIndex(of: "·") { line = String(line[line.index(after: dot)...]) }
    line = line.trimmingCharacters(in: .whitespaces)
    return line.isEmpty ? nil : line + ")"
}

let esc = "\u{001B}]2;"
let bel = "\u{0007}"

// ───── bookkeeping ───────────────────────────────────────────────────────

struct Watch {
    let rfd: Int32
    let wfd: Int32
    let source: DispatchSourceRead
}

var watches: [String: Watch] = [:]   // keyed by tty path

/// Add a watch for the given tty if we aren't already watching it
func ensureWatch(ttyPath: String, folder: String) {
    if watches[ttyPath] != nil { return }

    let rfd = open(ttyPath, O_RDONLY | O_NONBLOCK)
    let wfd = open(ttyPath, O_WRONLY | O_NONBLOCK)
    guard rfd >= 0, wfd >= 0 else { return }

    let source = DispatchSource.makeReadSource(fileDescriptor: rfd, queue: .global())
    source.setEventHandler {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(rfd, &buf, buf.count)
        guard n > 0, let chunk = String(bytes: buf[0..<n], encoding: .utf8) else { return }
        for line in chunk.split(separator: "\n") {
            if let status = cleanStatus(String(line)) {
                let title = "\(folder) — \(status)"
                let data = (esc + title + bel).data(using: .utf8)!
                _ = data.withUnsafeBytes { write(wfd, $0.baseAddress!, $0.count) }
            }
        }
    }
    source.setCancelHandler {
        close(rfd); close(wfd)
        watches.removeValue(forKey: ttyPath)
    }
    source.resume()
    watches[ttyPath] = Watch(rfd: rfd, wfd: wfd, source: source)
}

/// Poll every few seconds for Claude processes and register their ttys
func scanForClaude() {
    var pids = [pid_t](repeating: 0, count: 4096)
    let size = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
    guard size > 0 else { return }

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

        // resolve tty dev to path
        var dev = stat()
        for n in 0...999 {
            let p = String(format: "/dev/ttys%03d", n)
            if stat(p, &dev) == 0, dev.st_rdev == info.e_tdev {
                // Get the process's current working directory
                var pathBuf = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
                let pathLen = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
                if pathLen > 0 {
                    let processPath = String(cString: pathBuf)
                    // Get parent directory as the folder name
                    let folder = folderName(from: URL(fileURLWithPath: processPath).deletingLastPathComponent().path)
                    ensureWatch(ttyPath: p, folder: folder)
                }
                break
            }
        }
    }
}

// ───── main loop ─────────────────────────────────────────────────────────
print("Claude-title proxy running…  (Ctrl-C to quit)")
let timer = DispatchSource.makeTimerSource()
timer.schedule(deadline: .now(), repeating: .seconds(3))
timer.setEventHandler { scanForClaude() }
timer.resume()

dispatchMain()   // never returns