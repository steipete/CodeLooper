import Demark
import Foundation

/// Central service manager for CodeLooper that manages singleton instances.
///
/// This class provides a centralized way to access shared services throughout the application,
/// removing the need for individual services to manage their own singleton patterns.
@MainActor
final class ServiceManager: ObservableObject, Sendable {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    static let shared = ServiceManager()

    /// Shared Demark service for HTML to Markdown conversion
    lazy var demarkService = Demark()

    // MARK: Private

    // Add other shared services here as needed
}
