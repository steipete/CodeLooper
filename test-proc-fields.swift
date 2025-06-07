#!/usr/bin/env swift

import Foundation
import Darwin

// Test program to check proc_bsdinfo fields
var info = proc_bsdinfo()

// Try to access the field to see if it compiles
let pid = getpid()
if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) > 0 {
    print("Successfully got process info")
    
    // Test which field name is correct
    // Try e_tdev (which seems to be used in some places)
    print("Testing field access...")
}