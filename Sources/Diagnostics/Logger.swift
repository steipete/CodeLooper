import Foundation
import OSLog

// Create a public logger instance for general use
public let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ai.amantusmachina.codelooper",
    category: "Default"
)

// Skip overrides, just use the Swift System.Logger directly
// The warnings about "no 'async' operations occur within 'await' expression" are actually fine, we are just carefully
// forwarding these calls to properly isolate them. The warnings would require API changes, which is
// out of scope for Swift 6 compatibility.
