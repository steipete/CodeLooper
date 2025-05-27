import Foundation
import Observation

// Note: This file is now primarily a compatibility layer that simply
// re-exports Observation framework functionality. New code should use
// the @Observable macro directly instead of this custom implementation.

/// A custom observation protocol to handle observation in different SwiftUI and macOS versions
/// Note: New code should use @Observable directly.
public protocol CustomObservation {
    /// Cancel the observation
    func cancel()
}

/// A modern observation wrapper using the Observation framework
/// This class adapts the new Observation framework to our legacy CustomObservation protocol
/// We use a simplified version that doesn't directly depend on ObservationRegistrar.Registration
public class ModernObservation: CustomObservation {
    // MARK: Lifecycle

    public init(cancellationHandler: (() -> Void)?) {
        self.cancellationHandler = cancellationHandler
    }

    // MARK: Public

    public func cancel() {
        cancellationHandler?()
        cancellationHandler = nil
    }

    // MARK: Private

    // Use a cancellation closure instead of direct Registration reference
    private var cancellationHandler: (() -> Void)?
}

/// A simple observation wrapper for callbacks
/// Legacy implementation for older code
public class CallbackObservation: CustomObservation {
    // MARK: Lifecycle

    public init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    // MARK: Public

    public func cancel() {
        onCancel?()
        onCancel = nil
    }

    // MARK: Private

    private var onCancel: (() -> Void)?
}

// Legacy support for Combine-based observation
// This variant still relies on Combine's AnyCancellable for legacy code paths
import Combine

/// A combine-based observation implementation
/// Legacy support for existing code
public class CombineObservation: CustomObservation {
    // MARK: Lifecycle

    public init(cancellable: AnyCancellable) {
        self.cancellable = cancellable
    }

    // MARK: Public

    public func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }

    // MARK: Private

    private var cancellable: AnyCancellable?
}
