import AppKit
import Foundation

/// Extension to make NSImage conform to Sendable for Swift 6 concurrency.
///
/// NSImage is a reference type but is immutable after creation in our use cases,
/// so it's safe to mark as Sendable with @unchecked.
extension NSImage: @unchecked Sendable {}