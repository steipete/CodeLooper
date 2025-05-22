// MARK: - Swift 6 Contacts Sendable Support

// In Swift 6, many immutable classes can be safely treated as Sendable
// rather than marking everything as @unchecked Sendable
// This reduces the attack surface for race conditions and improves type safety

import Contacts
import Foundation

// MARK: - Immutable Contact Types

// CNContact and related types are immutable and thread-safe
// Swift 6 allows us to use them across actor boundaries safely

// CNContactStore is reference type that manages state, but we use it safely
// keeping explicit @unchecked since we access it across actors
extension CNContactStore: @retroactive @unchecked Sendable {
    // We use CNContactStore in a controlled manner across concurrency boundaries
    // with proper synchronization via async APIs
}

// MARK: - Limited Use Types

// These are used in specific contexts where we ensure thread safety through
// our architecture, but we still need to be careful with them

// CNSaveRequest is used only temporarily during contact operations
// and never shared across actor boundaries in our code
extension CNSaveRequest: @retroactive @unchecked Sendable {}
