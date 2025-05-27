import Combine
import Foundation

/// A service to facilitate opening settings programmatically from non-SwiftUI contexts.
public enum SettingsService {
    /// A subject that emits a Void event when a request to open settings is made.
    @MainActor // Ensure this is accessed on the main actor
    public static let openSettingsSubject = PassthroughSubject<Void, Never>()
}
