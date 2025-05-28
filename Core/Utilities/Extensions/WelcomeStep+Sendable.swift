// MARK: - Swift 6 Sendable Conformances

// This file provides appropriate Sendable conformances for Swift 6's improved checking
// We now only need to mark types as @unchecked Sendable when they are truly unsafe
// to share across concurrency boundaries but used in a controlled manner in our code

import Defaults
import Foundation
@preconcurrency import UserNotifications

// MARK: - Foundation Types

// In Swift 6, many Foundation types automatically conform to Sendable
// We only need to keep @unchecked Sendable for types that Swift 6 doesn't automatically handle

// MARK: - Application-Specific Types That Should Be Sendable

// These enum types are value types with no mutable state, but we need to use @unchecked
// since we can't add direct Sendable conformance in a different file from the original definition
extension WelcomeStep: @unchecked Sendable {}
